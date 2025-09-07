#pragma once

#include <math.h>
#include <stdint.h>
#include <time.h>
#include <QObject>
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
extern QObject* g_pulseRuntimeSettings;
extern QObject* g_pulseSettings;

class Dataset : public QObject
{
    Q_OBJECT

public:
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

    //Telemetry depth and temperature
    Q_PROPERTY(float dist                   READ dist                                                   NOTIFY distChanged)
    Q_PROPERTY(float temp                   READ temp                                                   NOTIFY tempChanged)
    Q_PROPERTY(float bottomTrackDepth       READ bottomTrackDepth                                       NOTIFY bottomTrackDepthChanged)

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
    Q_INVOKABLE bool processBottomTrack() const { return _processBottomTrack; }
    Q_INVOKABLE bool isBottomTrackInitiated() const { return _isBottomTrackInitiated; }
    Q_INVOKABLE bool isBottomTrackActive() const { return _isBottomTrackActive; }
    double bottomTrackMinDepth() const { return _bottomTrackMinDepth; }
    double fakeDepthAddition() const { return _fakeDepthAddition; }
    //Pulse setters
    Q_INVOKABLE void setSmallAgreeMargin(double margin);
    Q_INVOKABLE void setLargeJumpThreshold(double threshold);
    Q_INVOKABLE void setConsistNeeded(int retries);
    Q_INVOKABLE void setTransducerOffsetMount(double offset);
    Q_INVOKABLE void setProcessBottomTrack(bool enabled);
    Q_INVOKABLE void setIsBottomTrackInitiated(bool initiated);
    Q_INVOKABLE void setIsBottomTrackActive(bool activated);
    Q_INVOKABLE void setBottomTrackMinDepth(double minimumDepth);
    Q_INVOKABLE void setFakeDepthAddition(double addedDepth);


    void setState(DatasetState state);

#if defined(FAKE_COORDS)
    void setActiveZeroing(bool state);
#endif

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

    float getLastYaw() {
        return _lastYaw;
    }

    float getLastTemp() {
        return lastTemp_;
    }

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

public slots:
    friend class DataProcessor;

    void addEvent(int timestamp, int id, int unixt = 0);
    void addEncoder(float angle1_deg, float angle2_deg = NAN, float angle3_deg = NAN);
    void addTimestamp(int timestamp);

    //
    void setChartSetup (const ChannelId& channelId, uint16_t resol, uint16_t count, uint16_t offset);
    void setTranscSetup(const ChannelId& channelId, uint16_t freq, uint8_t pulse, uint8_t boost);
    void setSoundSpeed (const ChannelId& channelId, uint32_t soundSpeed);
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
    void addPositionRTK(Position position);

    void addDepth(float depth);

    void addGnssVelocity(double h_speed, double course);

//    void addDateTime(int year, );
    void addTemp(float temp_c);

    void mergeGnssTrack(QList<Position> track);

    void resetDataset();
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


    void interpolateData(bool fromStart);

    void onDistCompleted(int epIndx, const ChannelId& channelId, float dist);
    void onLastBottomTrackEpochChanged(const ChannelId& channelId, int val, const BottomTrackParam& btP, bool manual);

signals:
    // data horizon
    void epochAdded(uint64_t indx);
    void positionAdded(uint64_t indx);
    void chartAdded(uint64_t indx); // without ChartId
    void attitudeAdded(uint64_t indx);
    void bottomTrackAdded(uint64_t indx);
    //void interpYaw(int epIndx);
    //void interpPos(int epIndx);
    void dataUpdate();
    void bottomTrackUpdated(const ChannelId& channelId, int lEpoch, int rEpoch, bool manual);
    void updatedLlaRef();
    void channelsUpdated();
    void distChanged();
    void tempChanged();
    void bottomTrackDepthChanged();
    void redrawEpochs(const QSet<int>& indxs);
    void isBottomTrackActiveUpdated();

private:
    //Pulse
    float _dist = 0; // Stores the distance value
    float _temp = 0; // Stores the temperature value
    SlidingWindowMedian _depthFilter{10};
    //float _lastFilteredDepth = 0.0;
    float _lastRawDepth = 0.0;
    int _consistCount = 0;
    //Pulse adjustable
    double _kSmallAgreeMargin       = 0.5;
    double _kLargeJumpThreshold     = 10.00;
    int    _kConsistNeeded          = 3;
    double _transducerOffsetMount   = 0.0;
    bool   _processBottomTrack      = false;
    bool   _isBottomTrackInitiated  = false;
    bool   _isBottomTrackActive     = false;
    double _bottomTrackMinDepth     = 0.5;
    //Bottom track
    float _bottomTrackDepth      = NAN;
    float _lastStableBTDepth1    = NAN;
    float _lastStableBTDepth2    = NAN;
    float _btSpikeThreshold      = 2.0f;
    long  _processingRound       = 0;
    //Test
    double _fakeDepthAddition    = 0;


protected:

    int lastEventTimestamp = 0;
    int lastEventId = 0;
    float _lastEncoder = 0;

#if defined(FAKE_COORDS)
    bool activeZeroing_ = false;
    uint64_t testTime_ = 1740466541;
#endif

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

    float _lastYaw = 0, _lastPitch = 0, _lastRoll = 0;
    float lastTemp_ = NAN;

    Epoch* addNewEpoch();

    GraphicsScene3dView* scene3dViewPtr_ = nullptr;

private:
    friend class DataInterpolator;

    /*methods*/
    LlaRefState getCurrentLlaRefState() const;
    bool shouldAddNewEpoch(const ChannelId& channelId, uint8_t numSubChannels) const;
    void updateEpochWithChart(const ChannelId& channelId, const ChartParameters& chartParams, const QVector<QVector<uint8_t>>& data, float resolution, float offset);

    /*data*/
    mutable QReadWriteLock lock_;
    mutable QReadWriteLock poolMtx_;

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
    float _lastFilteredDepth = 0.0;

    // for GUI
    QList<QString> channelsNames_;
    QList<ChannelId> channelsIds_;
    QList<uint8_t> subChannelIds_;
};
