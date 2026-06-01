#include "plot2D.h"
#include "epoch_event.h"

//PULSE
#include <QObject>
#include <QVariant>
#include <QDebug>

#include "qmath.h"
#include <cmath>

MiniPreviewPlot2D::MiniPreviewPlot2D()
{
    setHorizontal(true);
    setPlotEnabled(true);
    echogram_.setVisible(true);
    echogram_.setWrapEnabled(false);
    bottomProcessing_.setVisible(true);
    bottomProcessing_.setDepthTextVisible(false);
    rangefinder_.setVisible(true);
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
                               int rangefinderThemeId)
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
    bottomProcessing_.setVisible(bottomTrackVisible);
    bottomProcessing_.setTheme(bottomTrackThemeId);
    rangefinder_.setVisible(rangefinderVisible);
    rangefinder_.setTheme(rangefinderThemeId);

    const bool rendered = echogram_.draw(this, dataset);
    if (!rendered) {
        return false;
    }

    if (QPainter* canvasPainter = canvas_.painter(); canvasPainter != nullptr) {
        for (const auto& range : noDataRanges) {
            const int xFrom = range.first;
            const int xTo = range.second;
            if (xTo > xFrom) {
                canvasPainter->fillRect(xFrom, 0, xTo - xFrom, previewHeight, Qt::black);
            }
        }
    }

    bottomProcessing_.draw(this, dataset);
    rangefinder_.draw(this, dataset);
    return true;
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
    rangefinder_.setVisible(true);
    depth_.setVisible(true);
    grid_.setVisible(true);
    temperature_.setVisible(true);
    aim_.setVisible(true);
    quadrature_.setVisible(false);
    setDataChannel(false, CHANNEL_NONE, 0, {});
    cursor_.attitude.from = -180;
    cursor_.attitude.to = 180;
    cursor_.distance.set(0, 20);
}

//PULSE
void Plot2D::applyRuntime(const QVariantMap& m)
{
    //qDebug() << "applyRuntime this=" << this << " thread=" << QThread::currentThread();
    if (m.contains("isSideScanLeftHand"))  isSideScanLeftHand_ = m.value("isSideScanLeftHand").toBool();
    if (m.contains("isSideScan2DView"))    isSideScan2DView_   = m.value("isSideScan2DView").toBool();
    if (m.contains("echogramSpeed"))       echogramSpeed_      = m.value("echogramSpeed").toDouble();
    if (m.contains("is2DTransducer"))      is2DTransducer_     = m.value("is2DTransducer").toBool();
    if (m.contains("shouldDoAutoRange"))   shouldDoAutoRange_  = m.value("shouldDoAutoRange").toBool();
    if (m.contains("autoDepthMaxLevel"))   autoDepthMaxLevel_  = m.value("autoDepthMaxLevel").toDouble();
    if (m.contains("maximumDepth"))        maximumDepth_       = m.value("maximumDepth").toInt();
    if (m.contains("autoRange"))           autoRange_          = m.value("autoRange").toInt();
    if (m.contains("echogramPause")) {
        echogramPause_ = m.value("echogramPause").toBool();
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
    const bool useChannel1 = qFuzzyIsNull(dist) || dist < 0.0f || cursor_.channel2 == CHANNEL_NONE;

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

    int column = -1;
    int sizeIndxs = cursor_.indexes.size();
    for (int i = 0; i < sizeIndxs; ++i) {
        if (cursor_.indexes[i] == epochIndx) {
            column = i;
            break;
        }
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

        if (echogramSpeed_ > 1.0 && !flipImage) {
            painter->translate(width, 0);
            painter->scale(echogramSpeed_, 1.0);
            painter->translate(-width, 0);
        }
        if (flipImage) {
            painter->translate(0, height);
            painter->scale(1.0, -1.0);
        }
        canvas_.setSize(width, height, painter);

        const QTransform W = painter->worldTransform();
        const double sxMag = std::hypot(W.m11(), W.m12());
        const double sx    = std::max(1e-6, sxMag);
        visibleColsOnScreen_ = std::max(1, int(std::floor(double(canvas_.width())/sx + 0.5)));
    }
    else {

        canvas_.setSize(height, width, painter);

        const QTransform W = painter->worldTransform();
        const double sxMag = std::hypot(W.m11(), W.m12());
        const double sx    = std::max(1e-6, sxMag);
        visibleColsOnScreen_ = std::max(1, int(std::floor(double(canvas_.width())/sx + 0.5)));

        painter->rotate(-90);
        painter->translate(-height, 0);
    }

    if (echogramPause_ && !echogramDragActive_)
        return true;

    reindexingCursor();
    reRangeDistance();

    return true;

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
    temperature_.draw(this, datasetPtr_);
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

    float pos = epochIndx == -1 ? cursor_.position : static_cast<float>(epochIndx + cursor_.indexes.size() / 2) / static_cast<float>(datasetPtr_->size());
    cursor_.selectEpochIndx = epochIndx;
    setTimelinePositionSec(pos);
}

void Plot2D::scrollPosition(int columns)
{
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
    qDebug() << "setEchogramLowLevel to value " << low;
    echogram_.setLowLevel(low);
    plotUpdate();
}

void Plot2D::setEchogramHightLevel(float high) {
    qDebug() << "setEchogramHightLevel to value " << high;
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
    bottomProcessing_.setDepthTextVisible(visible);
    plotUpdate();
}

void Plot2D::setRangefinderVisible(bool visible) {
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
    rangefinder_.setDepthTextVisible(visible);
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

void Plot2D::setDopplerInstrumentVisible(bool visible) {
    dvlSolution_.setVisible(visible);
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

    //cursor_.distance.set(from, to);
}

void Plot2D::zoomDistance(float ratio)
{
    //qDebug() << "Plot2D::zoomDistance with ratio" << ratio;
    cursor_.distance.mode = AutoRangeNone;

    int  delta = ratio;
    if(delta == 0) return;

    float from = cursor_.distance.from;
    float to = cursor_.distance.to;
    float absrange = abs(to - from);

    float zoom = delta < 0 ? -delta*0.01f : delta*0.01f;
    float delta_range = absrange*zoom;
    float new_range = 0;

    if(delta_range < 0.1) {
        delta_range = 0.1;
    } else if(delta_range > 5) {
        delta_range = 5;
    }

    if(delta > 0) {
        new_range = absrange + delta_range;
    } else {
        new_range = absrange - delta_range;
    }

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
            cursor_.distance.from = -ceil( new_range/2);
            cursor_.distance.to = ceil( new_range/2);
            qDebug() << "zoomDistance dualChannel: delta" << delta << "absrange" << absrange << "new_range" << new_range << "cursor_.distance.to" << cursor_.distance.to;
        }

    }
    else {
       cursor_.distance.to = ceil(cursor_.distance.from + new_range);
    }

    plotUpdate();
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

    if(cursor_.tool() > MouseToolNothing && !isSync) {

        for(int x_ind = 0; x_ind < x_length; x_ind++) {
            int epoch_index = cursor_.getIndex(x_start + x_ind);

            Epoch* epoch = datasetPtr_->fromIndex(epoch_index);

            const ChannelId channel1 = cursor_.channel1;
            const ChannelId channel2 = cursor_.channel2;

            if(epoch != NULL) {
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
            emit datasetPtr_->bottomTrackUpdated(cursor_.channel1, cursor_.getIndex(x_start), cursor_.getIndex(x_start + x_length), true, false);
        }
    }

    plotUpdate();
}

void Plot2D::simpleSetMousePosition(int x, int y)
{
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

    int x_start = 0;
    if(mouseX != -1) {
        if(mouseX < x) {
            x_start = mouseX;
        }
        else if (mouseX > x) {
            x_start = x;
        }
        else {
            x_start = x;
        }
    }
    else {
        x_start = x;
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

    // --- Mirror draw-time transform ---
    // In getImage(): for horizontal && !flipImage we do:
    //   translate(W,0); scale(s,1); translate(-W,0)  with  s = echogramSpeed_ (>1)
    // So one data column spans 's' device pixels, right-anchored at the screen's right edge.
    const bool flipImage = isSideScanLeftHand_ && isSideScan2DView_;
    const double s_applied = (isHorizontal_ && !flipImage && echogramSpeed_ > 1.0)
                                 ? double(echogramSpeed_)
                                 : 1.0;
    const double hor_ratio = s_applied; // device pixels per data column when stretched

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
    if (datasetPtr_ == NULL) {
        return;
    }

    float max_range = NAN;

    const bool is2D = is2DTransducer_ || isSideScan2DView_;
    //const bool doAutoRange = shouldDoAutoRange_;
    // const double autoRangeMax = autoDepthMaxLevel_;

    if (cursor_.distance.mode == AutoRangeLastData) {
        for (int i = datasetPtr_->endIndex() - 3; i < datasetPtr_->endIndex(); i++) {
            Epoch* epoch = datasetPtr_->fromIndex(i);
            if (epoch != NULL) {
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
            if(epoch != NULL) {
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
            if(epoch != NULL) {
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
