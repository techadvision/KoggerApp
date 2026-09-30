#include "plot2D.h"
#include "epoch_event.h"

//PULSE
#include <QObject>
#include <QVariant>
#include <QDebug>

#include "qmath.h"
#include <cmath>
#include <climits>
#include <algorithm>

MiniPreviewPlot2D::MiniPreviewPlot2D()
{
    setHorizontal(true);
    setPlotEnabled(true);
    echogram_.setVisible(true);
    echogram_.setWrapEnabled(false);
    bottomProcessing_.setVisible(true);
    bottomProcessing_.setDepthTextVisible(false);
    rangefinder_.setVisible(false); //We do not want this for pulse
    rangefinder_.setTheme(1);
    rangefinder_.setDepthTextVisible(false);
}

void MiniPreviewPlot2D::updateEchogramSettings(int themeId, float lowLevel, float highLevel, int compensationId)
{
    if (cachedThemeId_ != themeId) {
        echogram_.setThemeId(themeId);
        cachedThemeId_ = themeId;
    }

    const bool levelsChanged = !std::isfinite(cachedLowLevel_)
        || !std::isfinite(cachedHighLevel_)
        || std::abs(cachedLowLevel_ - lowLevel) > 1e-6f
        || std::abs(cachedHighLevel_ - highLevel) > 1e-6f;
    if (levelsChanged) {
        echogram_.setLevels(lowLevel, highLevel);
        cachedLowLevel_ = lowLevel;
        cachedHighLevel_ = highLevel;
    }

    if (cachedCompensationId_ != compensationId) {
        echogram_.setCompensation(compensationId);
        cachedCompensationId_ = compensationId;
    }
}

bool MiniPreviewPlot2D::render(QPainter* painter,
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
                               int compensationId)
{
    if (!painter || !dataset || previewWidth <= 0 || previewHeight <= 0 || parentCanvasWidth <= 0) {
        return false;
    }

    if (datasetPtr_ != dataset) {
        setDataset(dataset);
    }
    canvas_.setSize(previewWidth, previewHeight, painter);

    cursor_.channel1 = parentCursor.channel1;
    cursor_.subChannel1 = parentCursor.subChannel1;
    cursor_.channel2 = parentCursor.channel2;
    cursor_.subChannel2 = parentCursor.subChannel2;

    cursor_.distance.mode = AutoRangeNone;
    cursor_.distance.from = zoomFrom;
    cursor_.distance.to = zoomTo;
    cursor_.setMouse(-1, -1);
    cursor_.setContactPos(-1, -1);
    cursor_.selectEpochIndx = -1;
    cursor_.currentEpochIndx = -1;
    cursor_.lastEpochIndx = -1;

    int zeroEpochCount = 0;
    const int maxParentX = parentCanvasWidth - 1;
    const float stepX = static_cast<float>(sourceWidth) / static_cast<float>(previewWidth);
    float srcXFloat = static_cast<float>(sourceLeft) + stepX * 0.5f;
    QVector<QPair<int, int>> noDataRanges;
    int noDataStart = -1;

    cursor_.indexes.resize(previewWidth);
    for (int column = 0; column < previewWidth; ++column) {
        const int sourceX = qRound(srcXFloat);
        srcXFloat += stepX;

        const bool sourceInBounds = sourceX >= 0 && sourceX <= maxParentX;
        const int epochIndex = sourceInBounds ? parentCursor.getIndex(sourceX) : -1;
        const bool validEpoch = sourceInBounds && dataset->validIndex(epochIndex) >= 0;

        if (!validEpoch) {
            ++zeroEpochCount;
            cursor_.indexes[column] = -1;
            if (noDataStart < 0) {
                noDataStart = column;
            }
        }
        else {
            cursor_.indexes[column] = epochIndex;
            if (noDataStart >= 0) {
                noDataRanges.append(qMakePair(noDataStart, column));
                noDataStart = -1;
            }
        }
    }
    if (noDataStart >= 0) {
        noDataRanges.append(qMakePair(noDataStart, previewWidth));
    }

    cursor_.numZeroEpoch = zeroEpochCount;

    updateEchogramSettings(themeId, lowLevel, highLevel, compensationId);
    if (configSource) {
        configSource->copyVisualConfigTo(*this);
    }
    //UPSTREAM 1.0.3 replaced the bottomTrackVisible / bottomTrackThemeId /
    //rangefinderVisible / rangefinderThemeId parameters with configSource, and
    //copyVisualConfigTo() above now sets all four from the parent plot. Only the Pulse
    //override is still needed, and it has to come AFTER the copy so it still wins.
    rangefinder_.setVisible(false); //We do not want this for pulse

    const bool rendered = echogram_.draw(this, dataset);
    if (!rendered) {
        return false;
    }

    QPainter* canvasPainter = canvas_.painter();

    if (canvasPainter != nullptr) {
        for (const auto& range : noDataRanges) {
            const int xFrom = range.first;
            const int xTo = range.second;
            if (xTo > xFrom) {
                canvasPainter->fillRect(xFrom, 0, xTo - xFrom, previewHeight, Qt::black);
            }
        }
    }

    attitude_.draw(this, dataset);
    encoder_.draw(this, dataset);
    dvlBeamVelocity_.draw(this, dataset);
    dvlSolution_.draw(this, dataset);
    usblSolution_.draw(this, dataset);
    bottomProcessing_.draw(this, dataset);
    rangefinder_.draw(this, dataset);
    depth_.draw(this, dataset);
    gnss_.draw(this, dataset);
    quadrature_.draw(this, dataset);

    return true;
}

void Plot2D::copyVisualConfigTo(Plot2D& dst) const
{
    dst.setBottomTrackVisible(getBottomTrackVisible());
    dst.setBottomTrackTheme(getBottomTrackTheme());
    dst.setBottomTrackDepthTextVisible(false);

    dst.setRangefinderVisible(getRangefinderVisible());
    dst.setRangefinderTheme(getRangefinderTheme());
    dst.setRangefinderDepthTextVisible(false);

    dst.setAttitudeVisible(getAttitudeVisible());
    dst.setTemperatureVisible(getTemperatureVisible());

    dst.setDopplerBeamVisible(getDopplerBeamVisible(), getDopplerBeamFilter());
    dst.setDopplerInstrumentVisible(getDopplerInstrumentVisible(), getDopplerInstrumentFilter());

    dst.setAcousticAngleVisible(getAcousticAngleVisible());
    dst.setGNSSVisible(getGNSSVisible(), 0);

    dst.setGridVetricalNumber(getGridVerticalNumber());
    dst.setGridFillWidth(getGridFillWidth());
    dst.setGridInvert(getGridInvert());
    dst.setAngleVisibility(getAngleVisibility());
    dst.setAngleRange(getAngleRange());
    dst.setVelocityVisible(getVelocityVisible());
    dst.setVelocityRange(getVelocityRange());
}


Plot2D::Plot2D()
    : datasetPtr_(nullptr)
    , pendingBtpLambda_(nullptr)
    , isHorizontal_(true)
    , isEnabled_(true)
    , isLoupeVisible_(false)
    , loupeSize_(1)
    , loupeZoom_(0)
    , lAngleOffsetDeg_(0.0f)
    , rAngleOffsetDeg_(0.0f)
{
    qRegisterMetaType<ChannelId>("ChannelId");

    echogram_.setVisible(true);
    attitude_.setVisible(true);
    encoder_.setVisible(true);
    dvlBeamVelocity_.setVisible(true);
    dvlSolution_.setVisible(true);
    usblSolution_.setVisible(true);
    bottomProcessing_.setVisible(true);
    rangefinder_.setVisible(false);          // Pulse: no rangefinder overlay on the echogram (depth is shown in DepthAndTemperature)
    rangefinder_.setDepthTextVisible(false);
    depth_.setVisible(true);
    grid_.setVisible(true);
    temperature_.setVisible(true);
    aim_.setVisible(true);
    quadrature_.setVisible(false);
    setDataChannel(false, channelNone(), 0, {});
    cursor_.attitude.from = -180;
    cursor_.attitude.to = 180;
    cursor_.distance.set(0, 20);
}

//PULSE
void Plot2D::applyRuntime(const QVariantMap& mIn)
{
    //qDebug() << "applyRuntime this=" << this << " thread=" << QThread::currentThread();

    //PULSE, Stage 4 (b): THE PER-PANE GRID, applied to the MAP and applied exactly once.
    //
    //A split of side scan over down scan needs the two panes drawn with different grids, and
    //the settings bus cannot say so: every qPlot2D subscribes to the same SettingsBus and is
    //handed the same QVariantMap, so it is a broadcast by construction. This function is the
    //one funnel underneath that broadcast - whatever it reads, grid_ and aim_ read out of the
    //same map a few lines down - so rewriting the map here covers all three readers, and
    //there is no fourth place to keep in step.
    //
    //POLARITY, because the name says the opposite of what it means: isSideScan2DView is TRUE
    //for the DOWN view. It reads "draw this side scan device as a 2D picture", which is what
    //down scan is on a PULSE blue. Getting this backwards draws both panes the same and looks
    //like the override never arrived.
    QVariantMap m = mIn;
    if (!gridModeOverride_.isEmpty()) {
        const bool down = (gridModeOverride_ == QStringLiteral("down"));
        m[QStringLiteral("isSideScan2DView")] = down;
        m[QStringLiteral("isHorizontalGrid")] = down;
    }

    if (m.contains("isSideScanLeftHand"))  isSideScanLeftHand_ = m.value("isSideScanLeftHand").toBool();
    if (m.contains("isSideScan2DView"))    isSideScan2DView_   = m.value("isSideScan2DView").toBool();
    if (m.contains("isSideScanLeftHand") || m.contains("isSideScan2DView"))
        conformDownRange("the flip flags changed");
    if (m.contains("echogramSpeed"))       echogramSpeed_      = m.value("echogramSpeed").toDouble();
    if (m.contains("sideScanTrueProportions")) trueProportions_  = m.value("sideScanTrueProportions").toBool();
    if (m.contains("boatSpeedMps"))        boatSpeedMps_       = m.value("boatSpeedMps").toDouble();
    if (m.contains("truePingPeriodMs"))    truePingPeriodMs_   = m.value("truePingPeriodMs").toDouble();
    if (m.contains("downScanSpeed"))       downScanSpeed_      = m.value("downScanSpeed").toDouble();
    if (m.contains("is2DTransducer"))      is2DTransducer_     = m.value("is2DTransducer").toBool();
    if (m.contains("shouldDoAutoRange"))   shouldDoAutoRange_  = m.value("shouldDoAutoRange").toBool();
    if (m.contains("autoDepthMaxLevel"))   autoDepthMaxLevel_  = m.value("autoDepthMaxLevel").toDouble();
    if (m.contains("maximumDepth"))        maximumDepth_       = m.value("maximumDepth").toInt();
    if (m.contains("autoRange"))           autoRange_          = m.value("autoRange").toInt();
    if (m.contains("echogramPause")) {
        const bool newPause = m.value("echogramPause").toBool();
        if (newPause && !echogramPause_)
            pausedStretch_ = liveStretch();
        echogramPause_ = newPause;
        echogramDragActive_ = false;
    }

    grid_.applyRuntime(m);
    echogram_.applyPersistent(m);
    aim_.applyRuntime(m);
}

//PULSE
void Plot2D::applyPersistent(const QVariantMap& m)
{
    Q_UNUSED(m);
    // Add if/when you need persistent values here.
}

float Plot2D::getCursorDistance() const
{
    if (canvas_.height() <= 0) {
        return 0.0f;
    }

    const float valueRange = cursor_.distance.to - cursor_.distance.from;
    const float valueScale = static_cast<float>(cursor_.mouseY) / static_cast<float>(canvas_.height());

    return valueScale * valueRange + cursor_.distance.from;
}

std::tuple<ChannelId, uint8_t, QString> Plot2D::getSelectedChannelId(float cursorDistance) const
{
    const float dist = qFuzzyIsNull(cursorDistance) ? getCursorDistance() : cursorDistance;
    const bool useChannel1 = qFuzzyIsNull(dist) || dist < 0.0f || cursor_.channel2 == channelNone();

    return useChannel1 ? std::make_tuple(cursor_.channel1, cursor_.subChannel1, cursor_.firstChannelPortName) : std::make_tuple(cursor_.channel2, cursor_.subChannel2, cursor_.secondChannelPortName);
}


void Plot2D::setDataset(Dataset *dataset)
{
    datasetPtr_ = dataset;
    if (pendingBtpLambda_) {
        pendingBtpLambda_();
        pendingBtpLambda_ = nullptr;
    }
}

void Plot2D::setDataProcessorPtr(DataProcessor *dataProcessorPtr)
{
    dataProcessorPtr_ = dataProcessorPtr;
}

float Plot2D::getDepthByMousePos(int mouseX, int mouseY, bool isHorizontal) const
{
    int currPos = isHorizontal ? mouseY : mouseX;

    const float valueRange = cursor_.distance.to - cursor_.distance.from;
    const float valueScale = static_cast<float>(currPos) / static_cast<float>(canvas_.height());

    return valueScale * valueRange + cursor_.distance.from;
}

float Plot2D::getSyncDepthByMousePos(int mouseX, int mouseY, bool isHorizontal, int* channelOut) const
{
    const float coord = getDepthByMousePos(mouseX, mouseY, isHorizontal);

    int channel = 1;
    float depth = coord;
    if (cursor_.channel2 != channelNone()) {
        channel = (coord < 0.0f) ? 1 : 2;
        depth = std::fabs(coord);
    }
    if (channelOut) {
        *channelOut = channel;
    }
    return depth; // absolute physical depth (>=0)
}

int Plot2D::getEpochIndxByMousePos(int mouseX, int mouseY, bool isHorizontal) const
{
    const int width = canvas_.width();

    if (width == 0 || cursor_.indexes.empty()) {
        return -1;
    }

    int column = isHorizontal ? mouseX : (width - 1 - mouseY);
    int indxsSize = cursor_.indexes.size();
    if (column < 0 || column >= width || column >= indxsSize) {
        return -1;
    }

    return cursor_.indexes[column];
}

QPoint Plot2D::getMousePosByDepthAndEpochIndx(float depth, int epochIndx, bool isHorizontal) const
{
    if (!datasetPtr_ || canvas_.width() <= 0 || canvas_.height() <= 0) {
        return QPoint(-1, -1);
    }

    // THE CENTRE OF THE EPOCH'S BAND, not its first column (session 7). At a stretch of 3
    // an epoch is drawn over three columns and a marker belongs in the middle of them. At a
    // stretch below 1 some epochs are drawn in no column at all; the nearest drawn neighbour
    // stands in, as long as it is within the one column's worth of epochs it replaced.
    int firstCol = -1, lastCol = -1;
    int nearCol = -1, nearDist = INT_MAX;
    const int sizeIndxs = int(cursor_.indexes.size());
    for (int i = 0; i < sizeIndxs; ++i) {
        const int e = cursor_.indexes[i];
        if (e == epochIndx) {
            if (firstCol < 0) firstCol = i;
            lastCol = i;
        } else if (e >= 0 && firstCol < 0) {
            const int d = std::abs(e - epochIndx);
            if (d < nearDist) { nearDist = d; nearCol = i; }
        }
    }

    int column = -1;
    if (firstCol >= 0) {
        column = (firstCol + lastCol) / 2;
    } else if (nearCol >= 0 && nearDist <= int(std::ceil(1.0 / stretch()))) {
        column = nearCol;
    }

    if (column == -1) {
        return QPoint(-1, -1);
    }

    const float valueRange = cursor_.distance.to - cursor_.distance.from;
    const float norm = (depth - cursor_.distance.from) / valueRange;
    int depthPix = static_cast<int>(norm * canvas_.height());
    depthPix = std::clamp(depthPix, 0, canvas_.height() - 1);

    if (isHorizontal) {
        return QPoint(column, depthPix);
    }
    else {
        return QPoint(depthPix, canvas_.width() - 1 - column);
    }
}

void Plot2D::addReRenderPlotIndxs(const QSet<int> &indxs)
{
    if (!plotEnabled())
        return;
    echogram_.addReRenderPlotIndxs(indxs);
}

bool Plot2D::getPlotEnabled() const
{
    return isEnabled_;
}

void Plot2D::setPlotEnabled(bool state)
{
    isEnabled_ = state;
}

bool Plot2D::plotEnabled() const
{
    return isEnabled_;
}

bool Plot2D::getLoupeVisible() const
{
    return isLoupeVisible_;
}

void Plot2D::setLoupeVisible(bool state)
{
    if (isLoupeVisible_ == state) {
        return;
    }

    isLoupeVisible_ = state;
    plotUpdate();
}

int Plot2D::getLoupeSize() const
{
    return loupeSize_;
}

void Plot2D::setLoupeSize(int size)
{
    const int boundedSize = qBound(1, size, 3);
    if (loupeSize_ == boundedSize) {
        return;
    }

    loupeSize_ = boundedSize;
    plotUpdate();
}

int Plot2D::getLoupeZoom() const
{
    return loupeZoom_;
}

void Plot2D::setLoupeZoom(int zoom)
{
    const int boundedZoom = qBound(0, zoom, 300);
    if (loupeZoom_ == boundedZoom) {
        return;
    }

    loupeZoom_ = boundedZoom;
    plotUpdate();
}

bool Plot2D::getImage(int width, int height, QPainter* painter, bool is_horizontal)
{
    if (is_horizontal) {
        //Pulse
        const bool flipImage = isSideScanLeftHand_ && isSideScan2DView_;

        // No painter scale any more: the stretch is in the column table (stretch()).
        painterStretch_ = 1.0;
        if (flipImage) {
            painter->translate(0, height);
            painter->scale(1.0, -1.0);
        }
        canvas_.setSize(width, height, painter);

    }
    else {

        painterStretch_ = 1.0;
        canvas_.setSize(height, width, painter);


        painter->rotate(-90);
        painter->translate(-height, 0);
    }

    if (echogramPause_ && !echogramDragActive_)
        return true;

    reindexingCursor();
    reRangeDistance();

    return true;

}


QString Plot2D::stretchReport() const
{
    const int W = int(cursor_.indexes.size());
    if (W <= 0 || canvas_.width() != W)
        return QString();

    // The canvas columns that land on screen. The painter scale is right-anchored at the
    // canvas' right edge, so with a scale p only the right-hand W/p columns are visible.
    const double p  = std::max(1.0, painterStretch_);
    const int    x0 = std::clamp(int(std::ceil(double(W) - double(W) / p)), 0, W - 1);

    int first = -1, last = -1;
    for (int x = x0; x < W; ++x) {
        const int e = cursor_.indexes[x];
        if (e < 0) continue;
        if (first < 0) first = e;
        last = e;
    }
    if (first < 0 || last <= first)
        return QString();

    const int    epochs  = last - first + 1;
    // Over the columns that HOLD data: while the screen is still filling, W / epochs would
    // count the empty columns too (the 30 Sept device log read 92 px per epoch at 2.98).
    const int    dataCols = std::max(1, W - x0 - cursor_.numZeroEpoch);
    const double pxEpoch  = double(dataCols) / double(epochs);
    return QStringLiteral("%1 | setting %2 | painter %3 | mapping %4 | canvas %5 | on screen %6..%7 = %8 epochs | %9 px per epoch%10")
        .arg(isHorizontal_ ? (isDownScanPane() ? QStringLiteral("horizontal down scan") : QStringLiteral("horizontal"))
                           : QStringLiteral("vertical"))
        .arg(isDownScanPane() ? downScanSpeed_ : echogramSpeed_, 0, 'f', 2)
        .arg(painterStretch_, 0, 'f', 2)
        .arg(stretch(), 0, 'f', 2)
        .arg(W).arg(first).arg(last).arg(epochs)
        .arg(pxEpoch, 0, 'f', 1)
        .arg(cursor_.numZeroEpoch > 0 ? QStringLiteral(" (screen not full)") : QString())
        + (isTrueProportionsPane()
           ? QStringLiteral(" | TRUE %1 m/s x %2 ms, across %3 px over %4 m -> wants %5, shortened 1 : %6")
                 .arg(boatSpeedMps_, 0, 'f', 2).arg(truePingPeriodMs_, 0, 'f', 0)
                 .arg(canvas_.height())
                 .arg(std::abs(double(cursor_.distance.to) - double(cursor_.distance.from)), 0, 'f', 1)
                 .arg(trueStretchWanted(), 0, 'f', 2).arg(trueShortenedBy(), 0, 'f', 1)
           : QString());
}

void Plot2D::setDragActive(bool active)
{
    qDebug () << "AddWaypoint: Plot2D::setDragActive set to" << active;
    echogramDragActive_ = active;
}

void Plot2D::setHoldHistory(bool hold)
{
    echogramHoldHistory_ = hold;
}


void Plot2D::draw(QPainter *painterPtr)
{
    //    painter->setCompositionMode(QPainter::RasterOp_SourceXorDestination);
    echogram_.draw(this, datasetPtr_);
    attitude_.draw(this, datasetPtr_);
    encoder_.draw(this, datasetPtr_);
    dvlBeamVelocity_.draw(this, datasetPtr_);
    dvlSolution_.draw(this, datasetPtr_);

    usblSolution_.draw(this, datasetPtr_);
    bottomProcessing_.draw(this, datasetPtr_);
    rangefinder_.draw(this, datasetPtr_);
    depth_.draw(this, datasetPtr_);
    gnss_.draw(this, datasetPtr_);
    quadrature_.draw(this, datasetPtr_);

    //painterPtr->setCompositionMode(QPainter::CompositionMode_Exclusion);
    grid_.draw(this, datasetPtr_);
    painterPtr->setCompositionMode(QPainter::CompositionMode_SourceOver);

    if (dvlLegendVisible_) {
        const bool beamShow = dvlBeamVelocity_.isVisible() && dvlBeamVelocity_.hasData();
        const bool solShow  = dvlSolution_.isVisible()     && dvlSolution_.hasData();
        if (beamShow || solShow) {
            constexpr int rowH = 22, headerH = 25, padV = 12, margin = 8;
            const int beamH  = beamShow ? padV + headerH + dvlBeamVelocity_.countLegendItems() * rowH : 0;
            const int solH   = solShow  ? padV + headerH + dvlSolution_.countLegendItems()     * rowH : 0;
            const int totalH = beamH + (beamH > 0 && solH > 0 ? 4 : 0) + solH;

            const int gridTextX = grid_.lastRightTextX();
            const int rightLimit = (grid_.isVisible() && !grid_.isInvert() && gridTextX < canvas_.width())
                ? gridTextX - margin
                : canvas_.width() - margin;
            const int bw  = beamShow ? dvlBeamVelocity_.boxWidth(canvas_) : 0;
            const int sw  = solShow  ? dvlSolution_.boxWidth(canvas_)     : 0;
            const int lx  = rightLimit - qMax(bw, sw);

            const int startY = (dvlLegendPosIndex_ == 0) ? margin
                : (dvlLegendPosIndex_ == 1) ? canvas_.height() / 2 - totalH / 2
                : canvas_.height() - totalH - 55;

            int y = startY;
            y = dvlBeamVelocity_.drawLegend(canvas_, lx, y);
            dvlSolution_.drawLegend(canvas_, lx, y);
        }
    }

    aim_.draw(this, datasetPtr_);
    contacts_.draw(this, datasetPtr_);
}

bool Plot2D::drawEchogramZoomPreview(QPainter* painter, const QRect& targetRect, const QPoint& sourceCenter, int sourceSize, QPointF* focusPoint)
{
    return drawEchogramZoomPreview(painter, targetRect, sourceCenter, sourceSize, sourceSize, focusPoint);
}

bool Plot2D::drawEchogramZoomPreview(QPainter* painter, const QRect& targetRect, const QPoint& sourceCenter, int sourceWidth, int sourceHeight, QPointF* focusPoint)
{
    return echogram_.drawZoomPreview(this, datasetPtr_, painter, targetRect, sourceCenter, sourceWidth, sourceHeight, focusPoint);
}

bool Plot2D::isHorizontal()
{
    return isHorizontal_;
}

void Plot2D::setHorizontal(bool is_horizontal)
{
    isHorizontal_ = is_horizontal;
    contacts_.setIsHorizontal(isHorizontal_);
}

void Plot2D::setAimEpochEventState(bool state)
{
    aim_.setEpochEventState(state);
}

void Plot2D::setTimelinePosition(float position)
{
    if (position > 1.0f) {
        position = 1.0f;
    }
    if (position < 0) {
        position = 0;
    }

    if (echogramPause_ && !echogramDragActive_)
        return;

    if (cursor_.position != position) {
        cursor_.position = position;
        plotUpdate();
    }
}

void Plot2D::resetAim()
{
    cursor_.selectEpochIndx = -1;
}

void Plot2D::setTimelinePositionSec(float position)
{
    if (position > 1.0f) {
        position = 1.0f;
    }
    if (position < 0) {
        position = 0;
    }


    if (echogramPause_ && !echogramDragActive_)
        return;


    cursor_.position = position;
    plotUpdate();
}

void Plot2D::setTimelinePositionByEpoch(int epochIndx)
{
    if (echogramPause_)
        return;

    if (!datasetPtr_ || datasetPtr_->size() <= 0) {
        cursor_.selectEpochIndx = -1;
        return;
    }

    const int halfWindow = static_cast<int>(cursor_.indexes.size() / 2);
    float pos = epochIndx == -1
        ? cursor_.position
        : static_cast<float>(epochIndx + halfWindow) / static_cast<float>(datasetPtr_->size());
    cursor_.selectEpochIndx = epochIndx;
    setTimelinePositionSec(pos);
}

void Plot2D::setSyncCursor(int epoch, float depth, int channel)
{
    syncDepthValid_ = true;
    syncDepth_ = depth;       // absolute physical depth (>=0)
    syncChannel_ = channel;   // 1/2 — used to pick the half on a dual-channel slave
    setAimEpochEventState(true);
    setTimelinePositionByEpoch(epoch);

    // AND REPAINT, WHICH IS THE WHOLE FIX. Olav, 16 Sept, on a split: "The upper (or lower)
    // screen does not clear its old when I touch the other screen. Same now in tablet, not a
    // phone problem." Two crosshairs and two zoom boxes, and nothing about the sync was wrong.
    //
    // syncDepthValid_ above is what makes this pane's aim FOREIGN, and Plot2DAim::draw
    // already refuses a foreign aim both halves of its output - no crosshair, and cand_
    // cleared so no panel. The flag was set correctly every time. The pane simply never drew
    // again, so the guard never ran and the pixels from the user's previous touch stayed on
    // screen.
    //
    // THE ONLY REPAINT IN THIS FUNCTION'S CHAIN WAS INSIDE A CALL THAT RETURNS EARLY WHEN
    // PAUSED. setTimelinePositionByEpoch() opens with `if (echogramPause_) return;`, and
    // setTimelinePositionSec() - which holds the plotUpdate() - opens with the same test.
    // The loupe exists ONLY while paused: Plot2D.qml raises an aim on press exclusively
    // under pulseRuntimeSettings.echogramPause. So the one state in which this repaint is
    // needed is the one state in which it could not happen, and a running echogram redraws
    // within a frame anyway - which is why this was invisible until a split was paused.
    //
    // clearSyncCursor() HAS ALWAYS ENDED WITH plotUpdate(). The asymmetry between the two
    // was the bug: clearing a foreign aim repainted, setting one did not.
    //
    // NOT cursor_.setMouse(-1, -1) HERE, deliberately. What this pane may DRAW is already
    // answered by aimIsForeign(); the cursor still carries the epoch and depth the sync is
    // for, and a per-pane readout or a correlation marker wants exactly that. This commit
    // makes the pane redraw, and changes nothing about what it knows.
    plotUpdate();
}

void Plot2D::clearSyncCursor()
{
    syncDepthValid_ = false;
    setAimEpochEventState(false);
    cursor_.selectEpochIndx = -1;
    cursor_.setMouse(-1, -1);
    plotUpdate();
}

void Plot2D::scrollPosition(int columns)
{
    if (!datasetPtr_ || datasetPtr_->size() <= 0) {
        return;
    }

    float new_position = timelinePosition() + (1.0f / datasetPtr_->size()) * columns;
    setTimelinePosition(new_position);
}

void Plot2D::setDataChannel(bool fromGui, const ChannelId& channel, uint8_t subChannel1, const QString& portName1, const ChannelId& channel2, uint8_t subChannel2, const QString& portName2)
{
    cursor_.channel1 = channel;
    cursor_.subChannel1 = subChannel1;
    cursor_.firstChannelPortName = fromGui ? portName1 : QString("%1|%2|%3").arg(portName1, QString::number(channel.address), QString::number(subChannel1));
    cursor_.channel2 = channel2;
    cursor_.subChannel2 = subChannel2;
    cursor_.secondChannelPortName = fromGui ? portName2 : QString("%1|%2|%3").arg(portName2, QString::number(channel2.address), QString::number(subChannel2));

    float from = NAN, to = NAN;

    if (datasetPtr_) {
        datasetPtr_->getMaxDistanceRange(&from, &to, channel, subChannel1, channel2, subChannel2);

        if (isfinite(from) && isfinite(to) && (to - from) > 0) {
            cursor_.distance.set(from, to);
            conformDownRange("the channels were set");
        }
    }

    resetCash();
    //plotUpdate(); // TODO: this calls from ctr
}

bool Plot2D::getIsContactChanged()
{
    return contacts_.isChanged();
}

QString Plot2D::getContactInfo()
{
    return contacts_.getInfo();
}

void Plot2D::setContactInfo(const QString& str)
{
    contacts_.setInfo(str);
}

bool Plot2D::getContactVisible()
{
    return contacts_.getVisible();
}

void Plot2D::setContactVisible(bool state)
{
    contacts_.setVisible(state);
}

int Plot2D::getContactPositionX()
{
    return contacts_.getPosition().x();
}

int Plot2D::getContactPositionY()
{
    return contacts_.getPosition().y();
}

int Plot2D::getContactIndx()
{
    return contacts_.getIndx();
}

double Plot2D::getContactLat()
{
    return contacts_.getLat();
}

double Plot2D::getContactLon()
{
    return contacts_.getLon();
}

double Plot2D::getContactDepth()
{
    return contacts_.getDepth();
}

bool Plot2D::getContactIsActive()
{
    return contacts_.getIsActive();
}

float Plot2D::getEchogramLowLevel() const
{
    return echogram_.getLowLevel();
}

float Plot2D::getEchogramHighLevel() const
{
    return echogram_.getHighLevel();
}

int Plot2D::getThemeId() const
{
    return echogram_.getThemeId();
}

int Plot2D::getEchogramCompensation() const
{
    return echogram_.getCompensation();
}

void Plot2D::setEchogramLowLevel(float low) {
    //qDebug() << "setEchogramLowLevel to value " << low;
    echogram_.setLowLevel(low);
    plotUpdate();
}

void Plot2D::setEchogramHightLevel(float high) {
    //qDebug() << "setEchogramHightLevel to value " << high;
    echogram_.setHightLevel(high);
    plotUpdate();
}

void Plot2D::setEchogramVisible(bool visible) {
    echogram_.setVisible(visible);
    echogram_.resetCash();
    plotUpdate();
}

void Plot2D::setEchogramTheme(int theme_id) {
    echogram_.setThemeId(theme_id);
    plotUpdate();
}

void Plot2D::setEchogramCompensation(int compensation_id) {
    echogram_.setCompensation(compensation_id);
    echogram_.resetCash();
    plotUpdate();
}

void Plot2D::setBottomTrackVisible(bool visible) {
    bottomProcessing_.setVisible(visible);
    plotUpdate();
}

void Plot2D::setBottomTrackTheme(int theme_id) {
    bottomProcessing_.setTheme(theme_id);
    plotUpdate();
}

bool Plot2D::getBottomTrackVisible() const
{
    return bottomProcessing_.isVisible();
}

int Plot2D::getBottomTrackTheme() const
{
    return bottomProcessing_.getThemeId();
}

void Plot2D::setBottomTrackDepthTextVisible(bool visible)
{
    //bottomProcessing_.setDepthTextVisible(visible);
    bottomProcessing_.setDepthTextVisible(false); //We do not want this for pulse
    plotUpdate();
}

void Plot2D::setRangefinderVisible(bool visible) {
    // Honour the request so the expert "Show visible rangefinder track" toggle can paint the
    // rangefinder LINE. The value TEXT stays permanently off (see setRangefinderDepthTextVisible).
    // Default is off (constructors set false) and nothing enables it at load.
    rangefinder_.setVisible(visible);
    plotUpdate();
}

void Plot2D::setRangefinderTheme(int theme_id) {
    rangefinder_.setTheme(theme_id);
    plotUpdate();
}

bool Plot2D::getRangefinderVisible() const
{
    return rangefinder_.isVisible();
}

int Plot2D::getRangefinderTheme() const
{
    return rangefinder_.getThemeId();
}

void Plot2D::setRangefinderDepthTextVisible(bool visible)
{
    Q_UNUSED(visible);
    rangefinder_.setDepthTextVisible(false); //We do not want this for pulse
    plotUpdate();
}

void Plot2D::setAttitudeVisible(bool visible) {
    attitude_.setVisible(visible);
    plotUpdate();
}

void Plot2D::setTemperatureVisible(bool visible) {
    temperature_.setVisible(visible);
    plotUpdate();
}

bool Plot2D::hasTemperatureValue() const
{
    if (!datasetPtr_ || !temperature_.isVisible()) {
        return false;
    }

    float temp = datasetPtr_->getLastTemp();
    if (std::isfinite(temp)) {
        return true;
    }

    Epoch* lastEpoch = datasetPtr_->last();
    Epoch* preLastEpoch = datasetPtr_->lastlast();

    if (lastEpoch && lastEpoch->temperatureAvail()) {
        return true;
    }
    if (preLastEpoch && preLastEpoch->temperatureAvail()) {
        return true;
    }

    return false;
}

bool Plot2D::hasRangefinderDepthTextValue() const
{
    if (!datasetPtr_ || !rangefinder_.isVisible() || !rangefinder_.isDepthTextVisible()) {
        return false;
    }

    return std::isfinite(datasetPtr_->getLastRangefinderDepth());
}

void Plot2D::setDopplerBeamVisible(bool visible, int beam_filter) {
    dvlBeamVelocity_.setVisible(visible);
    dvlBeamVelocity_.setBeamFilter(beam_filter);
    plotUpdate();
}

void Plot2D::setDopplerInstrumentVisible(bool visible, int line_filter) {
    dvlSolution_.setVisible(visible);
    if (line_filter >= 0)
        dvlSolution_.setLineFilter(line_filter);
    plotUpdate();
}

void Plot2D::setDVLLegendVisible(bool visible) {
    dvlLegendVisible_ = visible;
    plotUpdate();
}

void Plot2D::setDVLLegendPosition(int pos) {
    dvlLegendPosIndex_ = pos;
    plotUpdate();
}

void Plot2D::setGNSSVisible(bool visible, int flags) {
    Q_UNUSED(flags);

    gnss_.setVisible(visible);
    plotUpdate();
}

void Plot2D::setAcousticAngleVisible(bool visible) {
    usblSolution_.setVisible(visible);
    plotUpdate();
}

void Plot2D::setGridVetricalNumber(int grids) {
    grid_.setVisible(grids > 0);
    grid_.setVetricalNumber(grids);
    plotUpdate();
}

void Plot2D::setGridFillWidth(bool state)
{
    grid_.setFillWidth(state);
    plotUpdate();
}

void Plot2D::setGridInvert(bool state)
{
    grid_.setInvert(state);
    plotUpdate();
}

void Plot2D::setAngleVisibility(bool state)
{
    grid_.setAngleVisibility(state);
    plotUpdate();
}

void Plot2D::setAngleRange(int angleRange)
{
    cursor_.attitude.from = static_cast<float>(-angleRange);
    cursor_.attitude.to = static_cast<float>(angleRange);
    plotUpdate();
}

void Plot2D::setVelocityVisible(bool visible) {
    grid_.setVelocityVisible(visible);
    plotUpdate();
}

void Plot2D::setVelocityRange(float velocity) {
    cursor_.velocity.from = -velocity;
    cursor_.velocity.to = velocity;
    plotUpdate();
}

void Plot2D::setDistanceAutoRange(int auto_range_type) {
    cursor_.distance.mode = AutoRangeMode(auto_range_type);
}

void Plot2D::setDistance(float from, float to) {
    //Pulse
    if (isSideScanLeftHand_ && isSideScan2DView_) {
        cursor_.distance.set(-1*to, from);
    } else {
        cursor_.distance.set(from, to);
    }
    conformDownRange("the range was set");

    //cursor_.distance.set(from, to);
}

void Plot2D::zoomDistance(float ratio)
{
    //qDebug() << "Plot2D::zoomDistance with ratio" << ratio;
    cursor_.distance.mode = AutoRangeNone;

    const float delta = ratio;
    if (qFuzzyIsNull(delta)) {
        return;
    }

    float from = cursor_.distance.from;
    float to = cursor_.distance.to;
    float absrange = std::abs(to - from);

    constexpr float kWheelStep = 120.0f;
    constexpr float kMinZoomPerStep = 1.03f;
    constexpr float kMaxZoomPerStep = 1.15f;
    const float rangeNorm = qBound(0.0f,
                                   std::log10(qMax(absrange, 1.0f)) / std::log10(500.0f),
                                   1.0f);
    const float zoomPerStep = kMinZoomPerStep + (kMaxZoomPerStep - kMinZoomPerStep) * rangeNorm;
    const float steps = delta / kWheelStep;
    float new_range = absrange * std::pow(zoomPerStep, steps);

    if(new_range < 1) {
        new_range = 1;
    }

    //Pulse
    int maximumTransducerRange = maximumDepth_;
    if (cursor_.isChannelDoubled() && !isHorizontal()) {
        maximumTransducerRange = 2 * maximumTransducerRange;
        if (new_range < 20) {
            new_range = 20;
        }
    }
    if (new_range > maximumTransducerRange)
        new_range = maximumTransducerRange;

    if (cursor_.isChannelDoubled()) {
        //Pulse
        if (isHorizontal()) {
            if (isSideScanLeftHand_) {
                cursor_.distance.from = 0;
                cursor_.distance.to = -ceil(cursor_.distance.from + new_range);
                qDebug() << "zoomDistance leftHand: delta" << delta << "absrange" << absrange << "new_range" << new_range << "cursor_.distance.to" << cursor_.distance.to;
                //cursor_.distance.to = 0;
                //cursor_.distance.from = ceil(cursor_.distance.to + new_range);
            } else {
                cursor_.distance.from = 0;
                cursor_.distance.to = ceil(cursor_.distance.from + new_range);
                qDebug() << "zoomDistance rightHand: delta" << delta << "absrange" << absrange << "new_range" << new_range << "cursor_.distance.to" << cursor_.distance.to;
            }

        } else {
            // Pulse: direction-aware rounding so zoom-in actually shrinks the dual-channel range.
            // Using ceil() in both directions made a small per-frame decrease (e.g. 32 -> 31.83)
            // round back up to the same integer, so the range was re-derived identically every
            // frame and zoom-in never reduced the depth. Grow (delta > 0) rounds up as before;
            // shrink (delta < 0) rounds down so the integer range can decrease.
            const float half = (delta > 0.0f) ? ceil( new_range/2)
                                              : floor( new_range/2);
            cursor_.distance.from = -half;
            cursor_.distance.to = half;
            qDebug() << "zoomDistance dualChannel: delta" << delta << "absrange" << absrange << "new_range" << new_range << "cursor_.distance.to" << cursor_.distance.to;
        }

    }
    else {
       cursor_.distance.to = cursor_.distance.from + new_range;
    }

    conformDownRange("the range was zoomed");
    plotUpdate();
}

// THE DOWN PANE'S RANGE AND ITS FLIP ARE TWO HALVES OF ONE FACT (29 Sept, Olav: "ONE
// occurrence of the down scan painted upside down, water surface at the bottom").
//
// With the side scan mounted left-handed (isSideScanOnLeftHandSide defaults to TRUE) the down
// view is drawn from the negative half: setDistance writes 0..R as -R..0, and getImage()
// flips the picture vertically on isSideScanLeftHand_ && isSideScan2DView_. The two must
// agree. They were decided at DIFFERENT MOMENTS: the range when it is set, the flip at every
// paint from whatever the two flags say by then. So a range set while the pane was not yet a
// down pane (applyMaxRange runs before the 10 ms orientation timer, and setGridMode("down")
// can land after the range) stays 0..R and is then flipped - upside down. And zoomDistance's
// left-hand branch writes 0 .. -R, the mirror of -R..0, which is upside down under the flip
// by construction.
//
// So the range is conformed, not trusted: any two-channel range that does not cross zero (a
// side scan range does, and is never touched; a one-channel 2D picture is never touched) is
// rewritten into the form the CURRENT flags want - -hi .. -lo when flipped, lo .. hi
// when not - whenever the range is written and whenever either flag changes. The flip stays
// where it is; only the half the range points at follows it.
void Plot2D::conformDownRange(const char* why)
{
    const float a = cursor_.distance.from;
    const float b = cursor_.distance.to;
    if (!std::isfinite(a) || !std::isfinite(b))
        return;
    if ((a < 0.0f && b > 0.0f) || (a > 0.0f && b < 0.0f))
        return;                                   // crosses zero: a side scan range
    if (!cursor_.isChannelDoubled())
        return;                                   // one channel: a 2D picture, never a down view
    const float lo = std::min(std::fabs(a), std::fabs(b));
    const float hi = std::max(std::fabs(a), std::fabs(b));
    if (hi <= 0.0f)
        return;
    const bool flipped = isSideScanLeftHand_ && isSideScan2DView_;
    const float nf = flipped ? -hi : lo;
    const float nt = flipped ? -lo : hi;
    if (nf == a && nt == b)
        return;
    qDebug().noquote() << QStringLiteral("RANGE: down range conformed %1 .. %2 -> %3 .. %4 | left hand %5, down view %6 | %7")
                              .arg(a).arg(b).arg(nf).arg(nt)
                              .arg(isSideScanLeftHand_ ? "true" : "false")
                              .arg(isSideScan2DView_ ? "true" : "false")
                              .arg(QString::fromLatin1(why));
    cursor_.distance.from = nf;
    cursor_.distance.to = nt;
}

void Plot2D::scrollDistance(float ratio)
{
    cursor_.distance.mode = AutoRangeNone;

    float from = cursor_.distance.from;
    float to = cursor_.distance.to;
    float absrange = abs(to - from);

    float delta_offset = ((float)absrange*(float)ratio*0.001f);

    if(from < to) {
        float round_cef = 10.0f;

        float from_n = (round((from + delta_offset)*round_cef)/round_cef);
        float to_n = (round((to + delta_offset)*round_cef)/round_cef);

        if(!cursor_.isChannelDoubled()) {
            if(from_n < 0) {
                to_n -= from_n;
                from_n = 0;
            }
        }

        cursor_.distance.from = from_n;
        cursor_.distance.to = to_n;

    } else if(from > to) {
        cursor_.distance.from = (from - delta_offset);
        cursor_.distance.to = (to - delta_offset);
    }

    plotUpdate();
}

void Plot2D::setMousePosition(int x, int y, bool isSync) {
    syncDepthValid_ = false;
    // A real aim, and whether it is this pane's own. Cleared by the x == -1 reset for free,
    // because a cleared aim belongs to nobody.
    aimIsMirrored_ = (x >= 0) && isSync;
    if (!datasetPtr_ || canvas_.width() <= 0 || canvas_.height() <= 0) {
        cursor_.selectEpochIndx = -1;
        cursor_.currentEpochIndx = -1;
        cursor_.lastEpochIndx = -1;
        cursor_.setMouse(-1, -1);
        cursor_.setContactPos(-1, -1);
        plotUpdate();
        return;
    }

    const int image_width = canvas_.width();
    const int image_height = canvas_.height();
    const int dataset_from = cursor_.getIndex(0);
    Q_UNUSED(dataset_from);

    const float distance_from = cursor_.distance.from;
    const float distance_range = cursor_.distance.to - cursor_.distance.from;
    const float image_distance_ratio = distance_range/(float)image_height;

    struct {
        int x = -1, y = -1;
    } _mouse;

    _mouse.x = cursor_.mouseX;
    _mouse.y = cursor_.mouseY;
    cursor_.setMouse(x, y);


    if(x < -1) { x = -1; }
    if(x >= image_width) { x = image_width - 1; }

    if(y < 0) { y = 0; }
    if(y >= image_height) { x = image_height - 1; }

    if(x == -1) {
        _mouse.x = -1;
        cursor_.selectEpochIndx = -1;
        cursor_.currentEpochIndx = -1;
        //_cursor.lastEpochIndx = -1; // ?
        // AN ECHO MUST NOT ECHO. syncClearAim() broadcasts a clear to every OTHER plot,
        // which is right when a user clears their own aim and catastrophic when the clear
        // IS the sync: main.qml's handlePlotReleased resets the MIRRORED pane on finger-up,
        // that reset lands here with x == -1, and the broadcast then wipes the aim on the
        // pane the user actually touched. The loupe vanished on release in a split and
        // never in a single pane, because in a single pane handlePlotReleased does nothing
        // at all and so nothing broadcasts. Olav, 16 Sept: "Only when dual screen. Never in
        // single screen, then it works as it should."
        //
        // isSync is already threaded through setMousePosition for exactly this distinction
        // and this branch had never consulted it. Every existing caller passes false, so
        // they are unchanged by construction; only the mirrored reset passes true.
        if (!isSync)
            syncClearAim();
        plotUpdate();
        return;
    }

    int x_start = 0, y_start = 0;
    int x_length = 0;
    float y_scale = 0.0f;
    if(_mouse.x != -1) {
        if(_mouse.x < x) {
            x_length = x - _mouse.x;
            x_start = _mouse.x;
            y_start = _mouse.y;
            y_scale = (float)(y - _mouse.y)/(float)x_length;
        } else if(_mouse.x > x) {
            x_length = _mouse.x - x;
            x_start = x;
            y_start = y;
            y_scale = -(float)(y - _mouse.y)/(float)x_length;
        } else {
            x_length = 1;
            x_start = x;
            y_start = y;
            y_scale = 0;
        }
    } else {
        x_length = 1;
        x_start = x;
        y_start = y;
        y_scale = 0;
    }

//    _mouse.x = x;
//    _mouse.y = y;

    int epoch_index = cursor_.getIndex(x);
    cursor_.currentEpochIndx = epoch_index;
    cursor_.lastEpochIndx = cursor_.currentEpochIndx;
    sendSyncEvent(epoch_index, EpochSelected2d);

    // AN AIM ON NO EPOCH STILL TAKES THE AIM FROM THE OTHER PANES (29 Sept). Olav, split
    // side + down, paused: a drag from the side scan into the down pane's still-empty
    // (black) columns gave TWO zoom boxes, and the side scan's went away only once the
    // finger reached filled columns. The only thing that retires another pane's aim is
    // qPlot2D::sendSyncEvent's broadcastEpochCursor, and that returns early without an
    // epoch - so over empty columns nothing told the side scan pane the aim had moved.
    // A clear is the honest message: there is no epoch to point the other panes at.
    // NOT FOR A SYNC ECHO - the same rule as the x == -1 branch above: a mirrored pane
    // landing on empty columns must not wipe the aim on the pane the user is touching.
    if (epoch_index < 0 && !isSync)
        syncClearAim();

    if(cursor_.tool() > MouseToolNothing && !isSync) {

        for(int x_ind = 0; x_ind < x_length; x_ind++) {
            int epoch_index = cursor_.getIndex(x_start + x_ind);

            Epoch* epoch = datasetPtr_->fromIndex(epoch_index);

            const ChannelId channel1 = cursor_.channel1;
            const ChannelId channel2 = cursor_.channel2;

            if(epoch != nullptr) {
                float image_y_pos = ((float)y_start + (float)x_ind*y_scale);
                float dist = abs(image_y_pos*image_distance_ratio + distance_from);

                if(cursor_.tool() == MouseToolDistanceMin) {
                    epoch->setMinDistProc(channel1, dist);
                    epoch->setMinDistProc(channel2, dist);
                } else if(cursor_.tool() == MouseToolDistance) {
                    epoch->setDistProcessing(channel1, dist);
                    epoch->setDistProcessing(channel2, dist);
                } else if(cursor_.tool()== MouseToolDistanceMax) {
                    epoch->setMaxDistProc(channel1, dist);
                    epoch->setMaxDistProc(channel2, dist);
                } else if(cursor_.tool() == MouseToolDistanceErase) {
                    epoch->clearDistProcessing(channel1);
                    epoch->clearDistProcessing(channel2);
                }
            }
        }

        if (cursor_.tool() == MouseToolDistanceMin || cursor_.tool() == MouseToolDistanceMax) {
            if (auto btp = datasetPtr_->getBottomTrackParamPtr(); btp) {
                btp->indexFrom = cursor_.getIndex(x_start);
                btp->indexTo = cursor_.getIndex(x_start + x_length);
                QMetaObject::invokeMethod(dataProcessorPtr_, "bottomTrackProcessing", Qt::QueuedConnection,
                                          Q_ARG(DatasetChannel, DatasetChannel(cursor_.channel1, cursor_.subChannel1)),
                                          Q_ARG(DatasetChannel, DatasetChannel(cursor_.channel2, cursor_.subChannel2)),
                                          Q_ARG(BottomTrackParam, *btp),
                                          Q_ARG(bool, true),/*manual*/
                                          Q_ARG(bool, false)/*redraw all*/);
            }
        }

        if (cursor_.tool() == MouseToolDistance || cursor_.tool() == MouseToolDistanceErase) {
            emit datasetPtr_->dataUpdate(); // refresh all 2D echograms (other panes)
            emit datasetPtr_->bottomTrackUpdated(cursor_.channel1, cursor_.getIndex(x_start), cursor_.getIndex(x_start + x_length), true, false);
        }
    }

    plotUpdate();
}

void Plot2D::simpleSetMousePosition(int x, int y)
{
    if (!datasetPtr_ || canvas_.width() <= 0 || canvas_.height() <= 0) {
        cursor_.currentEpochIndx = -1;
        cursor_.lastEpochIndx = -1;
        return;
    }

    const int image_width = canvas_.width();
    const int image_height = canvas_.height();
    //int mouseX = -1;
    int mouseX = cursor_.mouseX;

    if (x < -1) {
        x = -1;
    }
    if (x >= image_width) {
        x = image_width - 1;
    }
    if (y < 0) {
        y = 0;
    }
    if (y >= image_height) {
        x = image_height - 1;
    }

    if (x == -1) {
        //_cursor.selectEpochIndx = -1;
        cursor_.setMouse(-1, -1); //TODO: VERIFY if OK!!!
        cursor_.currentEpochIndx = -1;
        //_cursor.lastEpochIndx = -1; // ?
        return;
    }

    //TODO: Verify if OK
    cursor_.setMouse(x, y);

    cursor_.setContactPos(x, y);

    int x_start = x;
    if (mouseX != -1 && mouseX < x) {
        x_start = mouseX;
    }

    cursor_.currentEpochIndx = cursor_.getIndex(x_start);
    cursor_.lastEpochIndx = cursor_.currentEpochIndx;

    //sendSyncEvent(epoch_index);
    //plotUpdate();
}

void Plot2D::setMouseTool(MouseTool tool) {
    cursor_.setTool(tool);
}

bool Plot2D::setContact(int indx, const QString& text)
{
    if (!datasetPtr_) {
        qDebug() << "Plot2D::setContact returned: !_dataset";
        return false;
    }

    if (text.isEmpty()) {
        qDebug() << "Plot2D::setContact returned: text.isEmpty()";
        return false;
    }

    bool primary = indx == -1;
    int currIndx = primary ? cursor_.lastEpochIndx : indx;

    //qDebug() << "indx" << indx << "currIndx" << currIndx << text;

    auto* ep = datasetPtr_->fromIndex(currIndx);
    if (!ep) {
        qDebug() << "Plot2D::setContact returned: !ep";
        return false;
    }

    ep->contact_.info = text;

    if (primary) {
        ep->contact_.cursorX = cursor_.contactX;
        ep->contact_.cursorY = cursor_.contactY;

        const float canvas_height = canvas_.height();
        float value_range = cursor_.distance.to - cursor_.distance.from;
        float value_scale = float(cursor_.contactY) / canvas_height;
        float cursor_distance = value_scale * value_range + cursor_.distance.from;

        const auto [channelId, subIndx, name] = getSelectedChannelId(cursor_distance); // *
        const float bottomTrack = ep->distProccesing(channelId);
        const auto  sonarNed         = ep->getSonarPosition().ned;
        const auto  sonarLla         = ep->getSonarPosition().lla;
        const auto  epochPos         = ep->getPositionGNSS();

        ep->contact_.nedX             = std::isfinite(sonarNed.n) ? sonarNed.n : epochPos.ned.n;
        ep->contact_.nedY             = std::isfinite(sonarNed.e) ? sonarNed.e : epochPos.ned.e;
        ep->contact_.lat              = std::isfinite(sonarLla.latitude)  ? sonarLla.latitude  : epochPos.lla.latitude;
        ep->contact_.lon              = std::isfinite(sonarLla.longitude) ? sonarLla.longitude : epochPos.lla.longitude;
        ep->contact_.echogramDistance = cursor_distance;

        if (!cursor_.isChannelDoubled()) { // basic
            ep->contact_.depth            = cursor_distance;
        }
        else { // side scan
            if (!std::isfinite(bottomTrack)) {
                ep->contact_.depth            = 0;
            }
            else  if (std::fabs(cursor_distance) < std::fabs(bottomTrack)) {
                ep->contact_.depth            = bottomTrack;
            }
            else {
                const float  calcRange        = std::sqrt(std::max(0.0, std::pow(cursor_distance, 2) - std::pow(bottomTrack, 2)));
                const bool   goRight          = cursor_distance > 0; // *
                const float  lAngleOffsetDeg  = lAngleOffsetDeg_;
                const float  rAngleOffsetDeg  = rAngleOffsetDeg_;
                const double yawRad           = qDegreesToRadians(ep->yaw());
                const double leftAzRad        = yawRad - M_PI_2 + qDegreesToRadians(lAngleOffsetDeg);
                const double rightAzRad       = yawRad + M_PI_2 - qDegreesToRadians(rAngleOffsetDeg);
                const double beamAz           = goRight ? rightAzRad : leftAzRad;
                const double dN               = calcRange * std::cos(beamAz);
                const double dE               = calcRange * std::sin(beamAz);
                const double R                = 6378137.0;
                const double lat0_deg         = sonarLla.latitude;
                const double lon0_deg         = sonarLla.longitude;
                const double lat0_rad         = qDegreesToRadians(lat0_deg);
                const double dLat_deg         = (dN / R) * (180.0 / M_PI);
                const double dLon_deg         = (dE / (R * std::cos(lat0_rad))) * (180.0 / M_PI);

                ep->contact_.nedX             = sonarNed.n + dN;
                ep->contact_.nedY             = sonarNed.e + dE;
                ep->contact_.echogramDistance = cursor_distance;
                ep->contact_.depth            = bottomTrack;
                ep->contact_.lat              = lat0_deg + dLat_deg;
                ep->contact_.lon              = lon0_deg + dLon_deg;
            }
        }
    }
    else {
        // update rect
    }

    sendSyncEvent(currIndx, ContactCreated);

    plotUpdate();

    return true;
}

bool Plot2D::setActiveContact(int indx)
{
    if (!datasetPtr_) {
        qDebug() << "Plot2D::setActiveContact returned: !_dataset";
        return false;
    }

    auto* ep = datasetPtr_->fromIndex(indx);
    if (!ep) {
        qDebug() << "Plot2D::setActiveContact returned: !ep";
        return false;
    }

    auto currActiveIndx = datasetPtr_->getActiveContactIndx();
    if (currActiveIndx == indx) {
        datasetPtr_->setActiveContactIndx(-1);
        sendSyncEvent(-1, ContactActiveChanged);
    }
    else {
        datasetPtr_->setActiveContactIndx(indx);
        sendSyncEvent(indx, ContactActiveChanged);
    }

    plotUpdate();
    return true;
}

bool Plot2D::deleteContact(int indx)
{
    if (!datasetPtr_) {
        qDebug() << "Plot2D::deleteContact returned: !_dataset";
        return false;
    }

    //qDebug() << "indx" << indx << "currIndx" << currIndx << text;

    auto* ep = datasetPtr_->fromIndex(indx);
    if (!ep) {
        qDebug() << "Plot2D::deleteContact returned: !ep";
        return false;
    }

    ep->contact_.clear();

    if (datasetPtr_->getActiveContactIndx() == indx) {
        datasetPtr_->setActiveContactIndx(-1);
    }

    sendSyncEvent(indx, ContactDeleted);

    plotUpdate();

    return true;
}

void Plot2D::updateContact()
{
    contacts_.setMousePos(-1,-1);
    plotUpdate();
}

void Plot2D::onCursorMoved(int x, int y)
{
    if (isEchogramPaused() && isTapInsideZoom(x, y)) {
        return;
    }
    if (isHorizontal_) {
        contacts_.setMousePos(x, y);
    } 
    else {
        const int horX = canvas_.width() - 1 - y;
        const int horY = x;

        const int clampedX = std::clamp(horX, 0, canvas_.width() - 1);
        const int clampedY = std::clamp(horY, 0, canvas_.height() - 1);
        contacts_.setMousePos(clampedX, clampedY);
    }

    plotUpdate();
}

Canvas &Plot2D::canvas() { return canvas_; }

DatasetCursor &Plot2D::cursor() { return cursor_; }

void Plot2D::resetCash() {
    echogram_.resetCash();
}

void Plot2D::releaseCache()
{
    echogram_.releaseCache();
}

void Plot2D::plotUpdate() {}

void Plot2D::sendSyncEvent(int epoch_index, QEvent::Type eventType) {
    Q_UNUSED(epoch_index);
    Q_UNUSED(eventType);
}

void Plot2D::setMosaicLOffset(float val)
{
    lAngleOffsetDeg_ = val;
}

void Plot2D::setMosaicROffset(float val)
{
    rAngleOffsetDeg_ = val;
}

void Plot2D::clearPauseFreeze() {
    frozenValid_ = false;
    frozenHead_  = -1;
    frozenH_     = 0;
}

//Pulse
void Plot2D::freezePauseWindow() {
    if (frozenValid_) return;

    const int N = datasetPtr_ ? datasetPtr_->size() : 0;
    const int H = canvas_.height();

    // Prefer the live “rightmost” we tracked while running; else fall back to timeline
    int head = 0;
    if (rightmostEpochOnScreen_ > 0 && rightmostEpochOnScreen_ <= N-1) {
        head = rightmostEpochOnScreen_ + 1;   // newest = head-1
    } else {
        head = int(std::round(double(timelinePosition()) * double(N)));
    }

    frozenHead_  = std::clamp(head, 0, N);
    frozenH_     = std::max(0, H);
    frozenValid_ = true;

}

void Plot2D::reindexingCursor() {
    if (!datasetPtr_) return;

    //const int W = canvas_.width();
    //const int N = datasetPtr_->size();
    const int image_width = canvas_.width();
    const int data_width = datasetPtr_->size();
    const int last_indexes_size = cursor_.indexes.size();

    // Handle degenerate cases + keep sizes in sync
    if (image_width <= 0 || data_width <= 0) {
        cursor_.indexes.assign(std::max(0, image_width), -1);
        cursor_.numZeroEpoch     = std::max(0, image_width);
        cursor_.last_dataset_size = data_width;
        return;
    }
    if (last_indexes_size != image_width) {
        cursor_.indexes.resize(image_width);
    }

    // Preserve timeline gap to the head when dataset grows/shrinks
    const bool followLive = kIs32BitProcess() && !echogramDragActive_ && !echogramPause_ && !echogramHoldHistory_;
    if (cursor_.last_dataset_size > 0) {
        float pos = timelinePosition();
        if (followLive) {
            pos = 1.0f;
            setTimelinePosition(pos);
        } else {
            const float last_head = std::round(pos * cursor_.last_dataset_size);
            const float tail_gap  = float(cursor_.last_dataset_size) - last_head;
            const float new_head  = data_width- tail_gap;
            pos = (data_width > 0) ? std::clamp(float(new_head) / float(data_width), 0.0f, 1.0f) : 1.0f;
            setTimelinePosition(pos);
        }
    }
    cursor_.last_dataset_size = data_width;

    // THE STRETCH IS THE MAPPING. Column x (0 = oldest edge, W-1 = the live edge) shows
    // the epoch (x - W) / stretch() columns back from the head. Nothing scales the painter,
    // so a screen column IS a canvas column and every reader of cursor_.indexes - the
    // echogram, the tap, the loupe, the markers - sees the picture as it is drawn.
    const double hor_ratio = stretch();

    // Dataset "head" (right edge + 1)
    const int head = int(std::round(double(timelinePosition()) * double(data_width)));

    int zeros = 0;
    for (int x = 0; x < image_width; ++x) {
        int data_index = head + round((x - image_width)/hor_ratio) - 1;

        if (data_index >= 0 && data_index < data_width) {
            cursor_.indexes[x] = data_index;
        } else {
            cursor_.indexes[x] = -1;
            ++zeros;
        }
    }

    cursor_.numZeroEpoch = zeros;

    // WHAT THE SCREEN HOLDS, from the table itself (session 7). rightmostEpochOnScreen_ had
    // a reader (the aim's pause snapshot, freezePauseWindow) and no writer, so it read 0
    // and the aim's paused position search was capped at epoch 0 before it fell back to
    // the whole dataset. visibleColsOnScreen_ came from the painter's world transform,
    // which no longer carries the stretch. Both are now the table's own answer.
    int newest = -1;
    for (int x = image_width - 1; x >= 0; --x) {
        if (cursor_.indexes[x] >= 0) { newest = cursor_.indexes[x]; break; }
    }
    rightmostEpochOnScreen_ = std::max(0, newest);
    visibleColsOnScreen_    = std::max(1, image_width - zeros);

    if (cursor_.mouseX >= 0 && !cursor_.indexes.empty()) {
        const int clampedX = std::clamp(cursor_.mouseX, 0, image_width - 1);
        const int epochIndex = cursor_.getIndex(clampedX);
        cursor_.currentEpochIndx = datasetPtr_->validIndex(epochIndex);
        if (cursor_.currentEpochIndx >= 0) {
            cursor_.lastEpochIndx = cursor_.currentEpochIndx;
        }
    }
}


void Plot2D::reRangeDistance()
{
    if (datasetPtr_ == nullptr) {
        return;
    }

    float max_range = NAN;

    const bool is2D = is2DTransducer_ || isSideScan2DView_;
    //const bool doAutoRange = shouldDoAutoRange_;
    // const double autoRangeMax = autoDepthMaxLevel_;

    if (cursor_.distance.mode == AutoRangeLastData) {
        for (int i = datasetPtr_->endIndex() - 3; i < datasetPtr_->endIndex(); i++) {
            Epoch* epoch = datasetPtr_->fromIndex(i);
            if (epoch != nullptr) {
                float epoch_range = epoch->getMaxRange(cursor_.channel1);
                if (!isfinite(max_range) || max_range < epoch_range) {
                    max_range = epoch_range;
                }
            }
        }
    }

    if(cursor_.distance.mode == AutoRangeLastOnScreen) {
        for(unsigned int i = cursor_.indexes.size() - 3; i < cursor_.indexes.size(); i++) {
            Epoch* epoch = datasetPtr_->fromIndex(cursor_.getIndex(i));
            if(epoch != nullptr) {
                float epoch_range = epoch->getMaxRange(cursor_.channel1);
                if(!isfinite(max_range) || max_range < epoch_range) {
                    max_range = epoch_range;
                }
            }
        }
    }

    if(cursor_.distance.mode == AutoRangeMaxOnScreen) {
        for(unsigned int i = 0; i < cursor_.indexes.size(); i++) {
            Epoch* epoch = datasetPtr_->fromIndex(cursor_.getIndex(i));
            if(epoch != nullptr) {
                float epoch_range = epoch->getMaxRange(cursor_.channel1);
                if(!isfinite(max_range) || max_range < epoch_range) {
                    max_range = epoch_range;
                }
            }
        }
    }

    if (shouldDoAutoRange_) {
        if(isfinite(max_range)) {
            if(cursor_.isChannelDoubled()) {
                cursor_.distance.from = -ceil(autoDepthMaxLevel_);;
            } else {
                cursor_.distance.from = 0;
            }
            if (is2D) {
                cursor_.distance.from = 0;
            }
            cursor_.distance.to = ceil(autoDepthMaxLevel_);
        }

    /*
    if (doPulseAutoRange) {
        if(isfinite(max_range)) {
            if(cursor_.isChannelDoubled()) {
                cursor_.distance.from = -ceil(pulseAutoRange);;
            } else {
                cursor_.distance.from = 0;
            }
            if (is2D) {
                cursor_.distance.from = 0;
            }
            cursor_.distance.to = ceil(pulseAutoRange);
        } */
    } else {
        if (isfinite(max_range)) {
            const float dist = std::round(std::abs(max_range));
            cursor_.distance.to = dist;

            if (cursor_.isChannelDoubled()) {
                cursor_.distance.from = -dist;
            }
            else {
                cursor_.distance.from = 0;
            }
        }
    }
}

float Plot2D::timelinePosition()
{
    return cursor_.position;
}

