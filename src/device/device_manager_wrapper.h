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

private:
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
