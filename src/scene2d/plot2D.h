#pragma once

#include <QObject>
#include <QVector>
#include <QImage>
#include <QPoint>
#include <QPointF>
#include <QPixmap>
#include <QPainter>
#include <QEvent>


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
    int visibleColsOnScreen()   const { return visibleColsOnScreen_; }

    // Optional setters if other C++ wants to push directly
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

    bool getImage(int width, int height, QPainter* painter, bool is_horizontal);
    void draw(QPainter* painterPtr);
    bool drawEchogramZoomPreview(QPainter* painter, const QRect& targetRect, const QPoint& sourceCenter, int sourceSize, QPointF* focusPoint = nullptr);
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
    void setDopplerInstrumentVisible(bool visible);

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

    void setDistance(float from, float to);
    void zoomDistance(float ratio);
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

protected:
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

private:
    bool   isEnabled_;
    bool   isSideScanLeftHand_  = false;
    bool   isSideScan2DView_    = false;
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
                int compensationId,
                bool bottomTrackVisible,
                int bottomTrackThemeId,
                bool rangefinderVisible,
                int rangefinderThemeId);

private:
    void updateEchogramSettings(int themeId, float lowLevel, float highLevel, int compensationId);

    int cachedThemeId_ = -1;
    int cachedCompensationId_ = -1;
    float cachedLowLevel_ = NAN;
    float cachedHighLevel_ = NAN;

};
