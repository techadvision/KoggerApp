#pragma once

#include <memory>
#include <QObject>
#include <QList>
#include <QStringList>
#include <QThread>
#include <QPair>
#include <QUuid>
#include <QByteArray>
#include "link_manager.h"
#include "link_list_model.h"
class SettingsBus;


class LinkManagerWrapper : public QObject // wrapper for LinkManager in main thread
{
    Q_OBJECT
public:
    Q_PROPERTY(LinkListModel* linkListModel READ getModelPtr NOTIFY modelChanged)
    Q_PROPERTY(QVariant baudrateModel READ baudrateModel CONSTANT)

    void setSettingsBus(SettingsBus* bus);

    /*methods*/
    LinkManagerWrapper(QObject* parent);
    ~LinkManagerWrapper() override;

    LinkListModel* getModelPtr();
    LinkManager* getWorker();
    //Pulse: Added Q_INVOKABLE FOR closeOpenedLinks(), allows us to break connection for any device we have no support for
    Q_INVOKABLE void closeOpenedLinks();
    void startWorkerThread();
    void shutdownWorkerThread();
    QHash<QUuid, QString> getLinkNames() const;
    void openClosedLinks();
    QByteArray exportPinnedLinksToXmlData(QString* error = nullptr);
    bool reloadPinnedLinksFromXmlData(const QByteArray& xmlData,
                                      bool allowSerialLinks = true,
                                      int* skippedSerialLinks = nullptr,
                                      bool* infrastructureUnavailable = nullptr,
                                      QString* error = nullptr);
    QVariant baudrateModel() const;
    //Pulse
    Q_PROPERTY(QString mavlinkPeerIp READ mavlinkPeerIp NOTIFY mavlinkPeerChanged)
    Q_PROPERTY(qint64 mavlinkPeerSeenMs READ mavlinkPeerSeenMs NOTIFY mavlinkPeerChanged)
    QString mavlinkPeerIp() const { return mavlinkPeerIp_; }
    qint64 mavlinkPeerSeenMs() const { return mavlinkPeerSeenMs_; }


public slots:
    void openAsSerial(QUuid uuid, LinkAttribute attribute = LinkAttribute::kLinkAttributeNone);
    void createAsUdp(QString address, int sourcePort, int destinationPort);
    void openAsUdp(QUuid uuid, QString address, int sourcePort, int destinationPort, LinkAttribute attribute = LinkAttribute::kLinkAttributeNone);
    void createAsTcp(QString address, int sourcePort, int destinationPort);
    void openAsTcp(QUuid uuid, QString address, int sourcePort, int destinationPort, LinkAttribute attribute = LinkAttribute::kLinkAttributeNone);
    void createAsRtsp(QString address);
    void openAsRtsp(QUuid uuid, QString address);
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
    void appendModifyModelData(QUuid uuid, bool connectionStatus, bool receivesData, ControlType controlType, QString portName, int baudrate, bool parity,
                               LinkType linkType, QString address, int sourcePort, int destinationPort, bool isPinned, bool isHided, bool isNotAvailable,
                               bool autoSpeedSelection, bool isUpgradingState);
    void deleteModelData(QUuid uuid);
    QUuid getFirstOpened() { return getWorker()->getFirstOpend(); }

    Q_INVOKABLE int  linkState(const QString& uuidStr) const; // -1 absent, 0 closed, 1 ok, 2 idle, 3 unavailable
    Q_INVOKABLE void reopenLink(const QString& uuidStr);
    Q_INVOKABLE void updateBaudrateFor(const QString& uuidStr, int baudrate); // callers holding a uuid string (topology meta), not a model QUuid
    Q_INVOKABLE QStringList pinnedUuids() const; // uuids of pinned links present in the model
    Q_INVOKABLE QStringList serialUuids() const; // uuids of serial links present in the model
    // PULSE (device profiles, step 4): the address an IP link is talking to, so the profile
    // resolver can tell the wifi gateway from the IP telemetry gateway (192.168.144.*).
    // Both return an empty string when the answer is not known, which the resolver reads as
    // "no opinion" rather than as a negative.
    Q_INVOKABLE QString linkAddress(const QString& uuidStr) const; // "" if absent or not an IP link
    Q_INVOKABLE QString openedIpAddress() const;                   // first OPEN UDP/TCP link's address
    // PULSE (backlog item 8): is ANY link open at all, of any transport. The profile
    // resolver needs to know whether there is hardware to protect before it lets a
    // replayed log decide what the app presents as. Serial included, so a USB transducer
    // counts exactly like an IP gateway.
    Q_INVOKABLE bool hasOpenedLink() const;                        // any open link, any transport

public:
    Link* getLinkPtr(QUuid uuid) { return getWorker()->getLinkPtr(uuid); }

signals:
    void modelChanged(); // Q_PROPERTY in .h
    void linkCreatedInteractively(QUuid uuid);
    void linkOpened(QString uuid);
    void linkRemoved(QString uuid);
    void sendOpenAsSerial(QUuid uuid, LinkAttribute attribute = LinkAttribute::kLinkAttributeNone);
    void sendCreateAsUdp(QString address, int sourcePort, int destinationPort);
    void sendOpenAsUdp(QUuid uuid, QString address, int sourcePort, int destinationPort, LinkAttribute attribute = LinkAttribute::kLinkAttributeNone);
    void sendCreateAsTcp(QString address, int sourcePort, int destinationPort);
    void sendCreateAsRtsp(QString address);
    void sendOpenAsRtsp(QUuid uuid, QString address);
    void sendOpenAsTcp(QUuid uuid, QString address, int sourcePort, int destinationPort, LinkAttribute attribute = LinkAttribute::kLinkAttributeNone);
    void sendCloseLink(QUuid uuid);
    QUuid sendGetUuidFromString(QString uuidAsString);
    void sendResetMyOpenLink();
    void sendFCloseLink(QUuid uuid);
    void sendDeleteLink(QUuid uuid);
    void sendUpdateBaudrate(QUuid uuid, int baudrate);
    void sendSetRequestToSend(QUuid uuid, bool rts);
    void sendSetDataTerminalReady(QUuid uuid, bool dtr);
    void sendSetPatity(QUuid uuid, bool parity);
    void sendSetAttribut(QUuid uuid, LinkAttribute attribute);
    void sendUpdateAddress(QUuid uuid, QString address);
    void sendAutoSpeedSelection(QUuid uuid, bool state);
    void sendUpdateSourcePort(QUuid uuid, int sourcePort);
    void sendUpdateDestinationPort(QUuid uuid, int destinationPort);
    void sendUpdatePinnedState(QUuid uuid, bool state);
    void sendUpdateControlType(QUuid uuid, int controlType);
    void sendOpenFLinks();
    void sendCreateAndOpenAsUdpProxy(QString address, int sourcePort, int destinationPort);
    void sendCloseUdpProxy();
    //Pulse
    void mavlinkPeerChanged();

private:
    /*data*/
    std::unique_ptr<QThread> workerThread_;
    std::unique_ptr<LinkManager> workerObject_;
    LinkListModel model_;
    QList<QPair<QUuid, LinkType>> forceClosedLinks_;
    //Pulse
    QString mavlinkPeerIp_;
    qint64 mavlinkPeerSeenMs_ = 0;
};
