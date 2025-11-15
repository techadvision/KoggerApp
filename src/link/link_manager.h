#pragma once

#include <memory>
#include <QObject>
#include <QString>
#include <QUuid>
#include <QList>
#include <QTimer>
#if defined(Q_OS_ANDROID)
#include "platform/android/src/qtandroidserialport/src/qserialport.h"
#include "platform/android/src/qtandroidserialport/src/qserialportinfo.h"
#else
#include <QSerialPort>
#include <QSerialPortInfo>
#endif
#include "link.h"
#include "proto_binnary.h"
#include <QVariantMap>
class SettingsBus;
class Link;

class LinkManager : public QObject
{
    Q_OBJECT

public:
    explicit LinkManager(QObject *parent = nullptr);
    Link *getLinkPtr(QUuid uuid);
    void setSettingsBus(SettingsBus* b);
    void applyRuntime(const QVariantMap& m);
    void applyPersistent(const QVariantMap& m);

public slots:
    void onLinkConnectionStatusChanged(QUuid uuid);
    void onUpgradingFirmwareStateChanged(QUuid uuid);
    void onLinkBaudrateChanged(QUuid uuid);
    void onLinkIsReceivesDataChanged(QUuid uuid);
    void createAndStartTimer();
    void stopTimer();
    void onExpiredTimer();

    void openAsSerial(QUuid uuid, LinkAttribute attribute = LinkAttribute::kLinkAttributeNone);
    void openAsUdp(QUuid uuid, QString address, int sourcePort, int destinationPort, LinkAttribute attribute = LinkAttribute::kLinkAttributeNone);
    void openAsTcp(QUuid uuid, QString address, int sourcePort, int destinationPort, LinkAttribute attribute = LinkAttribute::kLinkAttributeNone);
    void closeLink(QUuid uuid);
    QUuid getUuidFromString (QString uuidAsString);
    void resetMyOpenLink();
    void closeFLink(QUuid uuid);
    void deleteLink(QUuid uuid);
    void updateBaudrate(QUuid uuid, int baudrate);
    void setRequestToSend(QUuid uuid, bool rts);
    void setDataTerminalReady(QUuid uuid, bool dtr);
    void setParity(QUuid uuid, bool parity);
    void setAttribute(QUuid uuid, LinkAttribute attribute);
    void updateAddress(QUuid uuid, const QString& address);
    void updateAutoSpeedSelection(QUuid uuid, bool state);
    void updateSourcePort(QUuid uuid,int sourcePort);
    void updateDestinationPort(QUuid uuid,int destinationPort);
    void updatePinnedState(QUuid uuid, bool state);
    void updateControlType(QUuid uuid, ControlType controlType);
    void frameInput(Link* link, FrameParser frame);
    void createAsUdp(QString address, int sourcePort, int destinationPort);
    void createAsTcp(QString address, int sourcePort, int destinationPort);
    void importPinnedLinksFromXML();
    void openFLinks();
    void createAndOpenAsUdpProxy(QString address, int sourcePort, int destinationPort);
    void closeUdpProxy();
    QUuid getFirstOpend();
    //PULSE
    void handleLinkOpened(QUuid uuid, Link* link);

signals:
    void appendModifyModel(QUuid uuid, bool connectionStatus, bool receivesData, ControlType controlType, QString portName, int baudrate, bool parity,
                        LinkType linkType, QString address, int sourcePort, int destinationPort, bool isPinned, bool isHided, bool isNotAvailable,
                        bool autoSpeedSelection, bool isUpgradingState);
    void deleteModel(QUuid uuid);
    void frameReady(QUuid uuid, Link* link, FrameParser frame);
    void linkClosed(QUuid uuid, Link* link);
    void linkOpened(QUuid uuid, Link* link);
    void linkDeleted(QUuid uuid, Link* link);
    void sendDoRequestAll(QUuid uuid);

private:
    /*structures*/
    class TimerController {
    public:
        explicit TimerController(QTimer* timer);
        ~TimerController();
    private:
        QTimer* timer_;
    };

    /*methods*/
    QList<QSerialPortInfo> getCurrentSerialList() const;
    Link* createSerialPort(const QSerialPortInfo& serialInfo) const;
    void addNewLinks(const QList<QSerialPortInfo> &currSerialList);
    void deleteMissingLinks(const QList<QSerialPortInfo> &currSerialList);
    void openAutoConnections();
    void update();
    void doEmitAppendModifyModel(Link* linkPtr);
    void exportPinnedLinksToXML();
    Link* createNewLink() const;
    void printLinkDebugInfo(Link* link) const;
    QString  getAndroidGatewayIP();

    /*data*/
    QList<Link*> list_;
    std::unique_ptr<QTimer> timer_;
    static const int timerInterval_ = 500; // msecs
    QUuid proxyLinkUuid_;
    bool coldStarted_;
    SettingsBus* bus_ = nullptr;
    QString udpGateway_ = "192.168.10.1";
    bool    isBetaTester_ = false;
    bool    isExpert_     = false;
    int     udpPort_      = 14560;
    QString uuidIpGateway_ = "{2ad43efc-61d1-4321-a925-a8e0cd188ca2}"; //As defined in pulseRuntimeSettings
    QString uuidUsbSerial_ = "{2ad43efc-61d1-4321-a925-a8e0cd188cd0}"; //As defined in pulseRuntimeSettings
    QString uuidProxyLink_ = "{2ad43efc-61d1-4321-a925-a8e0cd188cd0}";
    QString uuidSuccessfullyOpened_ = "";
};
