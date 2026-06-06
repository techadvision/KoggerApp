#pragma once

#include <QObject>
#include <QHash>

// ── PULSE TRIAL (feature/enable-3d-mosaic): mosaic/spatial-index diagnostics ──
// Define PULSE_MOSAIC_DEBUG to log the DataHorizon frontiers (epoch / chart /
// position / attitude / artificial-yaw / sonarPos / dimRect / mosaic) so we can
// see WHICH frontier flatlines and starves the side-scan mosaic. Throttled to
// ~1 Hz. Remove this block (and the matching ones in dataset.cpp) before any
// merge to master. Comment out the next line to silence without code changes.
#define PULSE_MOSAIC_DEBUG 1
// ─────────────────────────────────────────────────────────────────────────────


class DataHorizon : public QObject
{
    Q_OBJECT

public:
    DataHorizon();

    void clear();

    void setEmitChanges(bool state);
    void setIsFileOpening(bool state);
    void setIsAttitudeExpected(bool state);

    uint64_t getEpochSize() const { return epochIndx_; };
    uint64_t getPositionIndx() const { return positionIndx_; };
    uint64_t getChartIndx() const { return chartIndx_; };
    uint64_t getAttitudeIndx() const { return attitudeIndx_; };
    uint64_t getArtificalAttitudeIndx() const { return artificalAttitudeIndx_; };
    uint64_t getBottomTrackIndx() const { return bottomTrackIndx_; };

signals:
    void epochAdded(uint64_t indx);
    void positionAdded(uint64_t indx);
    void chartAdded(uint64_t indx);
    //void attitudeAdded(uint64_t indx);
    //void artificalAttitudeAdded(uint64_t indx);
    //void bottomTrackAdded(uint64_t indx); //
    void bottomTrack3DAdded(const QVector<int>& epIndxs, const QVector<int>& vertIndxs, bool isManual);
    void mosaicCanCalc(uint64_t indx); // uisng for dim rect in dataset
    void sonarPosCanCalc(uint64_t indx);
    void dimRectsCanCalc(uint64_t indx);

public slots:
    // Dataset
    void onAddedEpoch(uint64_t indx);
    void onAddedPosition(uint64_t indx);
    void onAddedChart(uint64_t indx);
    void onAddedAttitude(uint64_t indx);
    void onAddedArtificalAttitude(uint64_t indx);
    void onAddedBottomTrack(uint64_t indx); // from bottom track algorithm
    void onAddedBottomTrack3D(const QVector<int>& epIndxs, const QVector<int>& vertIndxs, bool isManual); // from 2D (editing), 3D

private:
    bool canEmitHorizon(bool beenChanged) const;
    bool resetOnIndexRollback(uint64_t incomingIndx, uint64_t currentIndx);
    uint64_t getActualAttitudeIndx() const;
    void tryCalcAndEmitMosaicIndx();
    void tryCalcAndEmitSonarPosIndx();
    void tryCalcAndEmitDimRectIndx();
#ifdef PULSE_MOSAIC_DEBUG
    // PULSE TRIAL: throttled frontier dump (see PULSE_MOSAIC_DEBUG note at top).
    void dbgLogHorizon(const char* where);
    qint64 dbgLastLogMs_ = 0;
#endif

private:
    bool emitChanges_;
    bool isFileOpening_;
    bool isSeparateReading_;
    bool isAttitudeExpected_;
    bool pendingBottomTrack3DManual_;

    uint64_t epochIndx_;
    uint64_t positionIndx_;
    uint64_t chartIndx_;
    uint64_t attitudeIndx_;
    uint64_t artificalAttitudeIndx_;
    uint64_t bottomTrackIndx_;
    uint64_t mosaicIndx_;
    uint64_t sonarPosIndx_;
    uint64_t dimRectIndx_;

    QHash<int, int> pendingBottomTrack3DPairs_;
};
