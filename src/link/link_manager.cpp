#include "link_manager.h"

#include <QFile>
#include <QXmlStreamReader>
#include <QDebug>
#include <QStandardPaths>
#include <QDir>
#include <QThread>
#if defined(Q_OS_ANDROID)
#include <QAndroidJniObject>
#include <QtAndroid>
#endif
#include <QDebug>
#include "SettingsBus.h"


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
    if (m.contains("uuidIpGateway"))
        uuidIpGateway_ = m.value("uuidIpGateway").toString();
    if (m.contains("uuidUsbSerial"))
        uuidUsbSerial_ = m.value("uuidUsbSerial").toString();
}

void LinkManager::applyPersistent(const QVariantMap& m)
{
    if (m.contains("udpGateway"))   udpGateway_   = m.value("udpGateway").toString();
    if (m.contains("isBetaTester")) isBetaTester_ = m.value("isBetaTester").toBool();
    if (m.contains("isExpert"))     isExpert_     = m.value("isExpert").toBool();
    if (m.contains("udpPort"))      udpPort_      = m.value("udpPort").toInt();
    qDebug() << "QA_ver_0.96: persistent values: udpGateway" << udpGateway_ << "isBetaTester" << isBetaTester_ << "isExpert" << isExpert_ << "udpPort" << udpPort_;
}


QList<QSerialPortInfo> LinkManager::getCurrentSerialList() const
{
    return QSerialPortInfo::availablePorts();
}

Link* LinkManager::createSerialPort(const QSerialPortInfo &serialInfo) const
{
    //qDebug() << "LinkManager::createSerialPort";
    Link* newLinkPtr = nullptr;

    if (serialInfo.isNull())
        return newLinkPtr;
    newLinkPtr = createNewLink();
    newLinkPtr->createAsSerial(serialInfo.portName(), 921600, false);   

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

#if !defined(Q_OS_ANDROID)
    deleteMissingLinks(currSerialList);
#endif

    openAutoConnections();
}

Link* LinkManager::getLinkPtr(QUuid uuid)
{
    TimerController(timer_.get());
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
    TimerController(timer_.get());
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
    TimerController(timer_.get());

    QString filePath = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/pinned_links.xml";

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

Link *LinkManager::createNewLink() const
{
    Link* retVal = new Link();
    //qDebug() << "LinkManager::createNewLink";

    QObject::connect(retVal, &Link::connectionStatusChanged, this, &LinkManager::onLinkConnectionStatusChanged);
    QObject::connect(retVal, &Link::upgradingFirmwareStateChanged, this, &LinkManager::onUpgradingFirmwareStateChanged);
    QObject::connect(retVal, &Link::frameReady, this, &LinkManager::frameReady);
    QObject::connect(retVal, &Link::closed, this, &LinkManager::linkClosed);
    QObject::connect(retVal, &Link::opened, this, &LinkManager::linkOpened);
    QObject::connect(retVal, &Link::baudrateChanged, this, &LinkManager::onLinkIsReceivesDataChanged);
    QObject::connect(retVal, &Link::isReceivesDataChanged, this, &LinkManager::onLinkIsReceivesDataChanged);
    QObject::connect(retVal, &Link::sendDoRequestAll, this, &LinkManager::sendDoRequestAll);

    return retVal;
}

void LinkManager::printLinkDebugInfo(Link* link) const
{
    TimerController(timer_.get());

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
    QString ip = udpGateway_; // start from last known/persisted
    // 1) pull gateway via Android APIs
    QAndroidJniObject activity = QtAndroid::androidActivity();
    if (!activity.isValid()) {
        qWarning() << "Android activity not valid";
        return ip;
    }
    QAndroidJniObject wifiService = activity.callObjectMethod(
        "getSystemService",
        "(Ljava/lang/String;)Ljava/lang/Object;",
        QAndroidJniObject::fromString("wifi").object<jstring>());
    if (!wifiService.isValid()) {
        qWarning() << "Wifi service not available";
        return ip;
    }
    QAndroidJniObject dhcpInfo = wifiService.callObjectMethod("getDhcpInfo", "()Landroid/net/DhcpInfo;");
    if (!dhcpInfo.isValid()) {
        qWarning() << "Could not get DhcpInfo";
        return ip;
    }
    jint gateway = dhcpInfo.getField<jint>("gateway");
    ip = QString("%1.%2.%3.%4")
             .arg(gateway        & 0xFF)
             .arg((gateway >> 8) & 0xFF)
             .arg((gateway >> 16)& 0xFF)
             .arg((gateway >> 24)& 0xFF);

    qDebug() << "Detected gateway IP:" << ip;

    // 2) allow/override based on tester/expert flags
    bool allowed = ip.startsWith("192.168.10");
    if (isBetaTester_) {
        allowed = ip.startsWith("192.168.10.") ||
                  ip.startsWith("192.168.2.");
    }
    if (isExpert_) {
        allowed = ip.startsWith("192.168.10.")  ||
                  ip.startsWith("192.168.2.")   ||
                  ip.startsWith("192.168.144.") ||
                  ip.startsWith("10.0.0.");
        if (ip.startsWith("192.168.144."))
            ip = "192.168.144.31";
    }

    if (!allowed) {
        qWarning() << "Gateway IP" << ip << "not allowed, using default:" << udpGateway_;
        ip = udpGateway_;
    } else {
        // publish back to persistent settings (so QML + disk get updated)
        if (bus_) bus_->updatePersistent({ { "udpGateway", ip } });
        qDebug() << "Gateway IP accepted; updated persistent udpGateway to" << ip;
    }
    qDebug() << "QA_ver_0.96: values at verifying IP: udpGateway" << udpGateway_ << "isBetaTester" << isBetaTester_ << "isExpert" << isExpert_ << "udpPort" << udpPort_;
    qDebug() << "QA_ver_0.96: resulting IP"<< ip;
    return ip;
#else
    return udpGateway_;
#endif
}



void LinkManager::importPinnedLinksFromXML()
{
    TimerController(timer_.get());
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
        <link>
            <uuid>%4</uuid>
            <control_type>1</control_type>
            <port_name>/dev/bus/usb/001/002</port_name>
            <baudrate>921600</baudrate>
            <parity>false</parity>
            <link_type>1</link_type>
            <address></address>
            <source_port></source_port>
            <destination_port></destination_port>
            <is_pinned>true</is_pinned>
            <is_hided>false</is_hided>
            <is_not_available>false</is_not_available>
            <connection_status>true</connection_status>
        </link>
    </pinned_links>
    )")
      .arg(uuidIp)
      .arg(gatewayIP)
      .arg(udpPort)
      .arg(uuidUsb);

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
    TimerController(timer_.get());
    //qDebug() << "LinkManager::onLinkConnectionStatusChanged for uuid" << uuid;

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        doEmitAppendModifyModel(linkPtr);
    }
}

void LinkManager::onUpgradingFirmwareStateChanged(QUuid uuid)
{
    TimerController(timer_.get());

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        doEmitAppendModifyModel(linkPtr);
    }
}

void LinkManager::onLinkBaudrateChanged(QUuid uuid)
{
    TimerController(timer_.get());
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
    TimerController(timer_.get());
    qDebug() << "LinkManager::onLinkIsReceivesDataChanged for uuid" << uuid;
    if (bus_) {
        QVariantMap m;

        if (auto* link = getLinkPtr(uuid)) {
            const bool active = link->getIsRecievesData();
            m.insert("uuidSuccessfullyOpened", active ? uuid.toString(QUuid::WithBraces) : QString());
        } else {
            m.insert("uuidSuccessfullyOpened", QString());
        }

        // cross-thread safe
        QMetaObject::invokeMethod(bus_, "updateRuntime",
                                  Qt::QueuedConnection,
                                  Q_ARG(QVariantMap, m));
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
    TimerController(timer_.get());
    qDebug() << "LinkManager::openAsSerial using uuid" << uuid << "when uuidUsbSerial is" << uuidUsbSerial_;

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setAttribute(attribute);
        linkPtr->setIsForceStopped(false);
        linkPtr->openAsSerial();
    }
}

void LinkManager::openAsUdp(QUuid uuid, QString address, int sourcePort, int destinationPort, LinkAttribute attribute)
{
    TimerController(timer_.get());
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
    TimerController(timer_.get());
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
    TimerController(timer_.get());
    qDebug() << "LinkManager::closeLink for uuid" << uuid;

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        if (linkPtr->getControlType() == ControlType::kAuto)
            linkPtr->setIsForceStopped(true);
        linkPtr->close();
        doEmitAppendModifyModel(linkPtr); //
    }
}

void LinkManager::closeFLink(QUuid uuid)
{
    TimerController(timer_.get());
    qDebug() << "LinkManager::closeFLink for uuid" << uuid;

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setIsForceStopped(true);
        linkPtr->close();
        doEmitAppendModifyModel(linkPtr); //
    }
}

void LinkManager::deleteLink(QUuid uuid)
{
    TimerController(timer_.get());
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
    TimerController(timer_.get());
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
    TimerController(timer_.get());

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setAddress(address);

        //doEmitAppendModifyModel(linkPtr); // why not?
        if (linkPtr->getIsPinned())
            exportPinnedLinksToXML();
    }
}

void LinkManager::updateAutoSpeedSelection(QUuid uuid, bool state)
{
    TimerController(timer_.get());

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setAutoSpeedSelection(state);

        //doEmitAppendModifyModel(linkPtr); // why not?
        if (linkPtr->getIsPinned())
            exportPinnedLinksToXML();
    }
}

void LinkManager::updateSourcePort(QUuid uuid, int sourcePort)
{
    TimerController(timer_.get());

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setSourcePort(sourcePort);

        //doEmitAppendModifyModel(linkPtr); //
        if (linkPtr->getIsPinned())
            exportPinnedLinksToXML();
    }
}

void LinkManager::updateDestinationPort(QUuid uuid, int destinationPort)
{
    TimerController(timer_.get());

    if (const auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setDestinationPort(destinationPort);

        //doEmitAppendModifyModel(linkPtr); //
        if (linkPtr->getIsPinned())
            exportPinnedLinksToXML();
    }
}

void LinkManager::updatePinnedState(QUuid uuid, bool state)
{
    TimerController(timer_.get());
    qDebug() << "LinkManager::updateBaudrate for updatePinnedState" << uuid << "with state" << state;

    if (auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setIsPinned(state);

        exportPinnedLinksToXML();
    }
}

void LinkManager::updateControlType(QUuid uuid, ControlType controlType)
{
    TimerController(timer_.get());

    if (auto linkPtr = getLinkPtr(uuid); linkPtr) {
        linkPtr->setControlType(controlType);

        if (linkPtr->getIsPinned())
            exportPinnedLinksToXML();
    }
}

void LinkManager::frameInput(Link *link, FrameParser frame)
{
    Q_UNUSED(link);
    Q_UNUSED(frame);
}

void LinkManager::createAsUdp(QString address, int sourcePort, int destinationPort)
{
    TimerController(timer_.get());
    qDebug() << "LinkManager::createAsUdp";

    Link* newLinkPtr = createNewLink();
    newLinkPtr->createAsUdp(address, sourcePort, destinationPort);
    list_.append(newLinkPtr);

    doEmitAppendModifyModel(newLinkPtr);
}

void LinkManager::createAsTcp(QString address, int sourcePort, int destinationPort)
{
    TimerController(timer_.get());
    qDebug() << "LinkManager::createAsTcp";

    Link* newLinkPtr = createNewLink();
    newLinkPtr->createAsTcp(address, sourcePort, destinationPort);
    list_.append(newLinkPtr);

    doEmitAppendModifyModel(newLinkPtr);
}

void LinkManager::openFLinks()
{
    TimerController(timer_.get());
    qDebug() << "LinkManager::openFLinks";

    for (auto& itm : list_) {
        if (itm->getIsForceStopped()) {
            itm->setIsForceStopped(false);

            switch (itm->getLinkType()) {
            case LinkType::kLinkSerial: {
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
    TimerController(timer_.get());
    //qDebug() << "LinkManager::createAndOpenAsUdpProxy";

    Link* newLinkPtr = createNewLink();
    newLinkPtr->createAsUdp(address, sourcePort, destinationPort);
    newLinkPtr->setIsProxy(true);
    newLinkPtr->setIsHided(true);
    proxyLinkUuid_ = newLinkPtr->getUuid();
    list_.append(newLinkPtr);

    newLinkPtr->openAsUdp();
}

void LinkManager::closeUdpProxy()
{
    if (proxyLinkUuid_ == QUuid())
        return;

    //qDebug() << "LinkManager::closeUdpProxy";
    deleteLink(proxyLinkUuid_);
    proxyLinkUuid_ = QUuid();
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
