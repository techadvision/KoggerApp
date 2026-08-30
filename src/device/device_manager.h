#pragma once

#include <QObject>
#include <QByteArray>
#include <QString>
#include <QList>
#include <QHash>
#include <QGeoPositionInfoSource>
#include <QUuid>
#include <QTimer>
#include <QFile>
#include <QElapsedTimer>
#include "link.h"
#include "stream_list.h"
#include "dev_q_property.h"
#include "proto_binnary.h"
#include "id_binnary.h"

#include "dataset.h"
#include <QtGlobal>
#include <limits>
class SettingsBus;


struct BootEpochSync {
    qint64 offset_ns = std::numeric_limits<qint64>::min(); // invalid sentinel
    qint64 last_boot_ms = -1;
};

class LocationReader;
class DeviceManager : public QObject
{
    Q_OBJECT

public:
    /*methods*/
    DeviceManager();
    ~DeviceManager() override;

    //PULSE
    void setSettingsBus(SettingsBus* bus);

    Q_INVOKABLE float vruVoltage();
    Q_INVOKABLE float vruCurrent();
    Q_INVOKABLE float vruVelocityH();
    Q_INVOKABLE int pilotArmState();
    Q_INVOKABLE int pilotModeState();
    QList<DevQProperty*> getDevList();
    QList<DevQProperty*> getDevList(BoardVersion ver);
    int calcAverageChartLosses();
    //Pulse
    Q_INVOKABLE bool mavlinkDetected() const;

public slots:
    Q_INVOKABLE bool isCreatedId(int id);
    Q_INVOKABLE StreamListModel* streamsList();

    void initStreamList();
    void frameInput(QUuid uuid, Link* link, Parsers::FrameParser frame);
    void openFile(QString filePath);

    //PULSE DEMO MODE (Stage 1) — see demo_mode_plan.md
    // Paced replay of a .plog file through frameInput(): the same entry point
    // openFile() uses, but metered to one chart epoch per timer tick so the app
    // sees the recording as if a live transducer were streaming it. Nothing
    // downstream of frameInput() can tell replay from live.
    void startDemo(QString filePath);
    void stopDemo();
#ifdef SEPARATE_READING
    void closeFile(bool onOpen = false);
#else
    void closeFile();
#endif
    void onLinkOpened(QUuid uuid, Link *link);
    void onLinkClosed(QUuid uuid, Link* link);
    void onLinkDeleted(QUuid uuid, Link* link);
    void binFrameOut(Parsers::ProtoBinOut protoOut);
    void setProtoBinConsoled(bool isConsoled);
    void upgradeLastDev(QByteArray data);

    void beaconActivationReceive(uint8_t id);
    void beaconDirectQueueAsk();
    bool isbeaconDirectQueueAsk() { return isUSBLBeaconDirectAsk; }
    void setUSBLBeaconDirectAsk(bool is_ask);

    void onLoggingKlfStarted(bool started);
    void onSendRequestAll(QUuid uuid);

    void onStartUpgradingFirmware(QUuid linkUuid, uint8_t address, const QByteArray& firmware);
    void onUpgradingFirmwareDone();
    void setMavlinkDetected (bool detected);

    void createLocationReader();
    void destroyLocationReader();
    void shutdown();

    void onPositionUpdated(const QGeoPositionInfo& info);

    void setUseGPS(bool state);

signals:
    void sendFrameInputToLogger(QUuid uuid, Link* link, Parsers::FrameParser frame);

    //
    void sendChartSetup (const ChannelId& channelId, uint16_t resol, uint16_t count, uint16_t offset);
    void sendTranscSetup(const ChannelId& channelId, uint16_t freq, uint8_t pulse, uint8_t boost);
    void sendSoundSpeeed(const ChannelId& channelId, uint32_t soundSpeed);

    void dataSend(QByteArray data);
    void chartComplete(const ChannelId& channelId, const ChartParameters& chartParams, const QVector<QVector<uint8_t>>& data, float resolution, float offset);
    void rawDataRecieved(const ChannelId& channelId, RawData rawData);
    void distComplete(const ChannelId& channelId, int dist);
    void usblSolutionComplete(IDBinUsblSolution::UsblSolution data);
    void dopplerBeamComlete(IDBinDVL::BeamSolution* beams, uint16_t cnt);
    void dvlSolutionComplete(IDBinDVL::DVLSolution dvlSolution);
    void chartSetupChanged();
    void distSetupChanged();
    void datasetChanged();
    void transChanged();
    void soundChanged();
    void UARTChanged();
    void upgradeProgressChanged(int progressStatus);
    void deviceVersionChanged();
    void devChanged();
    void streamChanged();
    void vruChanged();
    void writeProxyFrame(Parsers::FrameParser frame);
    void writeMavlinkFrame(Parsers::FrameParser frame);
    void eventComplete(int timestamp, int id, int unixt);
    void rangefinderComplete(const ChannelId& channelId, float distance);
    void positionComplete(double lat, double lon, uint32_t date, uint32_t time);
    void positionCompleteRTK(Position position);
    void depthComplete(float depth);
    void gnssVelocityComplete(double hSpeed, double course);
    void simpleNavV2Complete(uint8_t gnssFixType,
                             uint8_t numSats,
                             uint32_t unixTime,
                             int16_t unixOffsetMs,
                             double latitude,
                             double longitude,
                             double groundCourseDeg,
                             double groundVelocityMps,
                             float yawDeg,
                             float pitchDeg,
                             float rollDeg);
    void boatStatusComplete(uint8_t batteryBoatPercent, uint8_t batteryBridgePercent, uint8_t signalQualityBoatPercent, uint8_t signalQualityBridgePercent);
    void attitudeComplete(float yaw, float pitch, float roll);
    void tempComplete(float val);
    void encoderComplete(float e1, float e2, float e3);
    void fileStopsOpening();
    void chartLossesChanged();
    //Pulse
    void mavlinkWasDetected();
    //Pulse demo mode
    void demoStarted(int periodMs, bool isSideScan);
    // epochsPlayed lets Core decide whether looping is safe: a pass that played
    // nothing (unreadable file, no chart data) must NOT be retried forever.
    void demoFinished(quint64 epochsPlayed);

    // logger
    void sendProtoFrame(Parsers::ProtoBinOut protoOut);

#ifdef SEPARATE_READING
    void fileStartOpening();
    void fileBreaked(bool);
    void onFileReadEnough();
#endif
    void fileOpened();

private:
    /*methods*/
    DevQProperty* getDevice(QUuid uuid, Link* link, uint8_t addr);
    void delAllDev();
    void deleteDevicesByLink(QUuid uuid);
    DevQProperty* createDev(QUuid uuid, Link* link, uint8_t addr);

    //PULSE DEMO MODE
    // Bounded prefix scan: works out the pacing before the first frame is
    // dispatched. Returns false when the file cannot be used for a demo.
    bool demoPrescan(const QString& localPath, int& periodMsOut, bool& isSideScanOut);
    // Clock-driven: each tick delivers whatever the recording says is due by now.
    void demoTick();
    // Dispatches frames up to and including the next chart epoch boundary.
    // Returns false at end of file (having already stopped the demo).
    bool demoDeliverOneEpoch();
    void demoReportRate();
    void demoCleanup();
    // Non-destructive peek: true when this frame is the first fragment of a ping.
    static bool isChartEpochStart(const Parsers::FrameParser& frame);

    //PULSE
    SettingsBus* bus_ = nullptr;
    QHash<QUuid, BootEpochSync> mavEpochSync_;
    void setEpochSyncFromSystemTime(const QUuid& srcUuid,
                                    qint64 time_unix_us,
                                    qint64 time_boot_ms);
    bool hasSystemTimeMapping(const QUuid& srcUuid) const;
    std::pair<quint32,quint32> toUnixFromBootMs(const QUuid& srcUuid, qint64 boot_ms) const;
    static qint64 nowUnixNs();

    /*data*/
    struct VruData {
        VruData() :
            voltage(NAN),
            current(NAN),
            velocityH(NAN),
            armState(-1),
            flightMode(-1)
        {};

        void cleanVru()
        {
            voltage = NAN;
            current = NAN;
            velocityH = NAN;
            armState = -1;
            flightMode = -1;
        };

        float voltage;
        float current;
        float velocityH;
        int armState;
        int flightMode;
    };

    VruData vru_;
    DevQProperty* lastDevs_;
    DevQProperty* lastDevice_;
    Link* mavlinkLink_;
    QList<DevQProperty*> devList_;
    QHash<QUuid, QHash<int, DevQProperty*>> devTree_;
    QHash<QUuid, int> otherProtocolStat_;
    StreamList streamList_;
    QUuid lastUuid_;
    QUuid proxyLinkUuid_;
    QUuid mavlinUuid_;
    int lastAddress_;
    int progress_;
    bool isConsoled_;
    volatile bool break_;
#ifdef SEPARATE_READING
    bool onOpen_{ false };
#endif

    bool isUSBLBeaconDirectAsk = false;
    QTimer beacon_timer;
    QUuid upgradeUuid_;
    uint8_t upgradeAddr_;
    QByteArray upgradeData_;
    
    bool mavlinkDetected_;

    bool loggingStarted_ = false;
    LocationReader* locReader_{ nullptr };
    bool useGPS_{ false };

    //PULSE DEMO MODE state. All of it lives on the DeviceManager thread; with
    // SEPARATE_READING off that is the GUI thread, which is exactly where a
    // QTimer-paced replay wants to be.
    QTimer*             demoTimer_{ nullptr };
    QFile*              demoFile_{ nullptr };
    Parsers::FrameParser demoParser_;
    // The parser keeps a raw pointer into this buffer between ticks, so it must
    // outlive every tick that reads from it. Do not make it a local.
    QByteArray          demoChunk_;
    QUuid               demoUuid_;
    bool                demoRunning_{ false };
    bool                demoSeenFirstChart_{ false };
    int                 demoPeriodMs_{ 0 };
    quint64             demoEpochsPlayed_{ 0 };
    // Pacing is driven by this clock, NOT by counting timer ticks. A repeating
    // QTimer only guarantees a DELAY BETWEEN slot invocations, so every
    // millisecond spent processing an epoch was being added to the epoch period
    // — which is why the echogram ran slower as per-epoch cost grew.
    QElapsedTimer       demoClock_;
    qint64              demoNextDueMs_{ 0 };
    // Diagnostics, reported periodically so we can tell "timer was late" (which
    // catch-up absorbs) from "this machine cannot render at the recorded rate".
    qint64              demoLastReportMs_{ 0 };
    quint64             demoEpochsAtLastReport_{ 0 };
    quint64             demoCatchUpEvents_{ 0 };
    quint64             demoBehindEvents_{ 0 };
    // Prescan result cache. Looping restarts startDemo() for the same file, and
    // re-scanning 8 MB on every pass would put a visible hitch at each loop.
    QString             demoCachedPath_;
    int                 demoCachedPeriodMs_{ 0 };
    bool                demoCachedIsSideScan_{ false };

private slots:
    void readyReadProxy(Link* link);
    void readyReadProxyNav(Link* link);
};
