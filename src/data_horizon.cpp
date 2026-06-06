#include "data_horizon.h"

#include <algorithm>
#include <QDebug>
#ifdef PULSE_MOSAIC_DEBUG
#include <QDateTime>
#endif


DataHorizon::DataHorizon() :
    QObject(),
    emitChanges_(true),
    isFileOpening_(false),
    isSeparateReading_(false),
    isAttitudeExpected_(false),
    pendingBottomTrack3DManual_(false),
    epochIndx_(0),
    positionIndx_(0),
    chartIndx_(0),
    attitudeIndx_(0),
    artificalAttitudeIndx_(0),
    bottomTrackIndx_(0),
    mosaicIndx_(0),
    sonarPosIndx_(0),
    dimRectIndx_(0)
{
#ifdef SEPARATE_READING
    isSeparateReading_ = true;
#endif

    qRegisterMetaType<uint64_t>("uint64_t");
}

void DataHorizon::clear()
{
    isFileOpening_ = false;
    pendingBottomTrack3DPairs_.clear();
    pendingBottomTrack3DManual_ = false;

    epochIndx_ = 0;
    positionIndx_ = 0;
    chartIndx_ = 0;
    attitudeIndx_ = 0;
    artificalAttitudeIndx_ = 0;
    bottomTrackIndx_ = 0;
    mosaicIndx_ = 0;
    sonarPosIndx_ = 0;
    dimRectIndx_ = 0;
}

void DataHorizon::setEmitChanges(bool state)
{
    emitChanges_ = state;
}

void DataHorizon::setIsFileOpening(bool state)
{
    //qDebug() << "DataHorizon::setIsFileOpening" << state;

    if (state) {
        pendingBottomTrack3DPairs_.clear();
        pendingBottomTrack3DManual_ = false;
    }

    isFileOpening_ = state;

    if (!isFileOpening_ && !isSeparateReading_ && emitChanges_) { // emit all
        emit epochAdded(epochIndx_);
        emit positionAdded(positionIndx_);
        emit chartAdded(chartIndx_);
        //emit attitudeAdded(attitudeIndx_);
        //emit artificalAttitudeAdded(artificalAttitudeIndx_);
        tryCalcAndEmitSonarPosIndx();
        tryCalcAndEmitMosaicIndx();
        tryCalcAndEmitDimRectIndx();

        if (!pendingBottomTrack3DPairs_.isEmpty()) {
            QVector<int> epVec;
            QVector<int> vertVec;
            QVector<int> epKeys;
            epKeys.reserve(pendingBottomTrack3DPairs_.size());
            const QList<int> keys = pendingBottomTrack3DPairs_.keys();
            for (int key : keys) {
                epKeys.push_back(key);
            }
            std::sort(epKeys.begin(), epKeys.end());

            epVec.reserve(epKeys.size());
            vertVec.reserve(epKeys.size());
            for (int epIdx : epKeys) {
                epVec.push_back(epIdx);
                vertVec.push_back(pendingBottomTrack3DPairs_.value(epIdx));
            }

            emit bottomTrack3DAdded(epVec, vertVec, pendingBottomTrack3DManual_);
            pendingBottomTrack3DPairs_.clear();
            pendingBottomTrack3DManual_ = false;
        }
    }
}

void DataHorizon::setIsAttitudeExpected(bool state)
{
    //qDebug() << "DataHorizon::setIsAttitudeExpected" << state;
    isAttitudeExpected_ = state;
}

void DataHorizon::onAddedEpoch(uint64_t indx)
{
    //qDebug() << "DataHorizon::onAddedEpoch" << indx;

    resetOnIndexRollback(indx, epochIndx_);

    bool beenChanged = epochIndx_ != indx;

    epochIndx_ = indx;

    if (canEmitHorizon(beenChanged)) {
        emit epochAdded(epochIndx_);
    }
#ifdef PULSE_MOSAIC_DEBUG
    dbgLogHorizon("epoch");
#endif
}

void DataHorizon::onAddedPosition(uint64_t indx)
{
    //qDebug() << "DataHorizon::onAddedPosition" << indx;

    resetOnIndexRollback(indx, positionIndx_);

    bool beenChanged = positionIndx_ != indx;

    positionIndx_ = indx;

    if (canEmitHorizon(beenChanged)) {
        emit positionAdded(positionIndx_);
        tryCalcAndEmitDimRectIndx();
        tryCalcAndEmitSonarPosIndx();
        tryCalcAndEmitMosaicIndx();
    }
#ifdef PULSE_MOSAIC_DEBUG
    dbgLogHorizon("position");
#endif
}

void DataHorizon::onAddedChart(uint64_t indx)
{
    //qDebug() << "DataHorizon::onAddedChart" << indx;

    resetOnIndexRollback(indx, chartIndx_);

    bool beenChanged = indx != chartIndx_; // TODO: delete this (fix on processing)

    chartIndx_ = indx;

    if (canEmitHorizon(beenChanged)) {
        emit chartAdded(chartIndx_);
        tryCalcAndEmitDimRectIndx();
        tryCalcAndEmitMosaicIndx();
    }
#ifdef PULSE_MOSAIC_DEBUG
    dbgLogHorizon("chart");
#endif
}

void DataHorizon::onAddedAttitude(uint64_t indx)
{
    //qDebug() << "DataHorizon::onAddedAttitude" << indx;

    resetOnIndexRollback(indx, attitudeIndx_);

    bool beenChanged = attitudeIndx_ != indx;

    attitudeIndx_ = indx;

    if (canEmitHorizon(beenChanged)) {
        //emit attitudeAdded(attitudeIndx_);
        tryCalcAndEmitSonarPosIndx();
        tryCalcAndEmitDimRectIndx();
        tryCalcAndEmitMosaicIndx();
    }
#ifdef PULSE_MOSAIC_DEBUG
    dbgLogHorizon("attitude");
#endif
}

void DataHorizon::onAddedArtificalAttitude(uint64_t indx)
{
    //qDebug() << "DataHorizon::onAddedArtificalAttitude" << indx;

    resetOnIndexRollback(indx, artificalAttitudeIndx_);

    bool beenChanged = artificalAttitudeIndx_ != indx;

    artificalAttitudeIndx_ = indx;

    if (canEmitHorizon(beenChanged)) {
        //emit artificalAttitudeAdded(artificalAttitudeIndx_);
        tryCalcAndEmitSonarPosIndx();
        tryCalcAndEmitDimRectIndx();
        tryCalcAndEmitMosaicIndx();
    }
#ifdef PULSE_MOSAIC_DEBUG
    dbgLogHorizon("artAttitude");
#endif
}

void DataHorizon::onAddedBottomTrack(uint64_t indx)
{
    //qDebug() << "DataHorizon::onAddedBottomTrack" << indx;

    if (indx < bottomTrackIndx_) { // discard changes by editing bTr on plot
        return;
    }

    bool beenChanged = bottomTrackIndx_ != indx;

    bottomTrackIndx_ = indx;

    if (canEmitHorizon(beenChanged)) {
        //emit bottomTrackAdded(bottomTrackIndx_);
        tryCalcAndEmitMosaicIndx();
    }
#ifdef PULSE_MOSAIC_DEBUG
    dbgLogHorizon("bottomTrack");
#endif
}

void DataHorizon::onAddedBottomTrack3D(const QVector<int>& epIndxs, const QVector<int>& vertIndx, bool isManual)
{
    //qDebug() << "DataHorizon::onAddedBottomTrack3D" << epIndxs;

    if (epIndxs.isEmpty() || vertIndx.isEmpty()) {
        return;
    }

    if (!isSeparateReading_ && isFileOpening_) {
        const int pairCount = qMin(epIndxs.size(), vertIndx.size());
        for (int i = 0; i < pairCount; ++i) {
            pendingBottomTrack3DPairs_.insert(epIndxs[i], vertIndx[i]);
        }
        pendingBottomTrack3DManual_ = pendingBottomTrack3DManual_ || isManual;
        return;
    }

    bool beenChanged = true; // NEED COMPARE?

    if (canEmitHorizon(beenChanged)) {
        emit bottomTrack3DAdded(epIndxs, vertIndx, isManual);
    }
}

bool DataHorizon::canEmitHorizon(bool beenChanged) const
{
    bool retVal = false;

    if (!emitChanges_) {
        return retVal;
    }

    if (isSeparateReading_) {
        if (beenChanged) {
            retVal = true;
        }
    }
    else {
        if (!isFileOpening_ && beenChanged) {
            retVal = true;
        }
    }

    return retVal;
}

bool DataHorizon::resetOnIndexRollback(uint64_t incomingIndx, uint64_t currentIndx)
{
    if (incomingIndx >= currentIndx) {
        return false;
    }

    //qDebug() << "DataHorizon: index rollback detected"
    //         << "current" << currentIndx << "incoming" << incomingIndx
    //         << "- reset horizon for new session";

    clear();

    return true;
}

uint64_t DataHorizon::getActualAttitudeIndx() const
{
    return std::max(attitudeIndx_, artificalAttitudeIndx_);
}

void DataHorizon::tryCalcAndEmitMosaicIndx()
{
    const uint64_t attitudeIndx = getActualAttitudeIndx();
    uint64_t minMosaicHorizon = std::min(std::min(std::min(bottomTrackIndx_, chartIndx_), attitudeIndx), sonarPosIndx_);
    if (minMosaicHorizon > mosaicIndx_) {
        mosaicIndx_ = minMosaicHorizon;
        emit mosaicCanCalc(mosaicIndx_);
    }
}

void DataHorizon::tryCalcAndEmitSonarPosIndx()
{
    const uint64_t attitudeIndx = getActualAttitudeIndx();
    uint64_t minSonarIndx = isAttitudeExpected_ ? std::min(positionIndx_, attitudeIndx) : positionIndx_;
    if (minSonarIndx > sonarPosIndx_) {
        sonarPosIndx_ = minSonarIndx;
        emit sonarPosCanCalc(sonarPosIndx_);
    }
}

void DataHorizon::tryCalcAndEmitDimRectIndx()
{
    uint64_t minDimRectIndx = sonarPosIndx_;
    if (minDimRectIndx > dimRectIndx_) {
        dimRectIndx_ = minDimRectIndx;
        emit dimRectsCanCalc(dimRectIndx_);
    }
}

#ifdef PULSE_MOSAIC_DEBUG
void DataHorizon::dbgLogHorizon(const char* where)
{
    // PULSE TRIAL: throttled (~1 Hz) frontier dump. The mosaic frontier is
    // min(bottomTrack, chart, max(att,artAtt), sonarPos); whichever column
    // trails 'epoch' is the stream starving the side-scan mosaic. A growing
    // (epoch - sonarPos) gap is the "Data prepairing..." that never clears.
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    if (nowMs - dbgLastLogMs_ < 1000) {
        return;
    }
    dbgLastLogMs_ = nowMs;

    const uint64_t attIndx = getActualAttitudeIndx();
    qInfo().nospace()
        << "[PULSE_MOSAIC] " << where
        << " epoch=" << epochIndx_
        << " chart=" << chartIndx_
        << " pos=" << positionIndx_
        << " att=" << attitudeIndx_
        << " artAtt=" << artificalAttitudeIndx_
        << " attUsed=" << attIndx
        << " sonarPos=" << sonarPosIndx_
        << " dimRect=" << dimRectIndx_
        << " mosaic=" << mosaicIndx_
        << " | gap(epoch-sonarPos)=" << (epochIndx_ >= sonarPosIndx_ ? epochIndx_ - sonarPosIndx_ : 0)
        << " gap(epoch-mosaic)=" << (epochIndx_ >= mosaicIndx_ ? epochIndx_ - mosaicIndx_ : 0)
        << " attExpected=" << isAttitudeExpected_
        << " fileOpening=" << isFileOpening_;
}
#endif
