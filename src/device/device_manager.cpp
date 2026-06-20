#include "device_manager.h"
#include "device_defs.h"
#include <QDateTime>
#include "location_reader.h"
#include "core.h"
extern Core core;


DeviceManager::DeviceManager()
    : lastDevs_(nullptr),
      lastDevice_(nullptr),
      mavlinkLink_(nullptr),
      streamList_(this),
      lastAddress_(-1),
      progress_(0),
      isConsoled_(false),
      break_(false),
      upgradeUuid_(QUuid()),
      upgradeAddr_(0)
{
    qRegisterMetaType<ProtoBinOut>("ProtoBinOut");
    qRegisterMetaType<Parsers::ProtoBinOut>("Parsers::ProtoBinOut");
    qRegisterMetaType<uint8_t>("uint8_t");
    qRegisterMetaType<int16_t>("int16_t");
    qRegisterMetaType<QVector<uint8_t>>("QVector<uint8_t>");
    qRegisterMetaType<QByteArray>("QByteArray");
    qRegisterMetaType<IDBinUsblSolution::UsblSolution>("IDBinUsblSolution::UsblSolution");
    qRegisterMetaType<IDBinDVL::BeamSolution>("IDBinDVL::BeamSolution");
    qRegisterMetaType<uint16_t>("uint16_t");
    qRegisterMetaType<IDBinDVL::DVLSolution>("IDBinDVL::DVLSolution");
    qRegisterMetaType<uint32_t>("uint32_t");
    qRegisterMetaType<FrameParser>("FrameParser");
}

void DeviceManager::setSettingsBus(SettingsBus* bus)
{
    bus_ = bus;

    // propagate to all existing DevQProperty objects
    for (auto it = devTree_.begin(); it != devTree_.end(); ++it) {
        auto& addrMap = it.value(); // QHash<int, DevQProperty*>
        for (auto jt = addrMap.begin(); jt != addrMap.end(); ++jt) {
            if (auto* dev = jt.value()) {
                // You’ll add this method to DevQProperty next
                dev->setSettingsBus(bus_);
            }
        }
    }
}

bool DeviceManager::mavlinkDetected() const {
    return mavlinkDetected_;
}

void DeviceManager::setMavlinkDetected(bool detected) {
    mavlinkDetected_ = detected;
}

qint64 DeviceManager::nowUnixNs() {
    return static_cast<qint64>(QDateTime::currentMSecsSinceEpoch()) * 1'000'000LL;
}

bool DeviceManager::hasSystemTimeMapping(const QUuid& srcUuid) const {
    auto it = mavEpochSync_.find(srcUuid);
    return (it != mavEpochSync_.end() && it->offset_ns != std::numeric_limits<qint64>::min());
}

void DeviceManager::setEpochSyncFromSystemTime(const QUuid& srcUuid,
                                               qint64 time_unix_us,
                                               qint64 time_boot_ms)
{
    // Ignore “no time” reports
    if (time_unix_us <= 0 || time_boot_ms < 0) return;

    auto &s = mavEpochSync_[srcUuid];

    // Authoritative mapping: UNIX - boot
    s.offset_ns    = time_unix_us * 1000LL - time_boot_ms * 1'000'000LL;
    s.last_boot_ms = time_boot_ms;
}

std::pair<quint32,quint32>
DeviceManager::toUnixFromBootMs(const QUuid& srcUuid, qint64 boot_ms) const
{
    // If we don’t have SYSTEM_TIME yet, fall back to app-arrival time (best effort)
    qint64 offset_ns;
    auto it = mavEpochSync_.find(srcUuid);
    if (it == mavEpochSync_.end() || it->offset_ns == std::numeric_limits<qint64>::min()) {
        // Best effort guess so you still get reasonable stamps before SYSTEM_TIME appears
        offset_ns = nowUnixNs() - boot_ms * 1'000'000LL;
    } else {
        offset_ns = it->offset_ns;
    }

    const qint64 unix_ns = boot_ms * 1'000'000LL + offset_ns;
    const quint32 sec  = static_cast<quint32>(unix_ns / 1'000'000'000LL);
    const quint32 nsec = static_cast<quint32>(unix_ns % 1'000'000'000LL);
    return {sec, nsec};
}

DeviceManager::~DeviceManager()
{

}

float DeviceManager::vruVoltage()
{
    return vru_.voltage;
}

float DeviceManager::vruCurrent()
{
    return vru_.current;
}

float DeviceManager::vruVelocityH()
{
    return vru_.velocityH;
}

int DeviceManager::pilotArmState()
{
    return vru_.armState;
}

int DeviceManager::pilotModeState()
{
    return vru_.flightMode;
}

int DeviceManager::calcAverageChartLosses()
{
    int retVal = 0;
    int averageChartLosses = 0;
    int numOfDevices = 0;

    for (auto i = devTree_.cbegin(), end = devTree_.cend(); i != end; ++i) {
        const auto& devs = i.value();

        for (auto k = devs.cbegin(), end = devs.cend(); k != end; ++k) {
            ++numOfDevices;
            averageChartLosses += k.value()->getAverageChartLosses();
        }
    }

    if (numOfDevices != 0) {
        retVal = averageChartLosses / numOfDevices;
    }

    return retVal;
}

void DeviceManager::initStreamList()
{
    streamList_.initTimer();
}

QList<DevQProperty *> DeviceManager::getDevList()
{
    devList_.clear();

    for (auto i = devTree_.cbegin(), end = devTree_.cend(); i != end; ++i) {
        const auto& devs = i.value();

        for (auto k = devs.cbegin(), end = devs.cend(); k != end; ++k) {
            devList_.append(k.value());
        }
    }

    return devList_;
}

QList<DevQProperty *> DeviceManager::getDevList(BoardVersion ver) {
    QList<DevQProperty *> list;

    for (auto i = devTree_.cbegin(), end = devTree_.cend(); i != end; ++i) {
        const auto& devs = i.value();

        for (auto k = devs.cbegin(), end = devs.cend(); k != end; ++k) {
            if(k.value()->boardVersion() == ver) {
                list.append(k.value());
            }
        }
    }

    return list;
}

void DeviceManager::frameInput(QUuid uuid, Link* link, Parsers::FrameParser frame)
{
    if (loggingStarted_) {
        emit sendFrameInputToLogger(uuid, link, frame);
    }

    if (frame.isComplete()) {

// #if !defined(Q_OS_ANDROID)
//         if (frame.isStream())
//             streamList_.append(&frame);
//         if (frame.id() == ID_STREAM)
//             streamList_.parse(&frame);
//         if (streamList_.isListChenged())
//             emit streamChanged();
// #endif

        if (link != nullptr) {
            if (frame.isProxy() || frame.completeAsKBP()) {
                otherProtocolStat_.remove(uuid);
            }
        }

        if (frame.isProxy()) {
            return; //continue;
        }

        if (frame.completeAsKBP() || frame.completeAsKBP2()) {
            DevQProperty* dev = getDevice(uuid, link, frame.route());

            if (isConsoled_ && link && frame.id() != 32 && frame.id() != 33) { // link ptr check added
#ifndef SEPARATE_READING
                core.consoleProto(frame);
#endif
            }

#if !defined(Q_OS_ANDROID)
            if (frame.id() == ID_TIMESTAMP && frame.ver() == v1) {
                int t = static_cast<int>(frame.read<U4>());
                int u = static_cast<int>(frame.read<U4>());
                emit eventComplete(t, 0, u);
            }

            if (frame.id() == ID_EVENT) {
                int timestamp = frame.read<U4>();
                int id = frame.read<U4>();
                if (id < 100) {
                    emit eventComplete(timestamp, id, 0);
                }

            }

            if (frame.id() == ID_VOLTAGE) {
                int v_id = frame.read<U1>();
                int32_t v_uv = frame.read<S4>();
                Q_UNUSED(v_uv);
                if (v_id == 1) {
                    // core.dataset()->addEncoder(float(v_uv));
                    // qInfo("Voltage %f", float(v_uv));
                }
            }
#endif
            dev->protoComplete(frame);
        }

        if (frame.isCompleteAsNMEA()) {
            ProtoNMEA& prot_nmea = (ProtoNMEA&)frame;
            QString str_data = QByteArray((char*)prot_nmea.frame(), prot_nmea.frameLen() - 2);
#ifndef SEPARATE_READING
            core.consoleInfo(QString(">> NMEA: %5").arg(str_data));
#endif
            if (prot_nmea.isEqualId("DBT")) {
                prot_nmea.skip();
                prot_nmea.skip();
                double depth_m = prot_nmea.readDouble();
                if (isfinite(depth_m)) {
                    if (auto* dev = getDevice(uuid, link, frame.route()); dev) { // work?
                        emit rangefinderComplete(dev->getChannelId(), depth_m);
                    }
                }
            }

            if (prot_nmea.isEqualId("RMC")) {
                uint8_t h = 0, m = 0, s = 0;
                uint16_t ms = 0;

                bool isCorrect =  prot_nmea.readTime(&h, &m, &s, &ms);
                Q_UNUSED(isCorrect);

                char c = prot_nmea.readChar();
                if (c == 'A' || c == 'D') {
                    double lat = prot_nmea.readLatitude();
                    double lon = prot_nmea.readLongitude();

                    prot_nmea.skip();
                    prot_nmea.skip();

                    uint16_t year = 0;
                    uint8_t month = 0, day = 0;
                    prot_nmea.readDate(&year, &month, & day);

                    QDate date(year, month, day);
                    QTime time(h, m, s);

                    QDateTime dt(date, time, QTimeZone::utc());
                    uint32_t unix_time = static_cast<uint32_t>(dt.toSecsSinceEpoch());

                    emit positionComplete(lat, lon, unix_time, (uint32_t)ms*1000*1000);
                }
            }

            if (prot_nmea.isEqualId("GGA")) {
                uint8_t h = 0, m = 0, s = 0;
                uint16_t ms = 0;

                bool isCorrect =  prot_nmea.readTime(&h, &m, &s, &ms);
                Q_UNUSED(isCorrect);

                double lat = prot_nmea.readLatitude();
                double lon = prot_nmea.readLongitude();

                char q = prot_nmea.readChar();

                prot_nmea.skip(); // sv
                prot_nmea.skip(); // HDOP

                float height_msl = prot_nmea.readDouble(); // Orthometric height (MSL reference)

                if (q == '1' || q == '2' || q == '4' || q == '5') {
                    uint16_t year = 1971;
                    uint8_t month = 1, day = 1;

                    Position pos;
                    pos.lla.latitude = lat;
                    pos.lla.longitude = lon;
                    pos.lla.altitude = height_msl;
                    pos.lla.source = PositionSourceRTK;
                    pos.lla.altSource = AltitudeSourceRTK;
                    pos.time = DateTime(year, month, day, h, m, s, int64_t(ms)*1000*1000);

                    if(q == '4') {
                        emit positionCompleteRTK(pos);
                    }
                }
            }

            if (prot_nmea.isEqualId("HDT")) {
                const double headingDeg = prot_nmea.readDouble();
                //const char reference = prot_nmea.readChar();
                const bool headingValid = isfinite(headingDeg);

                if (/*reference == 'T' && TODO: check this*/ headingValid) {
                    //qDebug().noquote() << QString("NMEA HDT parsed: heading=%1 deg true").arg(heading_deg, 0, 'f', 3);
                    emit attitudeComplete(static_cast<float>(headingDeg), 0.0f, 0.0f);
                }
                else {
                    //qDebug().noquote() << QString("NMEA HDT rejected: heading=%1 ref=%2")
                    //                      .arg(heading_valid ? QString::number(heading_deg, 'f', 3) : QStringLiteral("nan"))
                    //                      .arg(reference);
                }
            }
        }

        if (frame.isCompleteAsUBX()) {
            ProtoUBX& ubx_frame = (ProtoUBX&)frame;

            if (ubx_frame.msgClass() == 1 && ubx_frame.msgId() == 7) {

                uint8_t h = 0, m = 0, s = 0;
                uint16_t year = 0;
                uint8_t month = 0, day = 0;
                int32_t nanosec = 0;

                ubx_frame.readSkip(4);
                year = ubx_frame.read<U2>();
                month = ubx_frame.read<U1>();
                day = ubx_frame.read<U1>();
                h = ubx_frame.read<U1>();
                m = ubx_frame.read<U1>();
                s = ubx_frame.read<U1>();
                ubx_frame.read<U1>(); // Validity flags
                ubx_frame.readSkip(4); // Time accuracy estimate (UTC)
                nanosec = ubx_frame.read<S4>();

                uint8_t fix_type = ubx_frame.read<U1>();
                uint8_t fix_flags = ubx_frame.read<U1>();
                Q_UNUSED(fix_flags);

                ubx_frame.read<U1>();
                uint8_t satellites_in_used = ubx_frame.read<U1>();
                Q_UNUSED(satellites_in_used)

                int32_t lon_int = ubx_frame.read<S4>();
                int32_t lat_int = ubx_frame.read<S4>();

                QDate date(year, month, day);
                QTime time(h, m, s);

                QDateTime dt(date, time, QTimeZone::utc());
                uint32_t unix_time = static_cast<uint32_t>(dt.toSecsSinceEpoch());

                if (fix_type > 1 && fix_type < 5) {
                    emit positionComplete(double(lat_int)*0.0000001, double(lon_int)*0.0000001, unix_time, nanosec);
                }

                // if (isConsoled_) {
#ifndef SEPARATE_READING
                    core.consoleInfo(QString(">> UBX: NAV_PVT, fix %1, sats %2, lat %3, lon %4, time %5:%6:%7.%8")
                                         .arg(fix_type).arg(satellites_in_used).arg(double(lat_int)*0.0000001).arg(double(lon_int)*0.0000001).arg(h).arg(m).arg(s).arg(nanosec/1000));
#endif
                    // }
            }
            else {
                // if (isConsoled_)
#ifndef SEPARATE_READING
                    core.consoleInfo(QString(">> UBX: class/id 0x%1 0x%2, len %3").arg(ubx_frame.msgClass(), 2, 16, QLatin1Char('0')).arg(ubx_frame.msgId(), 2, 16, QLatin1Char('0')).arg(ubx_frame.frameLen()));
#endif
            }
        }

        if (frame.isCompleteAsMAVLink()) {
            bool linkIsNull = link == nullptr;
            //qDebug() << "mavlink frame observed: link == nullptr?" << linkIsNull << "proxyLinkUuid_" << proxyLinkUuid_ << "uuid" << uuid << "mavlinUuid_" << mavlinUuid_;

            if (link != nullptr && mavlinUuid_ != uuid) {
                mavlinUuid_ = uuid;
                mavlinkLink_ = link;
                //connect(this, &DeviceManager::writeMavlinkFrame, mavlinkLink_, &Link::writeFrame, Qt::UniqueConnection);
            }

            if (!mavlinkDetected_) {
                setMavlinkDetected(true);
                emit mavlinkWasDetected();
            }

            ProtoMAVLink& mavlink_frame = (ProtoMAVLink&)frame;

            if (mavlink_frame.msgId() == 2) { // MAVLINK_MSG_ID_SYSTEM_TIME
                MAVLink_MSG_SYSTEM_TIME sys = mavlink_frame.read<MAVLink_MSG_SYSTEM_TIME>();
                setEpochSyncFromSystemTime(uuid,
                                           static_cast<qint64>(sys.time_unix_usec),
                                           static_cast<qint64>(sys.time_boot_ms));
            }

            if(mavlink_frame.msgId() == MAVLink_MSG_GLOBAL_POSITION_INT::getID()) {
                //qDebug() << "mavlink frame is MAVLink_MSG_GLOBAL_POSITION_INT";
                MAVLink_MSG_GLOBAL_POSITION_INT pos = mavlink_frame.read<MAVLink_MSG_GLOBAL_POSITION_INT>();
                if (pos.isValid()) {
                    /*
                    if (link != nullptr && mavlinUuid_ != uuid) {
                        mavlinUuid_ = uuid;
                    }
                    */
                    //Calculate usin msg id 2 SYSTEM_TIME
                    const qint64 boot_ms = pos.time_boot_msec();
                    auto [sec, nsec] = toUnixFromBootMs(uuid, boot_ms);

                    emit positionComplete(pos.latitude(), pos.longitude(), sec, nsec);
                    //qDebug() << "mavlink frame MAVLink_MSG_GLOBAL_POSITION_INT has a valid position. lat" << pos.latitude() << "lng" << pos.longitude();
                    emit gnssVelocityComplete(pos.velocityH(), 0);
                    vru_.velocityH = pos.velocityH();
                    emit vruChanged();
                }
            }

            if (mavlink_frame.msgId() == 30) {
                MAVLink_MSG_ATTITUDE attitude = mavlink_frame.read<MAVLink_MSG_ATTITUDE>();

                const float yaw = attitude.yawDeg();
                const float pitch = attitude.pitchDeg();
                const float roll = attitude.rollDeg();
                /*
                if (link != nullptr && mavlinUuid_ != uuid) {
                    mavlinUuid_ = uuid;
                }
                */

                if (!qFuzzyIsNull(yaw) || !qFuzzyIsNull(pitch) || !qFuzzyIsNull(roll)) {
                    //qDebug() << "mavlink frame MAVLink_MSG_ATTITUDE has a valid yaw" << yaw;
                    emit attitudeComplete(yaw, attitude.pitchDeg(), attitude.rollDeg());
                }
            }

            if (link == nullptr || proxyLinkUuid_ != uuid) {
                emit writeProxyFrame(frame);

                if (link != nullptr && mavlinUuid_ != uuid) {
                    mavlinUuid_ = uuid;
                    if(mavlinkLink_ != nullptr) {
                        disconnect(this, &DeviceManager::writeMavlinkFrame,  mavlinkLink_, &Link::writeFrame);
                    }
                    mavlinkLink_ = link;
                    connect(this, &DeviceManager::writeMavlinkFrame, mavlinkLink_, &Link::writeFrame, Qt::UniqueConnection);
                }

                ProtoMAVLink& mavlink_frame = (ProtoMAVLink&)frame;

                if(mavlink_frame.msgId() == MAVLink_MSG_GLOBAL_POSITION_INT::getID()) {
                    //qDebug() << "mavlink frame is MAVLink_MSG_GLOBAL_POSITION_INT";
                    MAVLink_MSG_GLOBAL_POSITION_INT pos = mavlink_frame.read<MAVLink_MSG_GLOBAL_POSITION_INT>();
                    if (pos.isValid()) {
                        //qDebug() << "mavlink frame MAVLink_MSG_GLOBAL_POSITION_INT has a valid position";
                        emit positionComplete(pos.latitude(), pos.longitude(), pos.time_boot_msec()/1000, (pos.time_boot_msec()%1000)*1e6);
                        emit gnssVelocityComplete(pos.velocityH(), 0);
                        vru_.velocityH = pos.velocityH();
                        emit vruChanged();
                    }
                }

                if (mavlink_frame.msgId() == 0) { // SYS_STATUS
                    MAVLink_MSG_HEARTBEAT heartbeat = mavlink_frame.read<MAVLink_MSG_HEARTBEAT>();
                    vru_.armState = (int)heartbeat.isArmed();
                    int flight_mode = (int)heartbeat.customMode();
                    if (flight_mode != vru_.flightMode) {
#ifndef SEPARATE_READING
                        core.consoleInfo(QString(">> FC: Flight mode %1").arg(flight_mode));
#endif
                    }
                    vru_.flightMode = flight_mode;
                    emit vruChanged();
                }

                if (mavlink_frame.msgId() == 147) { // BATTERY_STATUS
                    MAVLink_MSG_BATTERY_STATUS battery_status = mavlink_frame.read<MAVLink_MSG_BATTERY_STATUS>();
                    vru_.voltage = battery_status.voltage();
                    vru_.current = battery_status.current();
                    emit vruChanged();
                }

                if (mavlink_frame.msgId() == 30) {
                    MAVLink_MSG_ATTITUDE attitude = mavlink_frame.read<MAVLink_MSG_ATTITUDE>();

                    const float yaw = attitude.yawDeg();
                    const float pitch = attitude.pitchDeg();
                    const float roll = attitude.rollDeg();

                    if (!qFuzzyIsNull(yaw) || !qFuzzyIsNull(pitch) || !qFuzzyIsNull(roll)) {
                        emit attitudeComplete(yaw, attitude.pitchDeg(), attitude.rollDeg());
                    }
                }
#ifndef SEPARATE_READING
                core.consoleInfo(QString(">> MAVLink v%1: ID %2, comp. id %3, seq numb %4, len %5").arg(mavlink_frame.MAVLinkVersion()).arg(mavlink_frame.msgId()).arg(mavlink_frame.componentID()).arg(mavlink_frame.sequenceNumber()).arg(mavlink_frame.frameLen()));
#endif
            }
            else {
                if (link != nullptr) {
                    //qDebug() << "mavlink frame emitted";
                    emit writeMavlinkFrame(frame);
                }
            }
        }

        if (link != nullptr) {
            if ((frame.isCompleteAsNMEA() && !((ProtoNMEA*)&frame)->isEqualId("DBT")) ||
                frame.isCompleteAsUBX() ||
                frame.isCompleteAsMAVLink()) {
                if (!frame.isNested()) {
                    otherProtocolStat_[uuid]++;
                    if (otherProtocolStat_[uuid] > 30) {
                        deleteDevicesByLink(uuid);
                    }
                }
            }
        }
    }
}

void DeviceManager::openFile(QString filePath)
{
#ifdef SEPARATE_READING
    break_ = false;
#endif

    QFile file;
    const QUrl url(filePath);
    url.isLocalFile() ? file.setFileName(url.toLocalFile()) : file.setFileName(url.toString());

    if (!file.open(QIODevice::ReadOnly)) {
        emit fileStopsOpening();
        return;
    }

    const qint64 totalSize = file.size();
    qint64 bytesRead = 0;
    Parsers::FrameParser frameParser;
    const QUuid someUuid(kFileUuidStr);

    delAllDev();

#ifdef SEPARATE_READING
    emit fileStartOpening();
    bool fileReadEnough{false};
#endif

    while (true) {

#ifdef SEPARATE_READING
        QCoreApplication::processEvents();
        if (break_) {
            emit fileBreaked(onOpen_);
            onOpen_ = false;
            file.close();
            emit fileStopsOpening();
            return;
        }
#else
        if (break_) {
            file.close();
            return;
        }
#endif

        QByteArray chunk = file.read(static_cast<qint64>(1024) * 1024);
        const qint64 chunkSize = chunk.size();

        if (chunkSize == 0)
            break;

        bytesRead += chunkSize;

        auto currProgress = static_cast<int>((static_cast<float>(bytesRead) / static_cast<float>(totalSize)) * 100.0f);
        currProgress = std::max(0, currProgress);
        currProgress = std::min(100, currProgress);

        if (progress_ != currProgress) {
            progress_ = currProgress;
        }

        frameParser.setContext((uint8_t*)chunk.data(), chunk.size());

#ifdef SEPARATE_READING
        int sleepCnt = 0;
#endif

        while (frameParser.availContext() > 0) {

#ifdef SEPARATE_READING
            QCoreApplication::processEvents();
            if (break_) {
                emit fileBreaked(onOpen_);
                onOpen_ = false;
                file.close();
                return;
            }
            if (sleepCnt > 50) {
                QThread::msleep(1);
                sleepCnt = 0;
            }
            ++sleepCnt;
#endif
            frameParser.process();
            if (frameParser.isComplete()) {
                frameInput(someUuid, nullptr, frameParser);
#ifdef SEPARATE_READING
                if (!fileReadEnough) { // TODO: check this
                    emit onFileReadEnough();
                    fileReadEnough = true;
                }
#endif
            }
        }

        chunk.clear();
    }
    file.close();

    vru_.cleanVru();
    delAllDev();
    emit vruChanged();

    emit fileOpened();
    emit fileStopsOpening();
}

#ifdef SEPARATE_READING
void DeviceManager::closeFile(bool onOpen)
{
    onOpen_ = onOpen;
    break_ = true;

    vru_.cleanVru();
    delAllDev();
    emit vruChanged();
}
#else
void DeviceManager::closeFile()
{
    delAllDev();
    vru_.cleanVru();
    emit vruChanged();
}
#endif

void DeviceManager::onLinkOpened(QUuid uuid, Link *link)
{
    if (link) {
        if (link->getIsProxy()) {
            proxyLinkUuid_ = uuid;
            connect(this, &DeviceManager::writeProxyFrame, link, &Link::writeFrame);
        } else if(link->attribute() == LinkAttribute::kLinkAttributeBoot) {
#ifndef SEPARATE_READING
            core.consoleInfo("Device: Boot opened");
#endif
        } else {
            getDevice(uuid, link, 0);
        }
    }
}

void DeviceManager::onLinkClosed(QUuid uuid, Link *link)
{
    Q_UNUSED(uuid);

    if (link) {
        deleteDevicesByLink(uuid);
        this->disconnect(link);
        otherProtocolStat_.remove(uuid);
        if(uuid == mavlinUuid_) {
            mavlinUuid_ = QUuid();
        }
    }
}

void DeviceManager::onLinkDeleted(QUuid uuid, Link *link)
{
    Q_UNUSED(uuid);

    if (link) {
        deleteDevicesByLink(uuid);
        this->disconnect(link);
        otherProtocolStat_.remove(uuid);
        if(uuid == mavlinUuid_) {
            mavlinUuid_ = QUuid();
        }
    }
}

void DeviceManager::binFrameOut(Parsers::ProtoBinOut protoOut)
{
    if (isConsoled_ && protoOut.id() != 33) {
#ifndef SEPARATE_READING
        core.consoleProto(protoOut, false);
#endif
    }
    emit sendProtoFrame(protoOut);
}

bool DeviceManager::isCreatedId(int id)
{
    return getDevList().size() > id;
}

void DeviceManager::setProtoBinConsoled(bool isConsoled)
{
    isConsoled_ = isConsoled;
}

void DeviceManager::upgradeLastDev(QByteArray data)
{
    if (lastDevs_ != nullptr) {
        lastDevs_->sendUpdateFW(data);
    }
}

void DeviceManager::beaconActivationReceive(uint8_t id) {
    Q_UNUSED(id)

    QList<DevQProperty *> usbl_devs = getDevList(BoardUSBL);
    if (!usbl_devs.isEmpty()) {
        IDBinUsblSolution::USBLRequestBeacon ask = {};
        usbl_devs[0]->askBeaconPosition(ask);
    }
}

void DeviceManager::beaconDirectQueueAsk() {
    QList<DevQProperty *> usbl_devs = getDevList(BoardUSBLBeacon);
    qDebug("Sent request to the Beacon # %d", -1);
    if (!usbl_devs.isEmpty()) {
        usbl_devs[0]->enableBeaconOnce(3);
        qDebug("Sent request to the Beacon # %d", 0);
    }
}

void DeviceManager::setUSBLBeaconDirectAsk(bool is_ask) {
    isUSBLBeaconDirectAsk = is_ask;
    qDebug("Beacon auto scan is: %d", is_ask);
    if (is_ask) {
        QObject::connect(&beacon_timer, &QTimer::timeout, this, &DeviceManager::beaconDirectQueueAsk);
        beacon_timer.setInterval(3000);
        beacon_timer.start();
    } else {
        beacon_timer.stop();
    }
}

void DeviceManager::onLoggingKlfStarted(bool started)
{
    loggingStarted_ = started;

    if (loggingStarted_) {
        for (auto i = devTree_.cbegin(), end = devTree_.cend(); i != end; ++i) {
            const auto& devs = i.value();
            for (auto k = devs.cbegin(), end = devs.cend(); k != end; ++k) {
                k.value()->requestSetup();
            }
        }
    }
}

void DeviceManager::onSendRequestAll(QUuid uuid)
{
    if (devTree_.contains(uuid)) {
        const auto& devs = devTree_[uuid];
        for (auto i = devs.cbegin(), end = devs.cend(); i != end; ++i) {
            if (auto* dev = i.value(); dev) {
                dev->doRequestAll();
            }
        }
    }
}

StreamListModel* DeviceManager::streamsList()
{
    return streamList_.streamsList();
}

void DeviceManager::readyReadProxy(Link* link)
{
    while (link->parse()) {
        FrameParser* frame = link->frameParser();

        if (frame->isComplete()) {
            QByteArray data((char*)frame->frame(), frame->frameLen());
            emit dataSend(data);
        }
    }
}

void DeviceManager::readyReadProxyNav(Link* link)
{
    while (link->parse()) {
        FrameParser* frame = link->frameParser();

        if (frame->isComplete()) {
            QByteArray data((char*)frame->frame(), frame->frameLen());
            emit dataSend(data);
        }
    }
}

void DeviceManager::onStartUpgradingFirmware(QUuid linkUuid, uint8_t address, const QByteArray& firmware)
{
    qDebug() << "DeviceManager::onStartUpgradingFirmware";

    upgradeUuid_ = linkUuid;
    upgradeAddr_ = address;
    upgradeData_ = firmware;
}

void DeviceManager::onUpgradingFirmwareDone()
{
    qDebug() << "DeviceManager::onUpgradingFirmwareDone";

    upgradeUuid_ = QUuid();
    upgradeAddr_ = 0;
    upgradeData_.clear();
}

void DeviceManager::createLocationReader()
{
    //qDebug() << "DeviceManager::createLocationReader";

    if (locReader_) {
        return;
    }

    locReader_ = new LocationReader(this);
    connect(locReader_, &LocationReader::positionUpdated, this, &DeviceManager::onPositionUpdated, Qt::QueuedConnection);
    connect(locReader_, &LocationReader::gpsAlive, &core, &Core::setIsGPSAlive, Qt::QueuedConnection);
}

void DeviceManager::destroyLocationReader()
{
    if (!locReader_) {
        return;
    }

    locReader_->deleteLater();
    locReader_ = nullptr;
}

void DeviceManager::shutdown()
{
    destroyLocationReader();
}

void DeviceManager::onPositionUpdated(const QGeoPositionInfo &info)
{
    if (!useGPS_) {
        return;
    }

    IDBinNav::SimpleNav smplNav;
    smplNav.latitude = info.coordinate().latitude();
    smplNav.longitude = info.coordinate().longitude();
    smplNav.depth = 0;
    smplNav.yaw = info.attribute(QGeoPositionInfo::Attribute::Direction) ;
    smplNav.pitch = 0;
    smplNav.roll = 0;

    emit positionComplete(smplNav.latitude, smplNav.longitude, info.timestamp().toSecsSinceEpoch(), info.timestamp().toMSecsSinceEpoch());
    emit attitudeComplete(smplNav.yaw, 0.0, 0.0);

    // LOGGING
    if (loggingStarted_) {
        ProtoBinOut req_out;
        req_out.create(Parsers::CONTENT, IDBinNav::SimpleNav::getVer(), IDBinNav::SimpleNav::getId(), 0/*m_address*/);
        req_out.write<IDBinNav::SimpleNav>(smplNav);
        req_out.end();

        //QString str1 = "emit coords 1 " + QString::number(smplNav.latitude, 'f', 4) + " " + QString::number(smplNav.longitude, 'f', 4) + " " + QString::number(smplNav.depth, 'f', 4) + " "
        //+ QString::number(smplNav.yaw, 'f', 4) + " " + QString::number(smplNav.pitch, 'f', 4) + " " + QString::number(smplNav.roll, 'f', 4);
        //core.consoleInfo(str1);
        //QString str2 = "emit coords 2 " + QString::number(req_out.binError()) + " " + QString::number(req_out.isComplete()) + " " + QString::number(req_out.payloadLen()) + " " + QString::number(req_out.frameLen()) + " "
        //               + QString::number(req_out.readAvailable()) + " " + QString::number(req_out.availContext());
        //core.consoleInfo(str2);

        emit sendFrameInputToLogger(QUuid(), nullptr, req_out);
    }
}

void DeviceManager::setUseGPS(bool state)
{
    //qDebug() << "DeviceManager::setUseGPS" << state;
    useGPS_ = state;
}

DevQProperty* DeviceManager::getDevice(QUuid uuid, Link *link, uint8_t addr)
{
    if ((link == nullptr || lastUuid_ == uuid) && lastAddress_ == addr && lastDevice_ != nullptr) {
        return lastDevice_;
    }
    else {
        lastDevice_ = devTree_[uuid][addr];
        if (lastDevice_ == nullptr) {
            lastDevice_ = createDev(uuid, link, addr);
        }
        lastUuid_ = uuid;
        lastAddress_ = addr;
    }

    return lastDevice_;
}

void DeviceManager::delAllDev()
{
    QList<QUuid> keysToDelete;
    for (auto i = devTree_.cbegin(), end = devTree_.cend(); i != end; ++i) {
        keysToDelete.append(i.key());
    }

    for (const auto& key : keysToDelete) {
        deleteDevicesByLink(key);
    }
}

void DeviceManager::deleteDevicesByLink(QUuid uuid)
{
    if (devTree_.contains(uuid)) {
        const auto& devs = devTree_[uuid];
        for (auto i = devs.cbegin(), end = devs.cend(); i != end; ++i) {
            if (lastDevice_ == i.value()) {
                lastDevice_ = nullptr;
            }
            disconnect(i.value());

#ifdef SEPARATE_READING
            QMetaObject::invokeMethod(i.value(), "deleteLater", Qt::QueuedConnection);
#else
            i.value()->deleteLater();
#endif
        }
        devTree_[uuid].clear();
        devTree_.remove(uuid);
        emit devChanged();
    }
}

DevQProperty* DeviceManager::createDev(QUuid uuid, Link* link, uint8_t addr)
{
    DevQProperty* dev = new DevQProperty();
    devTree_[uuid][addr] = dev;
    dev->setBusAddress(addr);
    dev->setLinkUuid(uuid);

    if (upgradeUuid_ == uuid && upgradeAddr_ == addr) {
        dev->setFirmware(upgradeData_);
        upgradeUuid_ = QUuid();
    }
    if (bus_) {
        dev->setSettingsBus(bus_);   // ensure new devices also get it
    }

#ifdef SEPARATE_READING
    auto connType = Qt::AutoConnection;

    if (link != nullptr) {
        connect(dev, &DevQProperty::binFrameOut, this, &DeviceManager::binFrameOut, connType);
        connect(dev, &DevQProperty::binFrameOut, link, &Link::writeFrame, connType);
        connect(dev, &DevQProperty::startUpgradingFirmware, link, &Link::onStartUpgradingFirmware, connType);
        connect(dev, &DevQProperty::upgradingFirmwareDone, link, &Link::onUpgradingFirmwareDone, connType);
    }

    connect(dev, &DevQProperty::startUpgradingFirmwareDM, this, &DeviceManager::onStartUpgradingFirmware, connType);
    connect(dev, &DevQProperty::upgradingFirmwareDoneDM, this, &DeviceManager::onUpgradingFirmwareDone, connType);

    //
    connect(dev, &DevQProperty::sendChartSetup, this, &DeviceManager::sendChartSetup, connType);
    connect(dev, &DevQProperty::sendTranscSetup, this, &DeviceManager::sendTranscSetup, connType);
    connect(dev, &DevQProperty::sendSoundSpeed, this, &DeviceManager::sendSoundSpeeed, connType);
    connect(dev, &DevQProperty::averageChartLossesChanged, this, &DeviceManager::chartLossesChanged, connType);

    connect(dev, &DevQProperty::chartComplete, this, &DeviceManager::chartComplete, connType);
    connect(dev, &DevQProperty::rawDataRecieved, this, &DeviceManager::rawDataRecieved, connType);
    connect(dev, &DevQProperty::attitudeComplete, this, &DeviceManager::attitudeComplete, connType);
    connect(dev, &DevQProperty::tempComplete, this, &DeviceManager::tempComplete, connType);
    connect(dev, &DevQProperty::distComplete, this, &DeviceManager::distComplete, connType);
    connect(dev, &DevQProperty::usblSolutionComplete, this, &DeviceManager::usblSolutionComplete, connType);
    connect(dev, &DevQProperty::dopplerBeamComplete, this, &DeviceManager::dopplerBeamComlete, connType);
    connect(dev, &DevQProperty::dvlSolutionComplete, this, &DeviceManager::dvlSolutionComplete, connType);
    connect(dev, &DevQProperty::upgradeProgressChanged, this, &DeviceManager::upgradeProgressChanged, connType);

    connect(dev, &DevQProperty::positionComplete, this, &DeviceManager::positionComplete, connType);
    connect(dev, &DevQProperty::gnssVelocityComplete, this, &DeviceManager::gnssVelocityComplete, connType);
    connect(dev, &DevQProperty::simpleNavV2Complete, this, &DeviceManager::simpleNavV2Complete, connType);
    connect(dev, &DevQProperty::boatStatusComplete, this, &DeviceManager::boatStatusComplete, connType);
    connect(dev, &DevQProperty::depthComplete, this, &DeviceManager::depthComplete, connType);

    // PULSE: re-notify the QML `devs` list when a device's IDENTITY changes.
    // devChanged() is the NOTIFY for the `devs` Q_PROPERTY, but it was only emitted on
    // create/delete. A device's name/type arrives later via a version frame
    // (deviceVersionChanged), so without this the QML selection runs against a still-unnamed
    // placeholder and never re-evaluates. We must NOT forward every deviceVersionChanged though:
    // the device emits it on each periodic version/keep-alive frame, which would rebuild devList
    // (and re-run selection) several times a second. Forward only when the identity signature
    // (type/serial/firmware) actually changes, so selection re-runs as the device resolves and
    // then goes quiet (fixes the selection race without churning the list).
    connect(dev, &DevQProperty::deviceVersionChanged, this, [this, dev]() {
        const QString sig = QString::number(dev->devType()) + "/" +
                            QString::number(static_cast<int>(dev->devSerialNumber())) + "/" +
                            dev->fwVersion();
        if (dev->property("_lastIdSig").toString() != sig) {
            dev->setProperty("_lastIdSig", sig);
            emit devChanged();
        }
    }, connType);

    dev->moveToThread(qApp->thread());
    dev->getProcessTimer()->moveToThread(qApp->thread());
    QList<QTimer*> timers = dev->getChildTimers();
    foreach (QTimer* timer, timers) {
        timer->moveToThread(qApp->thread());
    }

    QMetaObject::invokeMethod(dev, "initProcessTimerConnects", Qt::QueuedConnection);
    QMetaObject::invokeMethod(dev, "initChildsTimersConnects", Qt::QueuedConnection);
    QMetaObject::invokeMethod(dev, "startConnection", Qt::QueuedConnection, Q_ARG(bool, link != nullptr));
#else
    if (link != nullptr) {
        connect(dev, &DevQProperty::binFrameOut, this, &DeviceManager::binFrameOut);
        connect(dev, &DevQProperty::binFrameOut, link, &Link::writeFrame);
        connect(dev, &DevQProperty::startUpgradingFirmware, link, &Link::onStartUpgradingFirmware);
        connect(dev, &DevQProperty::upgradingFirmwareDone, link, &Link::onUpgradingFirmwareDone);
    }

    connect(dev, &DevQProperty::startUpgradingFirmwareDM, this, &DeviceManager::onStartUpgradingFirmware);
    connect(dev, &DevQProperty::upgradingFirmwareDoneDM, this, &DeviceManager::onUpgradingFirmwareDone);

    //
    connect(dev, &DevQProperty::sendChartSetup,  this, &DeviceManager::sendChartSetup);
    connect(dev, &DevQProperty::sendTranscSetup, this, &DeviceManager::sendTranscSetup);
    connect(dev, &DevQProperty::sendSoundSpeed, this, &DeviceManager::sendSoundSpeeed);
    connect(dev, &DevQProperty::averageChartLossesChanged, this, &DeviceManager::chartLossesChanged);

    connect(dev, &DevQProperty::chartComplete, this, &DeviceManager::chartComplete);
    connect(dev, &DevQProperty::rawDataRecieved, this, &DeviceManager::rawDataRecieved);
    connect(dev, &DevQProperty::attitudeComplete, this, &DeviceManager::attitudeComplete);
    connect(dev, &DevQProperty::tempComplete, this, &DeviceManager::tempComplete);
    connect(dev, &DevQProperty::distComplete, this, &DeviceManager::distComplete);
    connect(dev, &DevQProperty::encoderComplete, this, &DeviceManager::encoderComplete);
    connect(dev, &DevQProperty::usblSolutionComplete, this, &DeviceManager::usblSolutionComplete);
    connect(dev, &DevQProperty::beaconActivationComplete, this, &DeviceManager::beaconActivationReceive);
    connect(dev, &DevQProperty::dopplerBeamComplete, this, &DeviceManager::dopplerBeamComlete);
    connect(dev, &DevQProperty::dvlSolutionComplete, this, &DeviceManager::dvlSolutionComplete);
    connect(dev, &DevQProperty::upgradeProgressChanged, this, &DeviceManager::upgradeProgressChanged);

    connect(dev, &DevQProperty::positionComplete, this, &DeviceManager::positionComplete);
    connect(dev, &DevQProperty::gnssVelocityComplete, this, &DeviceManager::gnssVelocityComplete);
    connect(dev, &DevQProperty::simpleNavV2Complete, this, &DeviceManager::simpleNavV2Complete);
    connect(dev, &DevQProperty::boatStatusComplete, this, &DeviceManager::boatStatusComplete);
    connect(dev, &DevQProperty::depthComplete, this, &DeviceManager::depthComplete);

    // PULSE: re-notify the QML `devs` list when a device's IDENTITY changes.
    // devChanged() is the NOTIFY for the `devs` Q_PROPERTY, but it was only emitted on
    // create/delete. A device's name/type arrives later via a version frame
    // (deviceVersionChanged), so without this the QML selection runs against a still-unnamed
    // placeholder and never re-evaluates. We must NOT forward every deviceVersionChanged though:
    // the device emits it on each periodic version/keep-alive frame, which would rebuild devList
    // (and re-run selection) several times a second. Forward only when the identity signature
    // (type/serial/firmware) actually changes, so selection re-runs as the device resolves and
    // then goes quiet (fixes the selection race without churning the list).
    connect(dev, &DevQProperty::deviceVersionChanged, this, [this, dev]() {
        const QString sig = QString::number(dev->devType()) + "/" +
                            QString::number(static_cast<int>(dev->devSerialNumber())) + "/" +
                            dev->fwVersion();
        if (dev->property("_lastIdSig").toString() != sig) {
            dev->setProperty("_lastIdSig", sig);
            emit devChanged();
        }
    });

    dev->startConnection(link != nullptr);
#endif

    emit devChanged();

    return dev;
}
