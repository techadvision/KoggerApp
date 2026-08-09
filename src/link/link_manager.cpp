#include "link_manager.h"

#include <QFile>
#include <QXmlStreamReader>
#include <QDebug>
#include <QStandardPaths>
#include <QDir>
#include <QThread>
#if defined(Q_OS_ANDROID)
#include <QCoreApplication>
#include <QtCore/qnativeinterface.h>
#include <QtCore/qjniobject.h>
#include <QFuture>
#include <QVariant>
#endif
#include <QDebug>
#include "SettingsBus.h"
#include <QPointer>
#include <QRegularExpression>

namespace {

bool xmlBoolValue(const QString& value)
{
    const QString normalized = value.trimmed().toUpper();
    return normalized == QStringLiteral("TRUE") || normalized == QStringLiteral("1");
}

}


LinkManager::LinkManager(QObject *parent) :
    QObject(parent),
    coldStarted_(true)
{
    qRegisterMetaType<ControlType>("ControlType");
    qRegisterMetaType<LinkType>("LinkType");
    qRegisterMetaType<FrameParser>("FrameParser");
}

//PULSE
void LinkManager::setSettingsBus(SettingsBus* bus)
{
    if (bus_ == bus) return;

    // avoid duplicate connections if this is called again
    if (bus_) {
        QObject::disconnect(bus_, nullptr, this, nullptr);
    }

    bus_ = bus;
    if (!bus_) return;

    // Subscribe to settings changes
    QObject::connect(bus_, &SettingsBus::persistentChanged,
                     this, [this](const QVariantMap& m){ applyPersistent(m); },
                     Qt::QueuedConnection);

    QObject::connect(bus_, &SettingsBus::runtimeChanged,
                     this, [this](const QVariantMap& m){ applyRuntime(m); },
                     Qt::QueuedConnection);

    // Propagate bus to already created Link objects
    for (Link* ln : list_) {
        if (ln) ln->setSettingsBus(bus_);
    }

    /*
    bus_ = bus;
    // propagate to existing link objects
    for (Link* l : list_) {
        if (l) l->setSettingsBus(bus_);
    }
    */
}

void LinkManager::applyRuntime(const QVariantMap& m)
{

    if (m.contains("uuidIpGateway")) {
        uuidIpGateway_ = m.value("uuidIpGateway").toString();
        qDebug() << "LinkManager::ApplyRuntime uuidIpGateway" << uuidIpGateway_;
    }
    if (m.contains("uuidUsbSerial")) {
        uuidUsbSerial_ = m.value("uuidUsbSerial").toString();
        qDebug() << "LinkManager::ApplyRuntime uuidUsbSerial" << uuidUsbSerial_;
    }
    if (m.contains("uuidProxyLink")) {
        uuidProxyLink_ = m.value("uuidProxyLink").toString();
        qDebug() << "LinkManager::ApplyRuntime uuidProxyLink" << uuidProxyLink_;
    }
    /*
    if (m.contains("usbSerialBaud")) {
        int newUsbBaudRate = m.value("usbSerialBaud").toInt();
        if (newUsbBaudRate != usbSerialBaud_) {
            usbSerialBaud_ = newUsbBaudRate;
            //updateBaudrate(uuidUsbSerial_, usbSerialBaud_);
            qDebug() << "LinkManager::ApplyRuntime usbSerialBaud" << usbSerialBaud_;
        }
    }
    */


}

void LinkManager::applyPersistent(const QVariantMap& m)
{
    if (m.contains("udpGateway"))   udpGateway_   = m.value("udpGateway").toString();
    if (m.contains("isBetaTester")) isBetaTester_ = m.value("isBetaTester").toBool();
    if (m.contains("isExpert"))     isExpert_     = m.value("isExpert").toBool();
    if (m.contains("udpPort"))      udpPort_      = m.value("udpPort").toInt();
    if (m.contains("usbSerialBaud")) {
        int newUsbBaudRate = m.value("usbSerialBaud").toInt();
        if (newUsbBaudRate != usbSerialBaud_) {
            usbSerialBaud_ = newUsbBaudRate;
            const QUuid uuid = QUuid::fromString(uuidUsbSerial_);
            if (uuid.isNull()) {
                qWarning() << "Invalid USB serial uuid string:" << uuidUsbSerial_;
            } else {
                updateBaudrate(uuid, usbSerialBaud_);
                qDebug() << "LinkManager::applyPersistent usbSerialBaud" << usbSerialBaud_;
            }
            //updateBaudrate(uuidUsbSerial_, usbSerialBaud_);
        }
    }
    qDebug() << "QA_ver_0.96: LinkManager persistent values: udpGateway" << udpGateway_ << "isBetaTester" << isBetaTester_ << "isExpert" << isExpert_ << "udpPort" << udpPort_;
}

/*
QList<QSerialPortInfo> LinkManager::getCurrentSerialList() const
{
    //return QSerialPortInfo::availablePorts();
    const QList<QSerialPortInfo> ports = QSerialPortInfo::availablePorts();

    for (const QSerialPortInfo &p : ports) {
        qDebug().noquote()
        << QString("port=%1  location=%2  desc=%3  mfg=%4  serial=%5  busy=%6")
                .arg(p.portName(),
                     p.systemLocation(),
                     p.description(),
                     p.manufacturer(),
                     p.serialNumber(),
                     p.isBusy() ? "yes" : "no");
    }

    return ports;
}
*/

LinkManager::~LinkManager()
{
    shutdown();
}

void LinkManager::shutdown()
{
    stopTimer();

    for (int i = list_.size() - 1; i >= 0; --i) {
        Link* link = list_.at(i);
        if (!link) {
            list_.removeAt(i);
            continue;
        }

        emit linkDeleted(link->getUuid(), link);
        emit deleteModel(link->getUuid());

        link->disconnect();
        this->disconnect(link);

        if (link->isOpen()) {
            link->close();
        }

        list_.removeAt(i);
        delete link;
    }

    proxyLinkUuid_ = QUuid();
}

QList<QSerialPortInfo> LinkManager::getCurrentSerialList() const
{
    const auto allPorts = QSerialPortInfo::availablePorts();

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    QList<QSerialPortInfo> filteredPorts;
    for (const auto& portInfo : allPorts) {
        const QString systemLocation = portInfo.systemLocation();
        const bool hasUsbIdentifiers = portInfo.hasVendorIdentifier() || portInfo.hasProductIdentifier();
        const bool hasUsbLikeName = systemLocation.startsWith("/dev/ttyUSB")
                                 || systemLocation.startsWith("/dev/ttyACM");

        if (hasUsbIdentifiers || hasUsbLikeName) {
            filteredPorts.append(portInfo);
        }
    }
    return filteredPorts;
#else
    return allPorts;
#endif
}


Link* LinkManager::createSerialPort(const QSerialPortInfo &serialInfo) const
{
    Link* newLinkPtr = nullptr;

    if (serialInfo.isNull())
        return newLinkPtr;
    newLinkPtr = createNewLink();
    newLinkPtr->createAsSerial(serialInfo.portName(), 921600, false);
#if defined(Q_OS_ANDROID)
    newLinkPtr->setControlType(ControlType::kAuto);
    newLinkPtr->setAutoConnOnce(true);
#endif
    return newLinkPtr;
}

void LinkManager::addNewLinks(const QList<QSerialPortInfo> &currSerialList)
{
    //qDebug() << "LinkManager::addNewLinks";
    for (const auto& itmI : currSerialList) {
        bool isBeen{ false };

        for (auto& itmJ : list_) {
            if (itmJ->getLinkType() != LinkType::kLinkSerial)
                continue;

            if (itmI.portName() == itmJ->getPortName()) {
                isBeen = true;
                break;
            }
        }

        if (!isBeen) {
            auto link = createSerialPort(itmI);
            list_.append(link);
            doEmitAppendModifyModel(link);
        }
    }

}

void LinkManager::deleteMissingLinks(const QList<QSerialPortInfo> &currSerialList)
{
    //qDebug() << "LinkManager::openAutoConnections";
    for (int i = 0; i < list_.size(); ++i) {
        Link* link = list_.at(i);

        if (link->getLinkType() != LinkType::kLinkSerial) {
            continue;
        }
        if (link->getIsUpgradingState()) {
            continue;
        }

        bool isBeen{ false };
        for (const auto& itm : currSerialList) {
            if (itm.portName() == link->getPortName()) {
                isBeen = true;
                break;
            }
        }

        if (link->getIsPinned()) {
            if (!isBeen && !link->getIsNotAvailable()) {
                if (link->isOpen())
                    link->close();
                link->setIsNotAvailable(true);
                doEmitAppendModifyModel(link);
            }
            else if (isBeen && link->getIsNotAvailable()) {
                link->setIsNotAvailable(false);
                doEmitAppendModifyModel(link);
            }
        }
        else if (!isBeen) {
            deleteLink(link->getUuid());
        }
    }
}

void LinkManager::openAutoConnections()
{
    //qDebug() << "LinkManager::openAutoConnections";
    for (int i = 0; i < list_.size(); ++i) { // do not open auto conns when file is open
        if (list_.at(i)->getIsForceStopped()) {
            return;
        }
    }

    for (int i = 0; i < list_.size(); ++i) {
        Link* link = list_.at(i);

        if (!link->getConnectionStatus()) {
            bool autoConnOnce = link->getAutoConnOnce();

            if ((link->getControlType() == ControlType::kAuto &&
                !link->getIsNotAvailable()) ||
                autoConnOnce) {

                if (autoConnOnce) {
                    link->setAutoConnOnce(false);
                }

                switch (link->getLinkType()) {
                    case LinkType::kLinkNone:   { break; }
                    case LinkType::kLinkSerial: { link->openAsSerial(); break; }
                    case LinkType::kLinkIPUDP:  { link->openAsUdp(); break; }
                    case LinkType::kLinkIPTCP:  { link->openAsTcp(); break; }
                    default:                   { break; }
                }
            }
        }
    }
}

void LinkManager::update()
{
    //qDebug() << "LinkManager::update";
    auto currSerialList{ getCurrentSerialList() };

    addNewLinks(currSerialList);

    deleteMissingLinks(currSerialList);

    openAutoConnections();
}

Link* LinkManager::getLinkPtr(QUuid uuid)
{
    const TimerController timerGuard(timer_.get());
    //qDebug() << "LinkManager::getLinkPtr";

    Link* retVal{ nullptr };

    for (auto& itm : list_) {
        if (itm->getUuid() == uuid) {
            retVal = itm;
            break;
        }
    }

    return retVal;
}

void LinkManager::doEmitAppendModifyModel(Link* linkPtr)
{
    const TimerController timerGuard(timer_.get());
    //qDebug() << "LinkManager::doEmitAppendModifyModel";

    emit appendModifyModel(linkPtr->getUuid(),
                           linkPtr->getConnectionStatus(),
                           linkPtr->getIsRecievesData(),
                           linkPtr->getControlType(),
                           linkPtr->getPortName(),
                           linkPtr->getBaudrate(),
                           linkPtr->getParity(),
                           linkPtr->getLinkType(),
                           linkPtr->getAddress(),
                           linkPtr->getSourcePort(),
                           linkPtr->getDestinationPort(),
                           linkPtr->getIsPinned(),
                           linkPtr->getIsHided(),
                           linkPtr->getIsNotAvailable(),
                           linkPtr->getAutoSpeedSelection(),
                           linkPtr->getIsUpgradingState());
}

void LinkManager::exportPinnedLinksToXML()
{
    return;
    const TimerController timerGuard(timer_.get());

    const QString filePath = pinnedLinksFilePath();

    QDir dir(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation));
    if (!dir.exists()) {
        if (!dir.mkpath(".")) {
            return;
        }
    }

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return;
    }

    QXmlStreamWriter xmlWriter(&file);
    xmlWriter.setAutoFormatting(true);
    xmlWriter.writeStartDocument();
    xmlWriter.writeStartElement("pinned_links");

    for (auto& itm : list_) {
        if (itm->getIsPinned()) {
            xmlWriter.writeStartElement("link");
            xmlWriter.writeTextElement("uuid", itm->getUuid().toString());
            xmlWriter.writeTextElement("control_type", QString::number(static_cast<int>(itm->getControlType())));
            xmlWriter.writeTextElement("port_name", itm->getPortName());
            xmlWriter.writeTextElement("baudrate", QString::number(itm->getBaudrate()));
            xmlWriter.writeTextElement("parity", QVariant(static_cast<bool>(itm->getParity())).toString());
            xmlWriter.writeTextElement("link_type", QString::number(static_cast<int>(itm->getLinkType())));
            xmlWriter.writeTextElement("address", itm->getAddress());
            xmlWriter.writeTextElement("source_port", QString::number(itm->getSourcePort()));
            xmlWriter.writeTextElement("destination_port", QString::number(itm->getDestinationPort()));
            xmlWriter.writeTextElement("is_pinned", QVariant(static_cast<bool>(itm->getIsPinned())).toString());
            xmlWriter.writeTextElement("is_hided", QVariant(static_cast<bool>(itm->getIsHided())).toString());
            xmlWriter.writeTextElement("is_not_available", QVariant(static_cast<bool>(itm->getIsNotAvailable())).toString());
            xmlWriter.writeTextElement("connection_status", QVariant(static_cast<bool>(itm->getConnectionStatus())).toString());
            xmlWriter.writeTextElement("auto_speed_selection", QVariant(static_cast<bool>(itm->getAutoSpeedSelection())).toString());
            xmlWriter.writeEndElement();
        }
    }

    xmlWriter.writeEndElement();
    xmlWriter.writeEndDocument();
    file.close();
}

QString LinkManager::pinnedLinksFilePath() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)
        + QStringLiteral("/pinned_links.xml");
}

bool LinkManager::parsePinnedLinksXmlData(const QByteArray& xmlData, QList<PinnedLinkRecord>* records, QString* error) const
{
    if (!records) {
        if (error) {
            *error = QStringLiteral("records output is null");
        }
        return false;
    }

    records->clear();

    if (xmlData.trimmed().isEmpty()) {
        return true;
    }

    QXmlStreamReader xmlReader(xmlData);

    while (!xmlReader.atEnd()) {
        const auto token = xmlReader.readNext();
        if (token != QXmlStreamReader::StartElement || xmlReader.name() != QStringLiteral("link")) {
            continue;
        }

        PinnedLinkRecord record;
        while (!(xmlReader.tokenType() == QXmlStreamReader::EndElement && xmlReader.name() == QStringLiteral("link"))) {
            xmlReader.readNext();
            if (xmlReader.atEnd()) {
                break;
            }

            if (xmlReader.tokenType() != QXmlStreamReader::StartElement) {
                continue;
            }

            const QString tag = xmlReader.name().toString();
            if (tag == QStringLiteral("uuid")) {
                record.uuid = QUuid(xmlReader.readElementText());
            }
            else if (tag == QStringLiteral("connection_status")) {
                record.connectionStatus = xmlBoolValue(xmlReader.readElementText());
            }
            else if (tag == QStringLiteral("control_type")) {
                record.controlType = static_cast<ControlType>(xmlReader.readElementText().toInt());
            }
            else if (tag == QStringLiteral("port_name")) {
                record.portName = xmlReader.readElementText();
            }
            else if (tag == QStringLiteral("baudrate")) {
                record.baudrate = xmlReader.readElementText().toInt();
            }
            else if (tag == QStringLiteral("parity")) {
                record.parity = xmlBoolValue(xmlReader.readElementText());
            }
            else if (tag == QStringLiteral("link_type")) {
                record.linkType = static_cast<LinkType>(xmlReader.readElementText().toInt());
            }
            else if (tag == QStringLiteral("address")) {
                record.address = xmlReader.readElementText();
            }
            else if (tag == QStringLiteral("source_port")) {
                record.sourcePort = xmlReader.readElementText().toInt();
            }
            else if (tag == QStringLiteral("destination_port")) {
                record.destinationPort = xmlReader.readElementText().toInt();
            }
            else if (tag == QStringLiteral("is_pinned")) {
                record.isPinned = xmlBoolValue(xmlReader.readElementText());
            }
            else if (tag == QStringLiteral("is_hided")) {
                record.isHided = xmlBoolValue(xmlReader.readElementText());
            }
            else if (tag == QStringLiteral("is_not_available")) {
                record.isNotAvailable = xmlBoolValue(xmlReader.readElementText());
            }
            else if (tag == QStringLiteral("auto_speed_selection")) {
                record.autoSpeedSelection = xmlBoolValue(xmlReader.readElementText());
            }
            else {
                xmlReader.skipCurrentElement();
            }
        }

        if (record.uuid.isNull()) {
            record.uuid = QUuid::createUuid();
        }
        records->append(record);
    }

    if (xmlReader.hasError()) {
        if (error) {
            *error = xmlReader.errorString();
        }
        records->clear();
        return false;
    }

    return true;
}

bool LinkManager::looksLikeSerialPortName(const QString& portName)
{
    const QString normalized = portName.trimmed();
    if (normalized.isEmpty()) {
        return false;
    }

    if (normalized.startsWith(QStringLiteral("/dev/tty"), Qt::CaseInsensitive) ||
        normalized.startsWith(QStringLiteral("/dev/cu"), Qt::CaseInsensitive)) {
        return true;
    }

    static const QRegularExpression comPortExpression(QStringLiteral(R"(^COM\d+$)"),
                                                      QRegularExpression::CaseInsensitiveOption);
    return comPortExpression.match(normalized).hasMatch();
}

void LinkManager::appendPinnedLinkRecords(const QList<PinnedLinkRecord>& records)
{
    for (const PinnedLinkRecord& record : records) {
        Link* link = createNewLink();
        link->setUuid(record.uuid);
        link->setControlType(record.controlType);
        link->setPortName(record.portName);
        link->setBaudrate(record.baudrate);
        link->setParity(record.parity);
        link->setLinkType(record.linkType);
        link->setAddress(record.address);
        link->setSourcePort(record.sourcePort);
        link->setDestinationPort(record.destinationPort);
        link->setIsPinned(true);
        link->setIsHided(record.isHided);
        link->setIsNotAvailable(record.isNotAvailable);
        link->setAutoSpeedSelection(record.autoSpeedSelection);
        link->setIsForceStopped(false);

        list_.append(link);
        doEmitAppendModifyModel(link);

        if (record.connectionStatus) {
            link->setConnectionStatus(true);
            doEmitAppendModifyModel(link);
        }
    }
}

bool LinkManager::reloadPinnedLinksFromXmlData(const QByteArray& xmlData,
                                               bool allowSerialLinks,
                                               int* skippedSerialLinks,
                                               QString* error)
{
    const TimerController timerGuard(timer_.get());
    if (skippedSerialLinks) {
        *skippedSerialLinks = 0;
    }

    QList<PinnedLinkRecord> records;
    QString parseError;
    if (!parsePinnedLinksXmlData(xmlData, &records, &parseError)) {
        if (error) {
            *error = parseError;
        }
        return false;
    }

    if (!allowSerialLinks) {
        QList<PinnedLinkRecord> filteredRecords;
        filteredRecords.reserve(records.size());
        int skippedCount = 0;

        for (const PinnedLinkRecord& record : records) {
            const bool isSerialByType = record.linkType == LinkType::kLinkSerial;
            const bool isSerialByPortName = looksLikeSerialPortName(record.portName);
            if (isSerialByType || isSerialByPortName) {
                ++skippedCount;
                continue;
            }

            filteredRecords.append(record);
        }

        records = filteredRecords;
        if (skippedSerialLinks) {
            *skippedSerialLinks = skippedCount;
        }
    }

    // Stop all currently active links before replacing pinned set.
    for (Link* link : list_) {
        if (!link) {
            continue;
        }
        if (link->isOpen()) {
            link->close();
        }
        doEmitAppendModifyModel(link);
    }

    // Remove all existing pinned links.
    for (int i = list_.size() - 1; i >= 0; --i) {
        Link* link = list_.at(i);
        if (!link || !link->getIsPinned()) {
            continue;
        }

        emit linkDeleted(link->getUuid(), link);
        emit deleteModel(link->getUuid());

        link->disconnect();
        this->disconnect(link);

        if (link->isOpen()) {
            link->close();
        }

        list_.removeAt(i);
        delete link;
    }

    appendPinnedLinkRecords(records);
    exportPinnedLinksToXML();
    coldStarted_ = false;
    return true;
}

Link *LinkManager::createNewLink() const
{
    Link* retVal = new Link();
    //qDebug() << "LinkManager::createNewLink";
    if (bus_) {
        retVal->setSettingsBus(bus_);
    }

    QObject::connect(retVal, &Link::connectionStatusChanged, this, &LinkManager::onLinkConnectionStatusChanged);
    QObject::connect(retVal, &Link::upgradingFirmwareStateChanged, this, &LinkManager::onUpgradingFirmwareStateChanged);
    QObject::connect(retVal, &Link::frameReady, this, &LinkManager::frameReady);
    QObject::connect(retVal, &Link::closed, this, &LinkManager::linkClosed);
    QObject::connect(retVal, &Link::opened, this, &LinkManager::linkOpened);
    QObject::connect(retVal, &Link::baudrateChanged, this, &LinkManager::onLinkIsReceivesDataChanged);
    QObject::connect(retVal, &Link::isReceivesDataChanged, this, &LinkManager::onLinkIsReceivesDataChanged);
    QObject::connect(retVal, &Link::sendDoRequestAll, this, &LinkManager::sendDoRequestAll);
    //Pulse
    QObject::connect(retVal, &Link::opened, this, &LinkManager::handleLinkOpened);

    return retVal;
}

void LinkManager::handleLinkOpened(QUuid uuid, Link* link)
{

    if (link && link->getLinkType() == LinkType::kLinkSerial) {
        uuidUsbSerial_ = uuid.toString(QUuid::WithBraces);
        qDebug() << "LinkManager::handleLinkOpened - serial opened, keep track of serial uuid" << uuidUsbSerial_;
    }
    if (link->getLinkType() == LinkType::kLinkIPUDP && !link->getIsProxy()) {
        uuidIpGateway_ = uuid.toString(QUuid::WithBraces);
        qDebug() << "LinkManager::handleLinkOpened - UDP opened, keep track of UDP uuid" << uuidIpGateway_;
    }

    emit linkOpened(uuid, link); // re-emit manager signal
}

void LinkManager::printLinkDebugInfo(Link* link) const
{
    const TimerController timerGuard(timer_.get());

    if (!link)
        qDebug() << "\tlink is nullptr";
    else {
        qDebug() << QString("uuid: %1; controlType: %2; portName: %3; baudrate: %4; parity: %5; linkType: %6; address: %7; sourcePort: %8; destinationPort: %9; isPinned: %10; isHided: %11; isNotAvailable: %12; connectionStatus: %13")
                        .arg(link->getUuid().toString()).arg(static_cast<int>(link->getControlType())).arg(link->getPortName()).arg(link->getBaudrate()).arg(link->getParity())
                        .arg(static_cast<int>(link->getLinkType())).arg(link->getAddress()).arg(link->getSourcePort()).arg(link->getDestinationPort()).arg(link->getIsPinned())
                        .arg(link->getIsHided()).arg(link->getIsNotAvailable()).arg(link->getConnectionStatus());
    }
}

QString LinkManager::getAndroidGatewayIP()
{
#ifdef Q_OS_ANDROID
    QString ip = udpGateway_; // fallback / last known

    auto fut = QNativeInterface::QAndroidApplication::runOnAndroidMainThread([fallback = ip]() -> QVariant {
        QJniObject context = QNativeInterface::QAndroidApplication::context();
        if (!context.isValid())
            return fallback;

        // Use Context.WIFI_SERVICE (safer than hardcoding "wifi")
        QJniObject wifiServiceName = QJniObject::getStaticObjectField(
            "android/content/Context", "WIFI_SERVICE", "Ljava/lang/String;");

        QJniObject wifiService = context.callObjectMethod(
            "getSystemService",
            "(Ljava/lang/String;)Ljava/lang/Object;",
            wifiServiceName.object<jstring>());

        if (!wifiService.isValid())
            return fallback;

        QJniObject dhcpInfo = wifiService.callObjectMethod("getDhcpInfo", "()Landroid/net/DhcpInfo;");
        if (!dhcpInfo.isValid())
            return fallback;

        const jint gateway = dhcpInfo.getField<jint>("gateway");
        if (gateway == 0)
            return fallback;

        const quint32 gw = static_cast<quint32>(gateway);
        const QString detected = QString("%1.%2.%3.%4")
                                     .arg(gw & 0xFF)
                                     .arg((gw >> 8) & 0xFF)
                                     .arg((gw >> 16) & 0xFF)
                                     .arg((gw >> 24) & 0xFF);

        return detected;
    });

    fut.waitForFinished();
    ip = fut.result().toString();

    qDebug() << "Detected gateway IP:" << ip;

    // --- your allow/override logic unchanged below ---
    bool allowed = ip.startsWith("192.168.10");
    if (isBetaTester_) {
        allowed = ip.startsWith("192.168.10.") ||
                  ip.startsWith("192.168.2.")   ||
                  ip.startsWith("192.168.144.") ;
        //if (ip.startsWith("192.168.144."))
        //    ip = "192.168.144.31";
    } else if (isExpert_) {
        allowed = ip.startsWith("192.168.10.")  ||
                  ip.startsWith("192.168.2.")   ||
                  ip.startsWith("192.168.144.") ||
                  ip.startsWith("10.0.0.");
        //if (ip.startsWith("192.168.144."))
        //    ip = "192.168.144.31";
    } else {
        allowed = ip.startsWith("192.168.10.")  ||
                  ip.startsWith("192.168.144.");
        //if (ip.startsWith("192.168.144."))
        //    ip = "192.168.144.31";
    }

    if (ip.startsWith("192.168.144."))
        ip = "192.168.144.31";

    if (!allowed) {
        qWarning() << "Gateway IP" << ip << "not allowed, using default:" << udpGateway_;
        ip = udpGateway_;
    } else {
        if (bus_) bus_->updatePersistent({ { "udpGateway", ip } });
        qDebug() << "Gateway IP accepted; updated persistent udpGateway to" << ip;
    }

    return ip;
#else
    return udpGateway_;
#endif
}



void LinkManager::importPinnedLinksFromXML()
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "PulseAppSettings::importPinnedLinksFromXML";

    int udpPort = 14560;
    //if (isBetaTester_) udpPort = 14550;
    if (isExpert_ || isBetaTester_)     udpPort = udpPort_;
#ifdef Q_OS_ANDROID
    const QString gatewayIP = getAndroidGatewayIP();
#else
    const QString gatewayIP = udpGateway_;
#endif
    const QString uuidIp = uuidIpGateway_;
    const QString uuidUsb = uuidUsbSerial_;

    QString xmlData = "";
    #ifdef Q_OS_ANDROID

    xmlData = QString(R"(
    <pinned_links>
        <link>
            <uuid>%1</uuid>
            <control_type>0</control_type>
            <port_name></port_name>
            <baudrate>0</baudrate>
            <parity>false</parity>
            <link_type>2</link_type>
            <address>%2</address>
            <source_port>%3</source_port>
            <destination_port>%3</destination_port>
            <is_pinned>true</is_pinned>
            <is_hided>false</is_hided>
            <is_not_available>false</is_not_available>
            <connection_status>true</connection_status>
        </link>
    </pinned_links>
    )")
      .arg(uuidIp)
      .arg(gatewayIP)
      .arg(udpPort);

    #endif

    #ifdef Q_OS_WINDOWS

    xmlData = QString(R"(
    <pinned_links>
        <link>
            <uuid>%1</uuid>
            <control_type>0</control_type>
            <port_name></port_name>
            <baudrate>0</baudrate>
            <parity>false</parity>
            <link_type>2</link_type>
            <address>%2</address>
            <source_port>%3</source_port>
            <destination_port>%3</destination_port>
            <is_pinned>true</is_pinned>
            <is_hided>false</is_hided>
            <is_not_available>false</is_not_available>
            <connection_status>true</connection_status>
        </link>
    </pinned_links>
    )")
                  .arg(uuidIp)
                  .arg(gatewayIP)
                  .arg(udpPort);

    #endif

    QXmlStreamReader xmlReader(xmlData);

    while (!xmlReader.atEnd() && !xmlReader.hasError()) {
        const QXmlStreamReader::TokenType token = xmlReader.readNext();

        if (token == QXmlStreamReader::StartElement) {
            if (xmlReader.name() == "link") {
                Link* link = createNewLink();

                while (!(xmlReader.tokenType() == QXmlStreamReader::EndElement && xmlReader.name() == "link")) {
                    if (xmlReader.tokenType() == QXmlStreamReader::StartElement) {
                        if (xmlReader.name().toString() == "uuid") {
                            link->setUuid(QUuid(xmlReader.readElementText()));
                        }
                        else if (xmlReader.name().toString() == "connection_status") {
                            link->setConnectionStatus(xmlReader.readElementText().trimmed().toUpper() == "TRUE" ? true : false);
                        }
                        else if (xmlReader.name().toString() == "control_type") {
                            link->setControlType(static_cast<ControlType>(xmlReader.readElementText().toInt()));
                        }
                        else if (xmlReader.name().toString() == "port_name") {
                            link->setPortName(xmlReader.readElementText());
                        }
                        else if (xmlReader.name().toString() == "baudrate") {
                            link->setBaudrate(xmlReader.readElementText().toInt());
                        }
                        else if (xmlReader.name().toString() == "parity") {
                            link->setParity(xmlReader.readElementText().trimmed().toUpper() == "TRUE" ? true : false);
                        }
                        else if (xmlReader.name().toString() == "link_type") {
                            link->setLinkType(static_cast<LinkType>(xmlReader.readElementText().toInt()));
                        }
                        else if (xmlReader.name().toString() == "address") {
                            link->setAddress(xmlReader.readElementText());
                        }
                        else if (xmlReader.name().toString() == "source_port") {
                            link->setSourcePort(xmlReader.readElementText().toInt());
                        }
                        else if (xmlReader.name().toString() == "destination_port") {
                            link->setDestinationPort(xmlReader.readElementText().toInt());
                        }
                        else if (xmlReader.name().toString() == "is_pinned") {
                            link->setIsPinned(xmlReader.readElementText().trimmed().toUpper() == "TRUE" ? true : false);
                        }
                        else if (xmlReader.name().toString() == "is_hided") {
                            link->setIsHided(xmlReader.readElementText().trimmed().toUpper() == "TRUE" ? true : false);
                        }
                        else if (xmlReader.name().toString() == "is_not_available") {
                            link->setIsNotAvailable(xmlReader.readElementText().trimmed().toUpper() == "TRUE" ? true : false);
                        }
                        else if (xmlReader.name().toString() == "auto_speed_selection") {
                            link->setAutoSpeedSelection(xmlReader.readElementText().trimmed().toUpper() == "TRUE" ? true : false);
                        }
                    }
                    xmlReader.readNext();
                }

                list_.append(link);
                doEmitAppendModifyModel(link);
            }
        }
    }

    //file.close();
}

void LinkManager::onLinkConnectionStatusChanged(QUuid uuid)
{
    const TimerController timerGuard(timer_.get());
    //qDebug() << "LinkManager::onLinkConnectionStatusChanged for uuid" << uuid;

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        doEmitAppendModifyModel(linkPtr);

        if (linkPtr->getIsPinned() && linkPtr->getConnectionStatus()) {
            exportPinnedLinksToXML();
        }
    }
}

void LinkManager::onUpgradingFirmwareStateChanged(QUuid uuid)
{
    const TimerController timerGuard(timer_.get());

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        doEmitAppendModifyModel(linkPtr);
    }
}

void LinkManager::onLinkBaudrateChanged(QUuid uuid)
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "LinkManager::onLinkBaudrateChanged for uuid" << uuid;

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        doEmitAppendModifyModel(linkPtr);

        if (linkPtr->getIsPinned()) {
            exportPinnedLinksToXML();
        }
    }
}

void LinkManager::onLinkIsReceivesDataChanged(QUuid uuid)
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "LinkManager::onLinkIsReceivesDataChanged for uuid" << uuid;
    if (bus_) {
        QVariantMap m;
        bool shouldUpdateRuntime = false;

        if (auto* link = getLinkPtr(uuid)) {
            const bool active = link->getIsRecievesData();
            LinkType type = link->getLinkType();
            const QUuid gwUuidWifi{uuidIpGateway_};
            const QUuid gwUuidSerial{uuidUsbSerial_};
            const QUuid proxyLink(uuidProxyLink_);

            if (active) {
                //USB type: If receiving we close UDP link (but not the proxyLink)
                if (type == LinkType::kLinkSerial) {
                    if (auto* usbLink = getLinkPtr(uuid)) {
                        bool usbReceivesData = usbLink->getIsRecievesData();
                        if (usbReceivesData) {
                            uuidUsbSerial_ = uuid.toString(QUuid::WithBraces);
                            //gwUuidSerial{uuidUsbSerial_};
                            uuidSuccessfullyOpened_ = uuid.toString(QUuid::WithBraces);
                            shouldUpdateRuntime = true;
                            auto* wifiLink = getLinkPtr(gwUuidWifi);
                            if (wifiLink && uuid != proxyLink) {
                                wifiLink->setIsForceStopped(true);
                                closeLink(gwUuidWifi);
                            }
                        }
                    }
                }
                if (type == LinkType::kLinkIPUDP) {
                    if (auto* udpLink = getLinkPtr(uuid)) {
                        bool udpReceivesData = udpLink->getIsRecievesData();
                        if (udpReceivesData) {
                            if (uuid != proxyLink) {
                                uuidIpGateway_ = uuid.toString(QUuid::WithBraces);
                                uuidSuccessfullyOpened_ = uuid.toString(QUuid::WithBraces);
                                shouldUpdateRuntime = true;
                            }
                        }
                    }
                    /*
                    if (uuid == proxyLink) {
                        uuidProxyLink_ = uuid.toString(QUuid::WithBraces);
                    } else {
                        if (uuidSuccessfullyOpened_ != uuidUsbSerial_) {
                            uuidIpGateway_ = uuid.toString(QUuid::WithBraces);
                            uuidSuccessfullyOpened_ = uuid.toString(QUuid::WithBraces);
                        }
                    }
                    uuidIpGateway_ = uuid.toString(QUuid::WithBraces);
                    */
                }
                /*
                if (uuid == gwUuidWifi && uuid != proxyLink) {
                    if (!uuidUsbSerial_.isEmpty()){
                        if (auto* usbLink = getLinkPtr(gwUuidSerial)) {
                            bool usbReceivesData = usbLink->getIsRecievesData();
                            if (usbReceivesData) {
                                qDebug() << "LinkManager::onLinkIsReceivesDataChanged: Wi-Fi became active but serial exists; keep serial and close Wi-Fi";
                                if (auto* wifi = getLinkPtr(gwUuidWifi)) {
                                    wifi->setIsForceStopped(true);
                                    closeLink(gwUuidWifi);
                                }
                            }
                        }

                    }
                }
                if (uuid == gwUuidSerial) {
                    uuidSuccessfullyOpened_ = uuid.toString(QUuid::WithBraces);
                    auto* gw = getLinkPtr(uuidIpGateway_);
                    qDebug() << "LinkManager::onLinkIsReceivesDataChanged - serial - close the wifi" << uuidIpGateway_;
                    gw->setIsForceStopped(true);
                    closeLink(gwUuidWifi);
                }
                */
                m.insert("uuidSuccessfullyOpened", uuidSuccessfullyOpened_);
                if (!uuidSuccessfullyOpened_.isEmpty())  m.insert("uuidSuccessfullyOpened",  uuidSuccessfullyOpened_);
                if (!uuidUsbSerial_.isEmpty())           m.insert("uuidUsbSerial",           uuidUsbSerial_);
                if (!uuidIpGateway_.isEmpty())           m.insert("uuidIpGateway",           uuidIpGateway_);


                //shouldUpdateRuntime = true;
            }
        }
        // cross-thread safe
        if (shouldUpdateRuntime) {
            qDebug() << "LinkManager::onLinkIsReceivesDataChanged, let us also update QML runtime preferences";
            QMetaObject::invokeMethod(bus_, "updateRuntime",
                                      Qt::QueuedConnection,
                                      Q_ARG(QVariantMap, m));
        }

    }
    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        doEmitAppendModifyModel(linkPtr);
    }
}

void LinkManager::createAndStartTimer()
{
    //qDebug() << "LinkManager::createAndStartTimer";
    if (!timer_) {
        timer_ = std::make_unique<QTimer>(this);
        timer_->setInterval(timerInterval_);
        QObject::connect(timer_.get(), &QTimer::timeout, this, &LinkManager::onExpiredTimer, Qt::QueuedConnection);
    }

    timer_->start();
}

void LinkManager::stopTimer()
{
    //qDebug() << "LinkManager::stopTimer";
    if (timer_) {
        timer_->stop();
    }
}

void LinkManager::onExpiredTimer()
{
    //qDebug() << "LinkManager::onExpiredTimer";
    if (coldStarted_) {
        importPinnedLinksFromXML();
        coldStarted_ = false;
    }
    update();

    if (timer_) {
        timer_->start();
    }
}

void LinkManager::openAsSerial(QUuid uuid, LinkAttribute attribute)
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "LinkManager::openAsSerial using uuid" << uuid << "when uuidUsbSerial is" << uuidUsbSerial_;

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setAttribute(attribute);
        linkPtr->setIsForceStopped(false);
        linkPtr->openAsSerial();
    }
}

void LinkManager::openAsUdp(QUuid uuid, QString address, int sourcePort, int destinationPort, LinkAttribute attribute)
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "LinkManager::openAsUdp for uuid" << uuid;

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setAttribute(attribute);
        linkPtr->setIsForceStopped(false);
        linkPtr->updateUdpParameters(address, sourcePort, destinationPort);
        linkPtr->openAsUdp();
        doEmitAppendModifyModel(linkPtr); //
    }
}

void LinkManager::openAsTcp(QUuid uuid, QString address, int sourcePort, int destinationPort, LinkAttribute attribute)
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "LinkManager::openAsTcp for uuid" << uuid;

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setAttribute(attribute);
        linkPtr->setIsForceStopped(false);
        linkPtr->updateTcpParameters(address, sourcePort, destinationPort);
        linkPtr->openAsTcp();

        doEmitAppendModifyModel(linkPtr); //
    }
}

void LinkManager::closeLink(QUuid uuid)
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "LinkManager::closeLink for uuid" << uuid;

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        if (linkPtr->getControlType() == ControlType::kAuto)
            linkPtr->setIsForceStopped(true);
        linkPtr->close();
        doEmitAppendModifyModel(linkPtr); //

        if (linkPtr->getIsPinned()) {
            exportPinnedLinksToXML();
        }
    }
}

QUuid LinkManager::getUuidFromString(QString uuidAsString)
{
    qDebug() << "LinkManager::getUuidFromString: Asked for uuid from string" << uuidAsString;
    qDebug() << "LinkManager::getUuidFromString: already have uuidSuccessfullyOpened_" << uuidSuccessfullyOpened_;

    //const QUuid successfullyOpened{uuidSuccessfullyOpened_};
    //return QUuid::fromString(uuidAsString);
    return QUuid::fromString(uuidSuccessfullyOpened_);
}


void LinkManager::resetMyOpenLink()
{
    const QUuid successfullyOpened{uuidSuccessfullyOpened_};
    const QUuid uuidGateway{uuidIpGateway_};
    const QUuid uuidSerial{uuidUsbSerial_};

    /*

    closeLink(uuidSuccessfullyOpened_);

    if (uuidSuccessfullyOpened_ == uuidUsbSerial_) {
        openAsSerial(uuidSerial);
    } else {
        openAsUdp(uuidGateway, udpGateway_, udpPort_, LinkType::kLinkIPUDP);
    }
    */


}

void LinkManager::closeFLink(QUuid uuid)
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "LinkManager::closeFLink for uuid" << uuid;

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setIsForceStopped(true);
        linkPtr->close();
        doEmitAppendModifyModel(linkPtr); //
    }
}

void LinkManager::deleteLink(QUuid uuid)
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "LinkManager::deleteLink for uuid" << uuid;

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        emit linkDeleted(linkPtr->getUuid(), linkPtr);

        emit deleteModel(linkPtr->getUuid());
        linkPtr->disconnect();
        this->disconnect(linkPtr);

        if (linkPtr->isOpen())
            linkPtr->close();

        auto linkType = linkPtr->getLinkType();

        list_.removeOne(linkPtr);
        delete linkPtr;

        // manual deleting
        if (linkType == LinkType::kLinkIPTCP ||
            linkType == LinkType::kLinkIPUDP)
            exportPinnedLinksToXML();
    }
}

void LinkManager::updateBaudrate(QUuid uuid, int baudrate)
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "LinkManager::updateBaudrate for uuid" << uuid;

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setBaudrate(baudrate);

        doEmitAppendModifyModel(linkPtr); // why?

        if (linkPtr->getIsPinned())
            exportPinnedLinksToXML();
    }
}

void LinkManager::setRequestToSend(QUuid uuid, bool rts) {
    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setRequestToSend(rts);
    }
}

void LinkManager::setDataTerminalReady(QUuid uuid, bool dtr) {
    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setDataTerminalReady(dtr);
    }
}

void LinkManager::setParity(QUuid uuid, bool parity) {
    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setParity(parity);
    }
}

void LinkManager::setAttribute(QUuid uuid, LinkAttribute attribute) {
    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setAttribute(attribute);
    }
}

void LinkManager::updateAddress(QUuid uuid, const QString &address)
{
    const TimerController timerGuard(timer_.get());

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setAddress(address);

        //doEmitAppendModifyModel(linkPtr); // why not?
        if (linkPtr->getIsPinned())
            exportPinnedLinksToXML();
    }
}

void LinkManager::updateAutoSpeedSelection(QUuid uuid, bool state)
{
    const TimerController timerGuard(timer_.get());

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setAutoSpeedSelection(state);

        //doEmitAppendModifyModel(linkPtr); // why not?
        if (linkPtr->getIsPinned())
            exportPinnedLinksToXML();
    }
}

void LinkManager::updateSourcePort(QUuid uuid, int sourcePort)
{
    const TimerController timerGuard(timer_.get());

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setSourcePort(sourcePort);

        //doEmitAppendModifyModel(linkPtr); //
        if (linkPtr->getIsPinned())
            exportPinnedLinksToXML();
    }
}

void LinkManager::updateDestinationPort(QUuid uuid, int destinationPort)
{
    const TimerController timerGuard(timer_.get());

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setDestinationPort(destinationPort);

        //doEmitAppendModifyModel(linkPtr); //
        if (linkPtr->getIsPinned())
            exportPinnedLinksToXML();
    }
}

void LinkManager::updatePinnedState(QUuid uuid, bool state)
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "LinkManager::updateBaudrate for updatePinnedState" << uuid << "with state" << state;

    if (auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setIsPinned(state);

        exportPinnedLinksToXML();
    }
}

void LinkManager::updateControlType(QUuid uuid, ControlType controlType)
{
    const TimerController timerGuard(timer_.get());

    if (auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setControlType(controlType);

        if (linkPtr->getIsPinned())
            exportPinnedLinksToXML();
    }
}

void LinkManager::frameInput(Link *link, Parsers::FrameParser frame)
{
    Q_UNUSED(link);
    Q_UNUSED(frame);
}

void LinkManager::createAsUdp(QString address, int sourcePort, int destinationPort)
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "LinkManager::createAsUdp";

    Link* newLinkPtr = createNewLink();
    newLinkPtr->createAsUdp(address, sourcePort, destinationPort);
    list_.append(newLinkPtr);

    doEmitAppendModifyModel(newLinkPtr);
}

void LinkManager::createAsTcp(QString address, int sourcePort, int destinationPort)
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "LinkManager::createAsTcp";

    Link* newLinkPtr = createNewLink();
    newLinkPtr->createAsTcp(address, sourcePort, destinationPort);
    list_.append(newLinkPtr);

    doEmitAppendModifyModel(newLinkPtr);
}

void LinkManager::openFLinks()
{
    const TimerController timerGuard(timer_.get());
    qDebug() << "LinkManager::openFLinks";

    for (auto& itm : list_) {
        if (itm->getIsForceStopped()) {
            itm->setIsForceStopped(false);

            switch (itm->getLinkType()) {
            case LinkType::kLinkSerial: {
                //How to fix USB serial on all Android devices?
                itm->setUuid(QUuid(uuidUsbSerial_));
                itm->setControlType(static_cast<ControlType>(1));
                itm->setBaudrate(usbSerialBaud_);
                //itm->setBaudrate(921600);
                itm->setParity(false);
                itm->openAsSerial();
                qDebug() << "LinkManager::openFLinks trigger openAsSerial";
                break;
            }
            case LinkType::kLinkIPTCP : {
                itm->openAsTcp();
                qDebug() << "LinkManager::openFLinks trigger openAsTcpl";
                break;
            }
            case LinkType::kLinkIPUDP: {
                qDebug() << "LinkManager::openFLinks trigger openAsUdp";
                itm->openAsUdp();
                break;
            }
            default:
                break;
            }
        }
    }
}

void LinkManager::createAndOpenAsUdpProxy(QString address, int sourcePort, int destinationPort)
{
    // PULSE: idempotency guard. This is called from BOTH the runtime toggle
    // (DeviceItem.qml onPositionSourceAutoPilotChanged) AND logAllDevSetupAsCompleted, which runs on
    // every config cycle. The UDP bind has no SO_REUSEADDR (link.cpp openAsUdp), so a 2nd call while a
    // proxy is already up creates a Link that fails to bind 14569, leaks into list_, and OVERWRITES
    // proxyLinkUuid_ to point at that DEAD link. closeUdpProxy() then deletes the dead one and the real
    // receiver is orphaned: it keeps emitting mavlinkPeer (~1 Hz) forever and is only cleared by a full
    // reconnect — exactly the "logs keep hitting after I set the preference false" symptom.
    // Run this BEFORE constructing the TimerController so we can safely delegate to closeUdpProxy
    // (which manages its own timer) without nesting timer stop/start.
    if (proxyLinkUuid_ != QUuid()) {
        const auto existing = getLinkPtr(proxyLinkUuid_);
        if (existing && existing->isOpen()) {
            qDebug() << "LinkManager::createAndOpenAsUdpProxy: live proxy already exists for"
                     << proxyLinkUuid_ << "- skipping duplicate create";
            return;
        }
        // Stale reference (link gone or never opened): clear it before recreating.
        closeUdpProxy();
    }

    const TimerController timerGuard(timer_.get());

    Link* newLinkPtr = createNewLink();
    newLinkPtr->createAsUdp(address, sourcePort, destinationPort);
    newLinkPtr->setIsProxy(true);
    newLinkPtr->setIsHided(true);
    proxyLinkUuid_ = newLinkPtr->getUuid();
    uuidProxyLink_ = proxyLinkUuid_.toString();
    list_.append(newLinkPtr);

    if (bus_ && !uuidProxyLink_.isEmpty()) {
        QVariantMap m;
        m.insert("uuidProxyLink", uuidProxyLink_);

        QPointer<SettingsBus> safeBus(bus_);
        const QVariantMap mm = m;

        QMetaObject::invokeMethod(bus_, [safeBus, mm]() {
            if (safeBus)
                safeBus->updateRuntime(mm);
        }, Qt::QueuedConnection);
    }

    const auto connType =
        static_cast<Qt::ConnectionType>(Qt::QueuedConnection | Qt::UniqueConnection);

    QObject::connect(newLinkPtr, &Link::mavlinkPeerChanged,
                     this, &LinkManager::onProxyMavlinkPeerChanged,
                     connType);


    newLinkPtr->openAsUdp();
}

void LinkManager::onProxyMavlinkPeerChanged(const QHostAddress& addr, qint64 seenMs)
{
    const QString ip = addr.toString();
    if (seenMs != mavlinkPeerSeenMs_) {
        mavlinkPeerIp_ = ip;
        mavlinkPeerSeenMs_ = seenMs;
        emit mavlinkPeerUpdated(mavlinkPeerIp_, mavlinkPeerSeenMs_);
    }
}

/* These methods crash, but I may need some stuff from them

void LinkManager::createAndOpenAsUdpProxy(QString address, int sourcePort, int destinationPort)
{
    TimerController(timer_.get());
    qDebug() << "LinkManager::createAndOpenAsUdpProxy" << "address" << address << "sourcePort" << sourcePort << "destinationPort" << destinationPort;

    Link* newLinkPtr = createNewLink();
    newLinkPtr->createAsUdp(address, sourcePort, destinationPort);
    newLinkPtr->setIsProxy(true);
    newLinkPtr->setIsHided(true);
    proxyLinkUuid_ = newLinkPtr->getUuid();
    uuidProxyLink_ = proxyLinkUuid_.toString();
    list_.append(newLinkPtr);

    QVariantMap m;
    if (!uuidProxyLink_.isEmpty())  m.insert("uuidProxyLink",  uuidProxyLink_);
    qDebug() << "LinkManager::createAndOpenAsUdpProxy, let us also update QML runtime preferences";
    QMetaObject::invokeMethod(bus_, "updateRuntime",
                              Qt::QueuedConnection,
                              Q_ARG(QVariantMap, m));

    QObject::connect(newLinkPtr, &Link::mavlinkPeerChanged,
                     this, [this](const QHostAddress& addr, qint64 seenMs) {
                         const QString ip = addr.toString();
                         if (seenMs != mavlinkPeerSeenMs_) {
                         //if (ip != mavlinkPeerIp_ || seenMs != mavlinkPeerSeenMs_) {
                             mavlinkPeerIp_ = ip;
                             mavlinkPeerSeenMs_ = seenMs;
                             emit mavlinkPeerUpdated(mavlinkPeerIp_, mavlinkPeerSeenMs_);
                         }
                     }, Qt::UniqueConnection);

    newLinkPtr->openAsUdp();
}

void LinkManager::closeUdpProxy()
{
    if (proxyLinkUuid_ == QUuid())
        return;

    //qDebug() << "LinkManager::closeUdpProxy";
    deleteLink(proxyLinkUuid_);
    proxyLinkUuid_ = QUuid();
    uuidProxyLink_ = proxyLinkUuid_.toString();

    mavlinkPeerIp_.clear();
    mavlinkPeerSeenMs_ = 0;
    emit mavlinkPeerUpdated(mavlinkPeerIp_, mavlinkPeerSeenMs_);

    QVariantMap m;
    if (!uuidProxyLink_.isEmpty())  m.insert("uuidProxyLink",  uuidProxyLink_);
    qDebug() << "LinkManager::createAndOpenAsUdpProxy, let us also update QML runtime preferences";
    QMetaObject::invokeMethod(bus_, "updateRuntime",
                              Qt::QueuedConnection,
                              Q_ARG(QVariantMap, m));
}
*/

void LinkManager::closeUdpProxy()
{
    if (proxyLinkUuid_ == QUuid())
        return;

    deleteLink(proxyLinkUuid_);
    proxyLinkUuid_ = QUuid();
    uuidProxyLink_ = proxyLinkUuid_.toString();

    mavlinkPeerIp_.clear();
    mavlinkPeerSeenMs_ = 0;
    emit mavlinkPeerUpdated(mavlinkPeerIp_, mavlinkPeerSeenMs_);

    if (bus_) {
        QVariantMap m;
        m.insert("uuidProxyLink", uuidProxyLink_);

        QPointer<SettingsBus> safeBus(bus_);
        const QVariantMap mm = m;

        QMetaObject::invokeMethod(bus_, [safeBus, mm]() {
            if (safeBus)
                safeBus->updateRuntime(mm);
        }, Qt::QueuedConnection);
    }

}

QUuid LinkManager::getFirstOpend() {
    for (auto& itm : list_) {
        if (itm->isOpen()) {
            qDebug() << "LinkManager::getFirstOpend with uuid" << itm->getUuid();
            return itm->getUuid();
        }
    }
    return QUuid();
}

LinkManager::TimerController::TimerController(QTimer *timer) : timer_(timer)
{
    if (timer_) {
        timer->stop();
    }
}

LinkManager::TimerController::~TimerController()
{
    if (timer_) {
        timer_->start();
    }
}
