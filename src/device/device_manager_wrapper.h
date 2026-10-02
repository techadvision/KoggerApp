#pragma once

#include <QObject>
#include <QThread>
#include <memory>

#include "device_manager.h"


class DeviceManagerWrapper : public QObject
{
    Q_OBJECT

public:
    /*methods*/
    DeviceManagerWrapper(QObject* parent = nullptr);
    ~DeviceManagerWrapper() override;

    //PULSE
    void setSettingsBus(SettingsBus* bus);

    Q_PROPERTY(QList<DevQProperty*> devs READ getDevList NOTIFY devChanged)
    Q_PROPERTY(bool standAvailable READ standAvailable NOTIFY standAvailableChanged)
    Q_PROPERTY(bool protoBinConsoled READ getProtoBinConsoled WRITE setProtoBinConsoled NOTIFY protoBinConsoledChanged)
    Q_PROPERTY(bool nmeaConsoled READ getNmeaConsoled WRITE setNmeaConsoled NOTIFY nmeaConsoledChanged)
    Q_PROPERTY(StreamListModel* streamsList READ streamsList NOTIFY streamChanged)
    Q_PROPERTY(float vruVoltage READ vruVoltage NOTIFY vruChanged)
    Q_PROPERTY(float vruCurrent READ vruCurrent NOTIFY vruChanged)
    Q_PROPERTY(float vruVelocityH READ vruVelocityH NOTIFY vruChanged)
    Q_PROPERTY(int pilotArmState READ pilotArmState NOTIFY vruChanged)
    Q_PROPERTY(int pilotModeState READ pilotModeState NOTIFY vruChanged)
    Q_PROPERTY(int averageChartLosses READ getAverageChartLosses NOTIFY chartLossesChanged)
    Q_PROPERTY(bool isbeaconDirectQueueAsk READ getUSBLBeaconDirectAsk WRITE setUSBLBeaconDirectAsk NOTIFY USBLBeaconDirectAskChanged)

    //Pulse
    Q_PROPERTY(bool mavlinkDetected READ mavlinkDetected NOTIFY mavlinkWasDetected)
    //Pulse, P2: how far a file open has got. Readable at all only because openFile() yields.
    Q_PROPERTY(int fileOpenProgress READ fileOpenProgress NOTIFY openProgressChanged)
    //Pulse, performance mode step 1: the serial link read-outs, refreshed once a second.
    //linkLoadPercent and the loss figures are -1 while there is nothing to say (no baud
    //reported, or no chart data in the window).
    Q_PROPERTY(int    linkBaud              READ linkBaud              NOTIFY linkStatsChanged)
    //false when the reported baud cannot carry what is measured on the wire (the load is -1 then)
    Q_PROPERTY(bool   linkBaudPlausible     READ linkBaudPlausible     NOTIFY linkStatsChanged)
    Q_PROPERTY(int    linkBytesPerSecond    READ linkBytesPerSecond    NOTIFY linkStatsChanged)
    Q_PROPERTY(double linkLoadPercent       READ linkLoadPercent       NOTIFY linkStatsChanged)
    Q_PROPERTY(double chartLossPercent      READ chartLossPercent      NOTIFY linkStatsChanged)
    Q_PROPERTY(double chartLossPercentTotal READ chartLossPercentTotal NOTIFY linkStatsChanged)
    //Pulse, performance mode step 2: what the last complete ping in the chart stream carried
    //(spacing from its header, samples over both channels) - the transducer's own word, which
    //the engine waits for before it sends the next parameter. 0 until a ping has arrived.
    Q_PROPERTY(int    linkStreamSamples     READ linkStreamSamples     NOTIFY linkStatsChanged)
    Q_PROPERTY(int    linkStreamSpacingMm   READ linkStreamSpacingMm   NOTIFY linkStatsChanged)

    DeviceManager* getWorker();
    QUuid getFileUuid() const;

    /*QML*/
    QList<DevQProperty*> getDevList     () { return getWorker()->getDevList();     }
    bool                 standAvailable () { return getWorker()->standAvailable(); }
    StreamListModel*     streamsList    () { return getWorker()->streamsList();    }
    float                vruVoltage     () { return getWorker()->vruVoltage();     }
    float                vruCurrent     () { return getWorker()->vruCurrent();     }
    float                vruVelocityH   () { return getWorker()->vruVelocityH();   }
    int                  pilotArmState  () { return getWorker()->pilotArmState();  }
    int                  pilotModeState () { return getWorker()->pilotModeState(); }
    int                  fileOpenProgress() { return getWorker()->openProgress(); }

    //Pulse, P2: the opening pill's two answers. Direct, not queued - openFile() runs on the
    //GUI thread on this branch and the tap that calls this lands inside its own
    //processEvents(), so the loop reads the new value on its very next check.
    Q_INVOKABLE void stopFileOpen()  { getWorker()->requestOpenInterrupt(DeviceManager::OpenKeepLoaded); }
    Q_INVOKABLE void abortFileOpen() { getWorker()->requestOpenInterrupt(DeviceManager::OpenDiscard); }

    void startWorkerThread();
    void initStreamList();

    //Pulse
    bool mavlinkDetected() const;
    bool getProtoBinConsoled() const { return protoBinConsoledState_; };
    bool getNmeaConsoled() const { return nmeaConsoledState_; };
    bool getUSBLBeaconDirectAsk() const { return USBLBeaconDirectAskState_; };
    int    linkBaud() const              { return linkBaud_; }
    int    linkBytesPerSecond() const    { return linkBytesPerSecond_; }
    bool   linkBaudPlausible() const     { return linkBaudPlausible_; }
    double linkLoadPercent() const       { return linkLoadPercent_; }
    double chartLossPercent() const      { return chartLossPercent_; }
    double chartLossPercentTotal() const { return chartLossPercentTotal_; }
    int    linkStreamSamples() const     { return linkStreamSamples_; }
    int    linkStreamSpacingMm() const   { return linkStreamSpacingMm_; }
    int getAverageChartLosses() const {
        return averageChartLosses_;
    };


public slots:
    Q_INVOKABLE bool isCreatedId(int id) { return getWorker()->isCreatedId(id); };
    Q_INVOKABLE void startStreamDownload(int id);
    Q_INVOKABLE void cancelStreamDownload(int id);
    Q_INVOKABLE void refreshStreamList();
    void calcAverageChartLosses();
    void setProtoBinConsoled(bool state) {
        const bool changed = (protoBinConsoledState_ != state);
        protoBinConsoledState_ = state;
        getWorker()->setProtoBinConsoled(protoBinConsoledState_);
        if (changed) {
            emit protoBinConsoledChanged();
        }
    }

    void setNmeaConsoled(bool state) {
        const bool changed = (nmeaConsoledState_ != state);
        nmeaConsoledState_ = state;
        getWorker()->setNmeaConsoled(nmeaConsoledState_);
        if (changed) {
            emit nmeaConsoledChanged();
        }
    }

    void setUSBLBeaconDirectAsk(bool is_ask) {
        const bool changed = (USBLBeaconDirectAskState_ != is_ask);
        USBLBeaconDirectAskState_ = is_ask;
        getWorker()->setUSBLBeaconDirectAsk(USBLBeaconDirectAskState_);
        if (changed) {
            emit USBLBeaconDirectAskChanged();
        }
    }

signals:
    void sendOpenFile(QString path);
#ifdef SEPARATE_READING
    void sendCloseFile(bool);
#else
    void sendCloseFile();
#endif

    void devChanged();
    void standAvailableChanged();
    void streamChanged();
    void vruChanged();
    void chartLossesChanged();
    void mavlinkWasDetected();
    //Pulse, P2
    void openProgressChanged(int percent);
    void openInterrupted(bool discarded);
    void protoBinConsoledChanged();
    void nmeaConsoledChanged();
    void USBLBeaconDirectAskChanged();
    void linkStatsChanged();

private:
    void sampleLinkStats();
    QTimer linkStatsTimer_;
    quint64 lastWireBytes_ = 0, lastChartBytes_ = 0, lastMissingBytes_ = 0;
    // a 10 s window for the loss figure: one second of 0.13% is a single fragment
    static constexpr int kLossWindow = 10;
    quint64 winChart_[kLossWindow] = {}, winMissing_[kLossWindow] = {}, winWire_[kLossWindow] = {};
    int winIndex_ = 0;
    int secondsWithData_ = 0;
    int linkBaud_ = 0;
    int linkBytesPerSecond_ = 0;
    bool linkBaudPlausible_ = true;
    double linkLoadPercent_ = -1.0;
    double chartLossPercent_ = -1.0;
    double chartLossPercentTotal_ = -1.0;
    int linkStreamSamples_ = 0;
    int linkStreamSpacingMm_ = 0;
    std::unique_ptr<DeviceManager> workerObject_;
#ifdef SEPARATE_READING
    std::unique_ptr<QThread> workerThread_;
    QList<QMetaObject::Connection> deviceManagerConnections_;
#endif

    int averageChartLosses_;
    bool protoBinConsoledState_;
    bool nmeaConsoledState_;
    bool USBLBeaconDirectAskState_;
}; // class DeviceWrapper
