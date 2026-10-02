#pragma once

#include <QObject>
#include <QVector>
#include <QImage>
#include <QPoint>
#include <QPointF>
#include <QPixmap>
#include <QPainter>
#include <QEvent>
#include <QMargins>


#include "plot2D_aim.h"
#include "plot2D_attitude.h"
#include "plot2D_bottom_processing.h"
#include "plot2D_contact.h"
#include "plot2D_defs.h"
#include "plot2D_dvl_beam_velocity.h"
#include "plot2D_dvl_solution.h"
#include "plot2D_echogram.h"
#include "plot2D_encoder.h"
#include "plot2D_gnss.h"
#include "plot2D_grid.h"
#include "plot2D_temperature.h"
#include "plot2D_quadrature.h"
#include "plot2D_rangefinder.h"
#include "plot2D_depth.h"
#include "plot2D_usbl_solution.h"
#include "dataset.h"
#include "data_processor.h"
//#define TRACE_ECH_PICK 1 // <-- enable logging

class QObject;

class Plot2D
{
public:
    Plot2D();

    void applyRuntime(const QVariantMap& m);   // NEW
    void applyPersistent(const QVariantMap& m);// NEW (future-proof)
    void setQObjectContext(QObject* ctx) { qobjectContext_ = ctx; }
    QObject* qobjectContext() const { return qobjectContext_; }
    static inline bool kIs32BitProcess() {
        return sizeof(void*) == 4;
    }
    int rightmostEpochOnScreen() const { return rightmostEpochOnScreen_; }

    // WHAT A SCREEN OF ECHOGRAM ACTUALLY HOLDS - an instrument, 30 Sept (session 7).
    // Screen pixels per epoch, measured from the column table and the painter scale that
    // getImage() really applied, not from the setting. The setting says what the picture
    // should do; this says what it did. Empty string until the screen holds data.
    QString stretchReport() const;
    int visibleColsOnScreen()   const { return visibleColsOnScreen_; }

    // THE STRETCH - screen columns per epoch, in BOTH flow directions (session 7, 30 Sept).
    //
    // It lives in the column table (reindexingCursor) and nowhere else: a stretch of 3
    // repeats an epoch over three columns, 0.5 puts every other epoch in a column. Until
    // 30 Sept it was ALSO a painter scale in getImage(), so a horizontal picture got it
    // twice (px per epoch = s squared) and a tap, which reads the table in screen columns,
    // disagreed with what was drawn - the reason pause used to drop the speed to 1.0.
    // Now drawing, taps, the loupe, markers and the scroll clamp read one mapping.
    //
    // No orientation, flip or "above 1" condition: the flip is a vertical mirror and does
    // not touch the columns, and below 1 is a compressed picture, not an error.
    //
    // FROZEN WHILE PAUSED: a speed or model change under a paused picture must not reflow it
    // under the crosshair. The value in force when the pause began holds until the resume.
    double stretch() const {
        const double s = echogramPause_ ? pausedStretch_ : liveStretch();
        return (std::isfinite(s) && s >= 0.05) ? s : 1.0;
    }

    // TRUE PROPORTIONS FOR THE SIDE SCAN (session 7, slice B; Olav 30 Sept: the side scan is
    // always a true render). A metre along the track takes as many pixels as a metre across:
    //   across px per metre = P / swath        (P = the pane's across-track canvas px)
    //   along  m per ping   = v x T            (boat speed x the confirmed ping period)
    //   stretch (px per ping) = v x T x P / swath
    // Capped at kTrueStretchCap; beyond it the picture is shortened along the track and
    // trueShortenedBy() says by how much, for the "1 : 3.1" label. Each pane asks its own
    // width and range, so a split's side pane is true and its down pane is not touched.
    static constexpr double kTrueStretchCap = 3.0;
    bool isTrueProportionsPane() const { return trueProportions_ && !isHorizontal_; }
    double trueStretchWanted() const {
        const double swath = std::abs(double(cursor_.distance.to) - double(cursor_.distance.from));
        const int    P     = canvas_.height();
        if (!(swath > 0.1) || P <= 0 || !(boatSpeedMps_ > 0.0) || !(truePingPeriodMs_ > 0.0))
            return 1.0;
        return boatSpeedMps_ * (truePingPeriodMs_ / 1000.0) * double(P) / swath;
    }
    double trueShortenedBy() const {
        if (!isTrueProportionsPane()) return 1.0;
        return std::max(1.0, trueStretchWanted() / kTrueStretchCap);
    }
    // THE DOWN SCAN HAS ITS OWN SPEED (Olav, 30 Sept): a blue's down pane is a horizontal
    // pane drawn from a side scan (isSideScan2DView, per pane under the split's override),
    // and it takes downScanSpeed_ instead of the 2D echogram speed, full screen or split.
    bool isDownScanPane() const { return isSideScan2DView_ && isHorizontal_; }
    double liveStretch() const {
        if (isTrueProportionsPane())
            return std::clamp(trueStretchWanted(), 0.05, kTrueStretchCap);
        if (isDownScanPane())
            return downScanSpeed_;
        return echogramSpeed_;
    }

    // Optional setters if other C++ wants to push directly
    // THE PER-PANE GRID (Stage 4 b, side over down). "" follows the settings bus, which is
    // what every pane did until now; "side" or "down" pins THIS pane's grid whatever the bus
    // says. See applyRuntime() for why it has to be here and not on the three objects that
    // read the value.
    void setGridModeOverride(const QString& mode) { gridModeOverride_ = mode; }
    QString gridModeOverride() const              { return gridModeOverride_; }

    void setIsSideScanLeftHand(bool v)   { isSideScanLeftHand_ = v; }
    void setIsSideScan2DView(bool v)     { isSideScan2DView_   = v; }
    void setEchogramSpeed(double v)      { echogramSpeed_      = v; }
    void setIs2DTransducer(bool v)       { is2DTransducer_     = v; }
    void setShouldDoAutoRange(bool v)    { shouldDoAutoRange_  = v; }
    void setAutoDepthMaxLevel(double v)  { autoDepthMaxLevel_  = v; }
    void setMaximumDepth(int v)          { maximumDepth_       = v; }
    void setAutoRange(int v)             { autoRange_          = v; }

    void setDataset(Dataset* dataset);
    void setDataProcessorPtr(DataProcessor* dataProcessorPtr);

    float getDepthByMousePos(int mouseX, int mouseY, bool isHorizontal) const;
    float getSyncDepthByMousePos(int mouseX, int mouseY, bool isHorizontal, int* channelOut) const;
    int getEpochIndxByMousePos(int mouseX, int mouseY, bool isHorizontal) const;
    QPoint getMousePosByDepthAndEpochIndx(float depth, int epochIndx, bool isHorizontal) const;

    void addReRenderPlotIndxs(const QSet<int>& indxs);

    bool getPlotEnabled() const;
    void setPlotEnabled(bool state);

    bool plotEnabled() const;
    bool getLoupeVisible() const;
    void setLoupeVisible(bool state);
    int getLoupeSize() const;
    void setLoupeSize(int size);
    int getLoupeZoom() const;
    void setLoupeZoom(int zoom);

    bool isHorizontal();
    void setHorizontal(bool is_horizontal);

    void setAimEpochEventState(bool state);
    void setTimelinePosition(float position);
    void resetAim();

    void setTimelinePositionSec(float position);
    void setTimelinePositionByEpoch(int epochIndx);
    void setSyncCursor(int epoch, float depth, int channel);
    void clearSyncCursor();
    virtual void syncClearAim() {}
    // Which pane this is, for log lines only. Plot2D has no index of its own; qPlot2D has.
    virtual int paneIndexForLog() const { return -1; }
    bool hasSyncDepth() const { return syncDepthValid_; }

    // TRUE when this pane's aim did not come from a touch on THIS pane. Two routes get one
    // there: main.qml's handlePlotPressed mirrors it in via setAim(), which is
    // plotMousePosition(x, y, isSync = true); and Core::broadcastEpochCursor pushes it in
    // via setSyncCursor(), which is what syncDepthValid_ already marks.
    //
    // A FOREIGN AIM GETS THE CROSSHAIR AND NOT THE PANEL. The crosshair is the whole point
    // of the correlation - it says where you are on the other view. The panel is a control
    // surface for the epoch under your finger, and there is only one finger: a second panel
    // is anchored to a point nobody pressed, which is why it also came up misplaced.
    // Olav, 16 Sept: "Just need that not-touched screen not to create a zoom box."
    bool aimIsForeign() const { return aimIsMirrored_ || syncDepthValid_; }
    float getSyncDepth() const { return syncDepth_; }
    int getSyncChannel() const { return syncChannel_; }
    void setAimFieldsMask(int mask) { aimFieldsMask_ = mask; }
    int getAimFieldsMask() const { return aimFieldsMask_; }

    float timelinePosition();
    void scrollPosition(int columns);

    void setDataChannel(bool fromGui, const ChannelId& channel, uint8_t subChannel1, const QString& portName1, const ChannelId& channel2 = channelNone(), uint8_t subChannel2 = 0, const QString& portName2 = QString());

    bool getIsContactChanged();

    QString getContactInfo();
    void    setContactInfo(const QString& str);
    bool    getContactVisible();
    void    setContactVisible(bool state);
    int     getContactPositionX();
    int     getContactPositionY();
    int     getContactIndx();
    double  getContactLat();
    double  getContactLon();
    double  getContactDepth();
    bool    getContactIsActive();

    bool getImage(int width, int height, QPainter* painter, bool is_horizontal);
    void draw(QPainter* painterPtr);
    bool drawEchogramZoomPreview(QPainter* painter, const QRect& targetRect, const QPoint& sourceCenter, int sourceSize, QPointF* focusPoint = nullptr);
    void copyVisualConfigTo(Plot2D& dst) const;
    bool drawEchogramZoomPreview(QPainter* painter, const QRect& targetRect, const QPoint& sourceCenter, int sourceWidth, int sourceHeight, QPointF* focusPoint = nullptr);

    float getCursorDistance() const;
    std::tuple<ChannelId, uint8_t, QString> getSelectedChannelId(float cursorDistance = 0.0f) const;

    float getEchogramLowLevel() const;
    float getEchogramHighLevel() const;
    int getThemeId() const;
    int getEchogramCompensation() const;
    void setEchogramLowLevel(float low);
    void setEchogramHightLevel(float high);
    void setEchogramVisible(bool visible);
    void setEchogramTheme(int theme_id);
    void setEchogramCompensation(int compensation_id);

    void setBottomTrackVisible(bool visible);
    void setBottomTrackTheme(int theme_id);
    void setBottomTrackDepthTextVisible(bool visible);
    bool getBottomTrackVisible() const;
    int getBottomTrackTheme() const;

    void setRangefinderVisible(bool visible);
    void setRangefinderTheme(int theme_id);
    void setRangefinderDepthTextVisible(bool visible);
    bool getRangefinderVisible() const;
    int getRangefinderTheme() const;
    void setAttitudeVisible(bool visible);
    void setTemperatureVisible(bool visible);
    bool hasTemperatureValue() const;
    bool hasRangefinderDepthTextValue() const;
    void setDopplerBeamVisible(bool visible, int beam_filter);
    void setDopplerInstrumentVisible(bool visible, int line_filter = -1);
    void setDVLLegendVisible(bool visible);
    void setDVLLegendPosition(int pos);

    void setGNSSVisible(bool visible, int flags);

    void setAcousticAngleVisible(bool visible);

    void setGridVetricalNumber(int grids);
    void setGridFillWidth(bool state);
    void setGridInvert(bool state);
    void setAngleVisibility(bool state);
    void setAngleRange(int angleRange);

    void setVelocityVisible(bool visible);
    void setVelocityRange(float velocity);
    void setDistanceAutoRange(int auto_range_type);

    bool getEchogramVisible() const { return echogram_.isVisible(); }
    bool getBottomTrackDepthTextVisible() const { return bottomProcessing_.isDepthTextVisible(); }
    bool getRangefinderDepthTextVisible() const { return rangefinder_.isDepthTextVisible(); }
    bool getAttitudeVisible() const { return attitude_.isVisible(); }
    bool getTemperatureVisible() const { return temperature_.isVisible(); }
    bool getAcousticAngleVisible() const { return usblSolution_.isVisible(); }
    bool getGNSSVisible() const { return gnss_.isVisible(); }
    bool getDopplerBeamVisible() const { return dvlBeamVelocity_.isVisible(); }
    int  getDopplerBeamFilter() const { return dvlBeamVelocity_.getBeamFilter(); }
    bool getDopplerInstrumentVisible() const { return dvlSolution_.isVisible(); }
    int  getDopplerInstrumentFilter() const { return dvlSolution_.getLineFilter(); }
    bool getDVLLegendVisible() const { return dvlLegendVisible_; }
    int  getDVLLegendPosition() const { return dvlLegendPosIndex_; }
    int  getGridVerticalNumber() const { return grid_.getVetricalNumber(); }
    bool getGridFillWidth() const { return grid_.isFillWidth(); }
    bool getGridInvert() const { return grid_.isInvert(); }
    bool getAngleVisibility() const { return grid_.getAngleVisibility(); }
    bool getVelocityVisible() const { return grid_.getVelocityVisible(); }
    int  getAngleRange() const { return std::isfinite(cursor_.attitude.to) ? static_cast<int>(std::lround(cursor_.attitude.to)) : 0; }
    float getVelocityRange() const { return std::isfinite(cursor_.velocity.to) ? cursor_.velocity.to : 0.0f; }
    int  getDistanceAutoRange() const { return static_cast<int>(cursor_.distance.mode); }

    void setDistance(float from, float to);
    void zoomDistance(float ratio);
    //PULSE, 29 Sept: a range that does not cross zero is written in the ONE form the current
    //left-hand/down flip draws upright. See the definition for why.
    void conformDownRange(const char* why);
    void scrollDistance(float ratio);

    void setMousePosition(int x, int y, bool isSync = false);
    void simpleSetMousePosition(int x, int y);
    void setMouseTool(MouseTool tool);
    bool setContact(int indx, const QString& text);
    bool setActiveContact(int indx);
    bool deleteContact(int indx);
    void updateContact();
    void onCursorMoved(int x, int y);

    Canvas& canvas();
    DatasetCursor& cursor();

    void resetCash();
    void releaseCache();
    Canvas image(int width, int height);
    void reindexingCursor();
    void reRangeDistance();

    virtual void plotUpdate();
    virtual void sendSyncEvent(int epoch_index, QEvent::Type eventType);

    //Pulse
    Q_INVOKABLE void setDragActive(bool active);
    Q_INVOKABLE void setHoldHistory (bool hold);
    const QPixmap& echogramPixmap() const { return echogram_.pixmap(); }
    void clearPauseFreeze();
    void freezePauseWindow();
    bool hasFrozenWindow() const { return frozenValid_; }
    int  frozenHead()     const { return frozenHead_; }
    int  frozenHeight()   const { return frozenH_; }
    bool isEchogramPaused() const { return aim_.isPaused(); }
    bool isTapInsideZoom(int devX, int devY) const {
        // aim_.isTapInsideZoom needs a Plot2D*, pass this
        return aim_.isTapInsideZoom(const_cast<Plot2D*>(this), devX, devY);
    }
    void setMosaicLOffset(float val);
    void setMosaicROffset(float val);

    // HOW MUCH OF THIS PANE LIES UNDER THE SYSTEM BARS, in CANVAS px, per edge.
    //
    // The v2 echogram is drawn edge to edge, under the navigation bar - Olav, 28 Sept: the
    // picture is the point, and there is rarely a reason to press at the far edge. What must
    // NOT go under a bar is anything the user reads or taps: the loupe's buttons and the
    // ruler's labels. Those are painted in C++ and cannot see QML's insets, and the old
    // grid code assumed every pane touched the right and bottom edges of the screen, which a
    // split pane does not. So qPlot2D::paint measures the real overlap of THIS pane with the
    // bars on every frame, and the layers read it here. Zero wherever a pane does not reach
    // a bar, and zero off Android.
    QMargins systemBarOverlap() const { return systemBarOverlap_; }

protected:
    QMargins systemBarOverlap_;
    Canvas canvas_;
    DatasetCursor cursor_;

    Plot2DAim aim_;
    Plot2DAttitude attitude_;
    Plot2DBottomProcessing bottomProcessing_;
    Plot2DContact contacts_;
    Plot2DDVLBeamVelocity dvlBeamVelocity_;
    Plot2DDVLSolution dvlSolution_;
    Plot2DEchogram echogram_;
    Plot2DEncoder encoder_;
    Plot2DGNSS gnss_;
    Plot2DGrid grid_;
    Plot2DTemperature temperature_;
    Plot2DQuadrature quadrature_;
    Plot2DRangefinder rangefinder_;
    Plot2DDepth depth_;
    Plot2DUSBLSolution usblSolution_;
    Dataset* datasetPtr_;
    DataProcessor* dataProcessorPtr_;
    std::function<void()> pendingBtpLambda_;
    bool isHorizontal_;
    bool dvlLegendVisible_ = true;
    int  dvlLegendPosIndex_ = 0;
    bool aimIsMirrored_ = false;      // see aimIsForeign()
    bool syncDepthValid_ = false;
    float syncDepth_ = 0.0f;          // absolute physical depth (>=0 from surface)
    int syncChannel_ = 1;             // which channel the synced depth belongs to (1/2)
    int aimFieldsMask_ = 0xFF;

private:
    bool   isEnabled_;
    bool   isSideScanLeftHand_  = false;
    bool   isSideScan2DView_    = false;
    QString gridModeOverride_;
    double echogramSpeed_       = 1.0;
    bool   is2DTransducer_      = true;
    bool   shouldDoAutoRange_   = false;
    double autoDepthMaxLevel_   = 49.0;
    int    maximumDepth_        = 50;
    int    autoRange_           = 5;
    bool   echogramPause_       = false;
    bool   echogramDragActive_  = false;
    bool   echogramHoldHistory_ = false;
    QObject* qobjectContext_ = nullptr;
    int rightmostEpochOnScreen_ = 0;
    int visibleColsOnScreen_ = 0;
    double painterStretch_ = 1.0;  // the horizontal painter scale getImage() applied last
    double pausedStretch_  = 1.0;  // liveStretch() when the pause began; see stretch()
    bool   trueProportions_  = false;  // runtime "sideScanTrueProportions"
    double boatSpeedMps_     = 3.0 / 3.6;
    double truePingPeriodMs_ = 70.0;
    double downScanSpeed_    = 1.0;    // runtime "downScanSpeed"
    int  frozenHead_   = -1;   // headAtPause = lastCap + 1 (newest = head-1)
    int  frozenH_      = 0;    // canvas height at pause
    bool frozenValid_  = false;

#ifdef TRACE_ECH_PICK
    QTransform lastEch_WorldToDevice_;
    QTransform lastEch_DeviceToWorld_;
    int        lastEch_W_ = 0;
    int        lastEch_H_ = 0;
    int        lastEch_Frame_ = 0;
#endif
    //bool isEnabled_;
    bool isLoupeVisible_;
    int loupeSize_;
    int loupeZoom_;
    float lAngleOffsetDeg_;
    float rAngleOffsetDeg_;
};

class MiniPreviewPlot2D final : public Plot2D
{
public:
    MiniPreviewPlot2D();

    bool render(QPainter* painter,
                Dataset* dataset,
                const Plot2D* configSource,
                const DatasetCursor& parentCursor,
                int parentCanvasWidth,
                int sourceLeft,
                int sourceWidth,
                int previewWidth,
                int previewHeight,
                float zoomFrom,
                float zoomTo,
                int themeId,
                float lowLevel,
                float highLevel,
                int compensationId);

private:
    void updateEchogramSettings(int themeId, float lowLevel, float highLevel, int compensationId);

    int cachedThemeId_ = -1;
    int cachedCompensationId_ = -1;
    float cachedLowLevel_ = NAN;
    float cachedHighLevel_ = NAN;

};
