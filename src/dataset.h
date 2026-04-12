#pragma once

#include <math.h>
#include <stdint.h>
#include <time.h>
#include <QObject>
#include <QMap>
#include <QSet>
#include <QPair>
#include <QVector>
#include <QVector3D>
#include <QReadWriteLock>

#include "black_stripes_processor.h"
#include "dataset_defs.h"
#include "data_interpolator.h"
#include "epoch.h"
#include "id_binnary.h"
#include "usbl_view.h"

#include "SlidingWindowMedian.h"
#include <QSysInfo>

class Dataset : public QObject
{
    Q_OBJECT

public:
    //Low mem 32 bit devices workaround
    static inline bool kIs32BitProcess() {
        return sizeof(void*) == 4;
    }
    // epochs ~= ping rows (20/s at 50 ms). On 32-bit, ~9 minutes @ 20/s = 10,800.
    // epochs ~= ping rows (20/s at 50 ms). On 32-bit, ~7 * 60 * 20 = 8400.
    // Give some headroom; keep ~7 minutes.
    static inline int kMaxEpochsFor32() { return 7000; }   // ~7.5 min @ 20/s
    static inline int kMaxEpochsFor64() { return 120000; } // plenty on 64-bit

    static inline int kMaxEpochsCap() {
        return kIs32BitProcess() ? kMaxEpochsFor32() : kMaxEpochsFor64();
    }

    // Trim in batches to avoid frequent O(n) memmoves.
    static inline int kTrimBatch() { return 256; }


    /*structures*/
    enum class DatasetState {
        kUndefined = 0,
        kFile,
        kConnection
    };
    enum class LlaRefState {
        kUndefined = 0,
        kSettings,
        kFile,
        kConnection
    };


    //TODO: Now we can maybe change to use standard methods? Telemetry depth and temperature
    Q_PROPERTY(float dist                   READ dist                                                   NOTIFY distChanged)
    Q_PROPERTY(float temp                   READ temp                                                   NOTIFY tempChanged)
    Q_PROPERTY(float bottomTrackDepth       READ bottomTrackDepth                                       NOTIFY bottomTrackDepthChanged)

    Q_PROPERTY(float boatLatitude             READ getBoatLatitude          NOTIFY lastPositionChanged)
    Q_PROPERTY(float boatLongitude            READ getBoatLongitude         NOTIFY lastPositionChanged)
    Q_PROPERTY(float distToContact            READ getDistToContact         NOTIFY lastPositionChanged)
    Q_PROPERTY(float angleToContact           READ getAngleToContact        NOTIFY lastPositionChanged)
    Q_PROPERTY(bool  isActiveContactIndxValid READ isValidActiveContactIndx NOTIFY activeContactChanged)
    Q_PROPERTY(bool  isBoatCoordinateValid    READ isValidBoatCoordinate    NOTIFY lastPositionChanged)
    Q_PROPERTY(float isLastDepthValid         READ isValidLastDepth         NOTIFY lastDepthChanged)
    Q_PROPERTY(float depth                    READ getLastDepth             NOTIFY lastDepthChanged)
    Q_PROPERTY(float isLastTrackDepthValid    READ isValidLastTrackDepth    NOTIFY lastDepthChanged)
    Q_PROPERTY(float trackDepth               READ getLastTrackDepth        NOTIFY lastDepthChanged)
    Q_PROPERTY(float isSpeedValid             READ isValidSpeed             NOTIFY speedChanged)
    Q_PROPERTY(float speed                    READ getSpeed                 NOTIFY speedChanged)
    Q_PROPERTY(bool isSimpleNavV2Valid                  READ isValidSimpleNavV2                   NOTIFY simpleNavV2Changed)
    Q_PROPERTY(int simpleNavV2GnssFixType               READ simpleNavV2GnssFixType               NOTIFY simpleNavV2Changed)
    Q_PROPERTY(int simpleNavV2NumSats                   READ simpleNavV2NumSats                   NOTIFY simpleNavV2Changed)
    Q_PROPERTY(uint simpleNavV2UnixTime                 READ simpleNavV2UnixTime                  NOTIFY simpleNavV2Changed)
    Q_PROPERTY(int simpleNavV2UnixOffsetMs              READ simpleNavV2UnixOffsetMs              NOTIFY simpleNavV2Changed)
    Q_PROPERTY(double simpleNavV2Latitude               READ simpleNavV2Latitude                  NOTIFY simpleNavV2Changed)
    Q_PROPERTY(double simpleNavV2Longitude              READ simpleNavV2Longitude                 NOTIFY simpleNavV2Changed)
    Q_PROPERTY(double simpleNavV2GroundCourseDeg        READ simpleNavV2GroundCourseDeg           NOTIFY simpleNavV2Changed)
    Q_PROPERTY(double simpleNavV2GroundVelocityMps      READ simpleNavV2GroundVelocityMps         NOTIFY simpleNavV2Changed)
    Q_PROPERTY(float simpleNavV2YawDeg                  READ simpleNavV2YawDeg                    NOTIFY simpleNavV2Changed)
    Q_PROPERTY(float simpleNavV2PitchDeg                READ simpleNavV2PitchDeg                  NOTIFY simpleNavV2Changed)
    Q_PROPERTY(float simpleNavV2RollDeg                 READ simpleNavV2RollDeg                   NOTIFY simpleNavV2Changed)
    Q_PROPERTY(bool isBoatStatusValid                   READ isValidBoatStatus                    NOTIFY boatStatusChanged)
    Q_PROPERTY(int boatStatusBatteryBoatPercent         READ boatStatusBatteryBoatPercent          NOTIFY boatStatusChanged)
    Q_PROPERTY(int boatStatusBatteryBridgePercent       READ boatStatusBatteryBridgePercent        NOTIFY boatStatusChanged)
    Q_PROPERTY(int boatStatusSignalQualityBoatPercent   READ boatStatusSignalQualityBoatPercent    NOTIFY boatStatusChanged)
    Q_PROPERTY(int boatStatusSignalQualityBridgePercent READ boatStatusSignalQualityBridgePercent  NOTIFY boatStatusChanged)
    Q_PROPERTY(bool  spatialPreparing         READ isSpatialPreparing       NOTIFY spatialPreparingChanged)

    /*methods*/
    Dataset();
    ~Dataset();

    //Pulse - getters
    float dist() const { return _dist; }
    float temp() const { return _temp; }
    float bottomTrackDepth() const { return _bottomTrackDepth; }
    double smallAgreeMargin() const { return _kSmallAgreeMargin; }
    double largeJumpThreshold() const { return _kLargeJumpThreshold; }
    int consistNeeded() const { return _kConsistNeeded; }
    double transducerOffsetMount() const { return _transducerOffsetMount; }
    //Q_INVOKABLE bool processBottomTrack() const { return _processBottomTrack; }
    //Q_INVOKABLE bool isBottomTrackInitiated() const { return _isBottomTrackInitiated; }
    //Q_INVOKABLE bool isBottomTrackActive() const { return _isBottomTrackActive; }
    //double bottomTrackMinDepth() const { return _bottomTrackMinDepth; }
    double fakeDepthAddition() const { return _fakeDepthAddition; }
    //Pulse setters
    Q_INVOKABLE void setSmallAgreeMargin(double margin);
    Q_INVOKABLE void setLargeJumpThreshold(double threshold);
    Q_INVOKABLE void setConsistNeeded(int retries);
    Q_INVOKABLE void setTransducerOffsetMount(double offset);
    //Q_INVOKABLE void setProcessBottomTrack(bool enabled);
    //Q_INVOKABLE void setIsBottomTrackInitiated(bool initiated);
    //Q_INVOKABLE void setIsBottomTrackActive(bool activated);
    Q_INVOKABLE void setBottomTrackMinDepth(double minimumDepth);
    Q_INVOKABLE void setFakeDepthAddition(double addedDepth);
    Q_INVOKABLE void processBottomTrack(bool processTracks);
    Q_INVOKABLE void initiateProcessBottomTrack(bool initiateProcessing);
    Q_INVOKABLE void setTemperatureCorrection(bool temperatureCorrection);
    Q_INVOKABLE void setDepthFilterActive(bool useDepthFilter);
    Q_INVOKABLE void setDepthFilterBottomTrackActive(bool useDepthFilterWithBottomTrack);
    float filterDepthRecords (float distance);


    void setState(DatasetState state);
    void setActiveZeroing(bool state);
    DatasetState getState() const;
    LLARef getLlaRef() const;
    void setLlaRef(const LLARef& val, LlaRefState state);

    inline int size() const {
        return pool_.size();
    }

    Epoch* fromIndex(int index_offset = 0) {
        int index = validIndex(index_offset);
        if(index >= 0) {
            return &pool_[index];
        }

        return NULL;
    }

    Epoch fromIndexCopy(int index_offset = 0) {
        QReadLocker rl(&poolMtx_);

        const int index = validIndex(index_offset);
        if (channelsSetup_.empty() || index < 0) {
            return Epoch{};
        }

        const Epoch &src = pool_.at(index);
        Epoch copy = src;

        return copy;
    }

    Epoch::Echogram fromIndexCopyEchogram(int index_offset, const ChannelId& channelId) {
        QReadLocker rl(&poolMtx_);

        const int currSize = pool_.size();
        if (channelsSetup_.empty() || currSize == 0)
            return {};

        int indx = validIndex(index_offset);
        if (indx == -1) {
            return {};
        }

        const Epoch &ep = pool_.at(indx);

        if (!ep.chartAvail(channelId, 0))
            return {};

        return ep.chartCopy(channelId, 0);
    }

    Epoch* last() {
        if(size() > 0) {
            return fromIndex(endIndex());
        }
        return addNewEpoch();
    }

    Epoch* lastlast() {
        if(size() > 1) {
            return fromIndex(endIndex()-1);
        }
        return NULL;
    }

    int endIndex() const {
        return size() - 1;
    }

    int validIndex(int index_offset = 0) {
        int index = index_offset;
        if(index >= size()) { index = endIndex(); }
        else if(index < 0) { index = -1; }
        return index;
    }

    void getMaxDistanceRange(float* from, float* to, const ChannelId& channel, uint8_t subAddressCh1, const ChannelId& channel2 = CHANNEL_NONE, uint8_t subAddressCh2 = 0);

    bool channelsListIsEmpty() const {
        QReadLocker locker(&lock_);

        return channelsSetup_.isEmpty();
    }

    QVector<DatasetChannel> channelsList() const {
        QReadLocker locker(&lock_);

        return channelsSetup_;
    }

    bool isContainsChannelInChannelSetup(const ChannelId& channelId) const {
        QReadLocker locker(&lock_);

        for (int16_t i = 0; i < channelsSetup_.size(); ++i) {
            if (channelsSetup_.at(i).channelId_ == channelId) {
                return true;
            }
        }

        return false;
    }

    int getLastBottomTrackEpoch() const;

    float getLastArtificalYaw() const;
    float getLastArtificaPitch() const;
    float getLastArtificalRoll() const;

    float tryRetLastValidYaw() const {
        if (isfinite(_lastYaw)) {
            return _lastYaw;
        }
        if (isfinite(lastAYaw_)) {
            return lastAYaw_;
        }
        return NAN;
    }

    float getLastYaw() const {
        return _lastYaw;
    }

    float getLastTemp() {
        return lastTemp_;
    }

    bool isValidLastRangefinderDepth() const { return isfinite(lastRangefinderDepth_); }
    bool isValidLastBottomTrackDepth() const { return isfinite(lastBottomTrackDepth_); }
    float getLastRangefinderDepth() const { return lastRangefinderDepth_; }
    float getLastBottomTrackDepth() const { return lastBottomTrackDepth_; }

    BottomTrackParam getBottomTrackParam() {
        QReadLocker rl(&lock_);

        return bottomTrackParam_;
    }

    BottomTrackParam* getBottomTrackParamPtr() {
        return &bottomTrackParam_;
    }

    BottomTrackParam& getBottomTrackParamRef() {
        return bottomTrackParam_;
    }

    std::tuple<ChannelId, uint8_t, QString> channelIdFromName(const QString& name) const;

    void setActiveContactIndx(int64_t indx);
    int64_t getActiveContactIndx() const;
    void setMosaicChannels(const QString& firstChStr, const QString& secondChStr);
    QMap<int, QSet<TileKey>> traceTileKeysForEpoch(int epochIndx) const;

public slots:
    Q_INVOKABLE void onSetLAngleOffset(float val);
    Q_INVOKABLE void onSetRAngleOffset(float val);
    void setSpatialIndexingEnabled(bool sonarState, bool dimRectState, bool chunkedCatchup);

    friend class DataProcessor;
    void onSonarPosCanCalc(uint64_t indx);
    bool  isValidActiveContactIndx() const { return activeContactIndx_ != -1;  };
    bool  isValidBoatCoordinate() const    { return !qFuzzyIsNull(boatLatitute_) || !qFuzzyIsNull(boatLongitude_); };
    bool  isValidLastDepth() const         { return !qFuzzyIsNull(lastDepth_); };
    bool  isValidLastTrackDepth() const    { return !qFuzzyIsNull(lastTrackDepth_); }; //pulse
    bool isValidSpeed() const              { return isfinite(speed_) /*&& !qFuzzyIsNull(speed_)*/; };
    bool isValidSimpleNavV2() const        { return simpleNavV2Valid_; };
    int simpleNavV2GnssFixType() const     { return static_cast<int>(simpleNavV2GnssFixType_); };
    int simpleNavV2NumSats() const         { return static_cast<int>(simpleNavV2NumSats_); };
    uint simpleNavV2UnixTime() const       { return simpleNavV2UnixTime_; };
    int simpleNavV2UnixOffsetMs() const    { return static_cast<int>(simpleNavV2UnixOffsetMs_); };
    double simpleNavV2Latitude() const     { return simpleNavV2Latitude_; };
    double simpleNavV2Longitude() const    { return simpleNavV2Longitude_; };
    double simpleNavV2GroundCourseDeg() const { return simpleNavV2GroundCourseDeg_; };
    double simpleNavV2GroundVelocityMps() const { return simpleNavV2GroundVelocityMps_; };
    float simpleNavV2YawDeg() const        { return simpleNavV2YawDeg_; };
    float simpleNavV2PitchDeg() const      { return simpleNavV2PitchDeg_; };
    float simpleNavV2RollDeg() const       { return simpleNavV2RollDeg_; };
    bool isValidBoatStatus() const         { return boatStatusValid_; };
    int boatStatusBatteryBoatPercent() const { return static_cast<int>(boatBatteryPercent_); };
    int boatStatusBatteryBridgePercent() const { return static_cast<int>(bridgeBatteryPercent_); };
    int boatStatusSignalQualityBoatPercent() const { return static_cast<int>(boatSignalQualityPercent_); };
    int boatStatusSignalQualityBridgePercent() const { return static_cast<int>(bridgeSignalQualityPercent_); };
    bool isSpatialPreparing() const        { return spatialPreparing_;          };
    float getBoatLatitude() const          { return boatLatitute_;             };
    float getBoatLongitude() const         { return boatLongitude_;            };
    float getDistToContact() const         { return distToActiveContact_;      };
    float getAngleToContact() const        { return angleToActiveContact_;     };
    float getLastDepth() const             { return lastDepth_;                };
    float getLastTrackDepth() const        { return lastTrackDepth_;           }; //pulse
    float getSpeed() const                 { return speed_;                    };
    void addEvent(int timestamp, int id, int unixt = 0);
    void addEncoder(float angle1_deg, float angle2_deg = NAN, float angle3_deg = NAN);
    void addTimestamp(int timestamp);

    //
    void setChartSetup (const ChannelId& channelId, uint16_t resol, uint16_t count, uint16_t offset);
    void setTranscSetup(const ChannelId& channelId, uint16_t freq, uint8_t pulse, uint8_t boost);
    void setSoundSpeed (const ChannelId& channelId, uint32_t soundSpeed);
    void setSonarOffset(float x, float y, float z);
    void setFixBlackStripesState(bool state);
    void setFixBlackStripesForwardSteps(int val);
    void setFixBlackStripesBackwardSteps(int val);
    void addChart(const ChannelId& channelId, const ChartParameters& chartParams, const QVector<QVector<uint8_t>>& data, float resolution, float offset);
    void rawDataRecieved(const ChannelId& channelId, RawData raw_data);
    void addDist(const ChannelId& channelId, int dist);
    void addRangefinder(const ChannelId& channelId, float distance);
    void addUsblSolution(IDBinUsblSolution::UsblSolution data);
    void addDopplerBeam(IDBinDVL::BeamSolution *beams, uint16_t cnt);
    void addDVLSolution(IDBinDVL::DVLSolution dvlSolution);
    void addAtt(float yaw, float pitch, float roll);
    void addPosition(double lat, double lon, uint32_t unix_time = 0, int32_t nanosec = 0);
    void addArtificalYaw();
    void addPositionRTK(Position position);

    void addDepth(float depth);

    void addGnssVelocity(double h_speed, double course);
    void addSimpleNavV2(uint8_t gnssFixType,
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

//    void addDateTime(int year, );
    void addTemp(float temp_c);
    void addBoatStatus(uint8_t batteryBoatPercent, uint8_t batteryBridgePercent, uint8_t signalQualityBoatPercent, uint8_t signalQualityBridgePercent);

    void mergeGnssTrack(QList<Position> track);

    void resetDataset();
    void softResetDataset();
    void resetRenderBuffers();
    void resetDistProcessing();

    void setChannelOffset(const ChannelId& channelId, float x, float y, float z);
    void spatialProcessing();

    void usblProcessing();
    QVector<QVector3D> beaconTrack() {
        return _beaconTrack;
    }

    QVector<QVector3D> beaconTrack1() {
        return _beaconTrack1;
    }

    void setScene3D(GraphicsScene3dView* scene3dViewPtr) { scene3dViewPtr_ = scene3dViewPtr; };

    void setRefPosition(int epoch_index);
    void setRefPosition(Epoch* ref_epoch);
    void setRefPosition(Position position);
    void setRefPositionByFirstValid();
    Epoch* getFirstEpochByValidPosition();

    QStringList channelsNameList();

    void onDistCompleted(int epIndx, const ChannelId& channelId, float dist);
    void onDistCompletedBatch(const QVector<BottomTrackUpdate>& updates);
    void onLastBottomTrackEpochChanged(const ChannelId& channelId, int val, const BottomTrackParam& btP, bool manual, bool redrawAll);
    void onDimensionRectCanCalc(uint64_t indx);

signals:
    // data horizon
    void epochAdded(uint64_t indx);
    void positionAdded(uint64_t indx);
    void chartAdded(uint64_t indx); // without ChartId
    void attitudeAdded(uint64_t indx);
    void artificalAttitudeAdded(uint64_t indx);
    void bottomTrackAdded(uint64_t indx);
    //void interpYaw(int epIndx);
    //void interpPos(int epIndx);
    void dataUpdate();
    void bottomTrackUpdated(const ChannelId& channelId, int lEpoch, int rEpoch, bool manual, bool redrawAll);
    void updatedLlaRef();
    void channelsUpdated();
    void distChanged();
    void tempChanged();
    void bottomTrackDepthChanged();
    void redrawEpochs(const QSet<int>& indxs);
    //Pulse
    void didReceiveData();

    void lastPositionChanged();
    void activeContactChanged();
    void lastDepthChanged();
    void speedChanged();
    void simpleNavV2Changed();
    void boatStatusChanged();
    void spatialPreparingChanged();
    void datasetStateChanged(int state);

    void sendTilesByZoom(int epochIndx, const QMap<int, QSet<TileKey>>& tilesByZoom);

protected:

    int lastEventTimestamp = 0;
    int lastEventId = 0;
    float _lastEncoder = 0;

    bool activeZeroing_ = false;
    uint64_t testTime_ = 1740466541;

    DatasetChannel firstChannelId_ = DatasetChannel(); // TODO: temp solution
    QVector<DatasetChannel> channelsSetup_;

    void validateChannelList(const ChannelId& channelId, uint8_t subChannelId);

    QVector<QVector3D> _beaconTrack;
    QVector<QVector3D> _beaconTrack1;

    QMap<int, UsblView::UsblObjectParams> tracks;

    //enum {
    //    AutoRangeNone,
    //    AutoRangeLast,
    //    AutoRangeMax,
    //    AutoRangeMaxVis
    //} _autoRange = AutoRangeLast;


    QVector<Epoch> pool_;

    float lastAYaw_ = NAN, lastAPitch_ = NAN, lastARoll_ = NAN;
    float _lastYaw = NAN, _lastPitch = NAN, _lastRoll = NAN;
    float lastTemp_ = NAN;

    Epoch* addNewEpoch();

    GraphicsScene3dView* scene3dViewPtr_ = nullptr;

private:
    friend class DataInterpolator;

    /*methods*/
    LlaRefState getCurrentLlaRefState() const;
    bool shouldAddNewEpoch(const ChannelId& channelId, uint8_t numSubChannels) const;
    void updateEpochWithChart(const ChannelId& channelId, const ChartParameters& chartParams, const QVector<QVector<uint8_t>>& data, float resolution, float offset);
    void setLastDepth(float val);
    void setLastRangefinderDepth(float val);
    void setLastBottomTrackDepth(float val);
    void tryResetDataset(float lat, float lon);
    void calcDimensionRects(uint64_t indx);
    void appendTileEpochIndex(int epochIndx, const QMap<int, QSet<TileKey>>& tilesByZoom);
    void clearTileEpochIndex();
    void scheduleSpatialCatchup();
    void setSpatialPreparing(bool state);

    /*data*/
    mutable QReadWriteLock lock_;
    mutable QReadWriteLock poolMtx_;
    mutable QReadWriteLock tileEpochIdxMtx_;

    LLARef _llaRef;
    LlaRefState llaRefState_ = LlaRefState::kUndefined;
    DatasetState state_ = DatasetState::kUndefined;
    DataInterpolator interpolator_;
    int lastBottomTrackEpoch_;
    BottomTrackParam bottomTrackParam_;
    QMap<ChannelId, RecordParameters> usingRecordParameters_;
    BlackStripesProcessor* bSProc_;
    QMap<ChannelId, int> lastAddChartEpochIndx_;
    QSet<ChannelId> channelsToResizeEthData_;

    // for GUI
    QList<QString> channelsNames_;
    QList<ChannelId> channelsIds_;
    QList<uint8_t> subChannelIds_;
    int64_t activeContactIndx_  = -1;
    float boatLatitute_         = 0.0f;
    float boatLongitude_        = 0.0f;
    float distToActiveContact_  = 0.0f;
    float angleToActiveContact_ = 0.0f;
    float lastDepth_            = 0.0f;
    float lastTrackDepth_       = 0.0f;
    float lastRangefinderDepth_ = NAN;
    float lastBottomTrackDepth_ = NAN;
    float speed_                = 0.0f;
    bool simpleNavV2Valid_ = false;
    uint8_t simpleNavV2GnssFixType_ = 0;
    uint8_t simpleNavV2NumSats_ = 0;
    uint32_t simpleNavV2UnixTime_ = 0;
    int16_t simpleNavV2UnixOffsetMs_ = 0;
    double simpleNavV2Latitude_ = 0.0;
    double simpleNavV2Longitude_ = 0.0;
    double simpleNavV2GroundCourseDeg_ = 0.0;
    double simpleNavV2GroundVelocityMps_ = 0.0;
    float simpleNavV2YawDeg_ = 0.0f;
    float simpleNavV2PitchDeg_ = 0.0f;
    float simpleNavV2RollDeg_ = 0.0f;
    bool boatStatusValid_ = false;
    uint8_t boatBatteryPercent_ = 0;
    uint8_t bridgeBatteryPercent_ = 0;
    uint8_t boatSignalQualityPercent_ = 0;
    uint8_t bridgeSignalQualityPercent_ = 0;
    QVector3D sonarOffset_;
    uint64_t sonarPosIndx_;
    bool sonarIndexingEnabled_ = false;
    bool dimRectIndexingEnabled_ = false;
    bool chunkedSpatialCatchup_ = false;
    bool spatialCatchupScheduled_ = false;
    bool spatialPreparing_ = false;
    uint64_t pendingSonarPosIndx_ = 0;
    uint64_t pendingDimRectIndx_ = 0;

    ChannelId mosaicFirstChId_;
    ChannelId mosaicSecondChId_;
    uint8_t mosaicFirstSubChId_;
    uint8_t mosaicSecondSubChId_;
    uint64_t lastDimRectindx_;
    float lAngleOffset_;
    float rAngleOffset_;
    QVector<QHash<TileKey, QVector<int>>> tileEpochIndxsByZoom_;
    
    //Pulse
    float _dist = 0; // Stores the distance value
    float _temp = 0; // Stores the temperature value
    SlidingWindowMedian _depthFilter{10};
    //void trimOldEpochsIfNeeded();
    int  pendingEpochsSinceLastTrim_ = 0;
    //float _lastFilteredDepth = 0.0;
    float _lastRawDepth = 0.0;
    int _consistCount = 0;
    //Pulse adjustable incl depth filter
    double _kSmallAgreeMargin               = 0.5;
    double _kLargeJumpThreshold             = 5.00;
    int    _kConsistNeeded                  = 3;
    double _transducerOffsetMount           = 0.0;
    bool   _didEverReceiveData              = false;
    double _temperatureCorrection           = 0.0;
    float  _lastFilteredDepth               = 0.0;
    bool   _useDepthFilter                  = true;
    bool   _useDepthFilterWithBottomTrack   = true;
    //Bottom track
    bool   _processBottomTrack      = false;
    bool   _isBottomTrackInitiated  = false;
    bool   _isBottomTrackActive     = false;
    double _bottomTrackMinDepth     = 0.5;
    float _bottomTrackDepth         = NAN;
    float _lastStableBTDepth1       = NAN;
    float _lastStableBTDepth2       = NAN;
    float _btSpikeThreshold         = 2.0f;
    long  _processingRound          = 0;
    //Test
    double _fakeDepthAddition       = 0;
};
