#include "Plot2D.h"
#include <epochevent.h>

extern QObject* g_pulseRuntimeSettings;


Plot2D::Plot2D()
{
    _echogram.setVisible(true);
    _attitude.setVisible(true);
    _encoder.setVisible(true);
    _DVLBeamVelocity.setVisible(true);
    _DVLSolution.setVisible(true);
    _usblSolution.setVisible(true);
    _bottomProcessing.setVisible(true);
    _rangeFinder.setVisible(true);
    _grid.setVisible(true);
    _aim.setVisible(true);
    _quadrature.setVisible(false);
    setDataChannel(CHANNEL_FIRST);
   _cursor.attitude.from = -180;
   _cursor.attitude.to = 180;

    _cursor.distance.set(0, 100);
//    _cursor.velocity.set(-1, 1);
}

bool Plot2D::getImage(int width, int height, QPainter* painter, bool is_horizontal) {
    painter->save();
    if(is_horizontal) {
        if (g_pulseRuntimeSettings) {
            bool isSideScanOnLeftHandSide = g_pulseRuntimeSettings->property("isSideScanLeftHand").toBool();
            bool isSideScan2DView = g_pulseRuntimeSettings->property("isSideScan2DView").toBool();
            bool flipImage = isSideScanOnLeftHandSide && isSideScan2DView;
            double echogramSpeed = g_pulseRuntimeSettings->property("echogramSpeed").toDouble();

            if (echogramSpeed > 1 && !flipImage) {
                //painter->save();
                painter->translate(width, 0);
                painter->scale(echogramSpeed, 1.0);
                painter->translate(-width, 0);
            }
            if (flipImage) {
                painter->translate(0, height);
                painter->scale(1.0, -1.0);
            }
        }
        _canvas.setSize(width, height, painter);
    } else {
        _canvas.setSize(height, width, painter);
        painter->rotate(-90);
        painter->translate(-height, 0);
    }

    reindexingCursor();
    reRangeDistance();

//    painter->setCompositionMode(QPainter::RasterOp_SourceXorDestination);
    _echogram.draw(_canvas, _dataset, _cursor);

    _attitude.draw(_canvas, _dataset, _cursor);
    _encoder.draw(_canvas, _dataset, _cursor);
    _DVLBeamVelocity.draw(_canvas, _dataset, _cursor);
    _DVLSolution.draw(_canvas, _dataset, _cursor);
    _usblSolution.draw(_canvas, _dataset, _cursor);
    _bottomProcessing.draw(_canvas, _dataset, _cursor);
    _rangeFinder.draw(_canvas, _dataset, _cursor);
    _GNSS.draw(_canvas, _dataset, _cursor);
    _quadrature.draw(_canvas, _dataset, _cursor);

#ifdef Q_OS_WINDOWS
    painter->setCompositionMode(QPainter::CompositionMode_Exclusion);
#endif

    _grid.draw(_canvas, _dataset, _cursor);
    _aim.draw(_canvas, _dataset, _cursor);

    contacts_.draw(_canvas, _dataset, _cursor);

    painter->restore();

    return true;
}

void Plot2D::setAimEpochEventState(bool state)
{
    _aim.setEpochEventState(state);
}

void Plot2D::setTimelinePosition(float position)
{
    if (position > 1.0f) {
        position = 1.0f;
    }
    if (position < 0) {
        position = 0;
    }
    if (_cursor.position != position) {
        _cursor.position = position;
        plotUpdate();
    }
}

void Plot2D::resetAim()
{
    _cursor.selectEpochIndx = -1;
}

void Plot2D::setTimelinePositionSec(float position)
{
    if (position > 1.0f) {
        position = 1.0f;
    }
    if (position < 0) {
        position = 0;
    }

    _cursor.position = position;
    plotUpdate();
}

void Plot2D::setTimelinePositionByEpoch(int epochIndx) {
    float pos = epochIndx == -1 ? _cursor.position : static_cast<float>(epochIndx + _cursor.indexes.size() / 2) / static_cast<float>(_dataset->size());
    _cursor.selectEpochIndx = epochIndx;
    setTimelinePositionSec(pos);
}

void Plot2D::scrollPosition(int columns) {
    float new_position = timelinePosition() + (1.0f/_dataset->size())*columns;
    setTimelinePosition(new_position);
}

void Plot2D::setDataChannel(int channel, int channel2) {
    _cursor.channel1 = channel;
    _cursor.channel2 = channel2;

    float from = NAN, to = NAN;

    if(_dataset != NULL) {
        _dataset->getMaxDistanceRange(&from, &to, channel, channel2);

        if(isfinite(from) && isfinite(to) && (to - from) > 0) {
            _cursor.distance.set(from, to);
        }
    }

    resetCash();

    plotUpdate();
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
    return _echogram.getLowLevel();
}

float Plot2D::getEchogramHighLevel() const
{
    return _echogram.getHighLevel();
}

int Plot2D::getThemeId() const
{
    return _echogram.getThemeId();
}

void Plot2D::setEchogramLowLevel(float low) {
    //qDebug() << "TAV: setEchogramLowLevel low: " << low;
    _echogram.setLowLevel(low);
    plotUpdate();
}

void Plot2D::setEchogramHightLevel(float high) {
    //qDebug() << "TAV: setEchogramLowLevel high: " << high;
    _echogram.setHightLevel(high);
    plotUpdate();
}

void Plot2D::setEchogramVisible(bool visible) {
    _echogram.setVisible(visible);
    _echogram.resetCash();
    plotUpdate();
}

void Plot2D::setEchogramTheme(int theme_id) {
    _echogram.setThemeId(theme_id);
    plotUpdate();
}

void Plot2D::setEchogramCompensation(int compensation_id) {
    _echogram.setCompensation(compensation_id);
    _echogram.resetCash();
    plotUpdate();
}

void Plot2D::setBottomTrackVisible(bool visible) {
    _bottomProcessing.setVisible(visible);
    plotUpdate();
}

void Plot2D::setBottomTrackTheme(int theme_id) {
    Q_UNUSED(theme_id);
}

void Plot2D::setRangefinderVisible(bool visible) {
    _rangeFinder.setVisible(visible);
    _grid.setRangeFinderVisible(visible);
    plotUpdate();
}

void Plot2D::setRangefinderTheme(int theme_id) {
    qDebug() << "DevDriver - Plot2D setRangeFinderTheme " << theme_id;
    _rangeFinder.setTheme(theme_id);
    plotUpdate();
}

void Plot2D::setAttitudeVisible(bool visible) {
    _attitude.setVisible(visible);
    plotUpdate();
}

void Plot2D::setDopplerBeamVisible(bool visible, int beam_filter) {
    _DVLBeamVelocity.setVisible(visible);
    _DVLBeamVelocity.setBeamFilter(beam_filter);
    plotUpdate();
}

void Plot2D::setDopplerInstrumentVisible(bool visible) {
    _DVLSolution.setVisible(visible);
    plotUpdate();
}

void Plot2D::setGNSSVisible(bool visible, int flags) {
    Q_UNUSED(flags);

    _GNSS.setVisible(visible);
    plotUpdate();
}

void Plot2D::setGridVetricalNumber(int grids) {
    _grid.setVisible(grids > 0);
    _grid.setVetricalNumber(grids);
    plotUpdate();
}

void Plot2D::setGridFillWidth(bool state)
{
    _grid.setFillWidth(state);
    plotUpdate();
}

void Plot2D::setAngleVisibility(bool state)
{
    _grid.setAngleVisibility(state);
    plotUpdate();
}

void Plot2D::setAngleRange(int angleRange)
{
    _cursor.attitude.from = static_cast<float>(-angleRange);
    _cursor.attitude.to = static_cast<float>(angleRange);
    plotUpdate();
}

void Plot2D::setVelocityVisible(bool visible) {
    _grid.setVelocityVisible(visible);
    plotUpdate();
}

void Plot2D::setVelocityRange(float velocity) {
    _cursor.velocity.from = -velocity;
    _cursor.velocity.to = velocity;
    plotUpdate();
}

void Plot2D::setDistanceAutoRange(int auto_range_type) {
    _cursor.distance.mode = AutoRangeMode(auto_range_type);
}

void Plot2D::setDistance(float from, float to) {
    //qDebug() << "DevDriver - Plot2D setDistance from " << from << " to " << to;

    //bool isSideScanOnLeftHandSide = false;
    bool isSideScan2DView = false;
    if (g_pulseRuntimeSettings) {
        isSideScanOnLeftHandSide_ = g_pulseRuntimeSettings->property("isSideScanLeftHand").toBool();
        isSideScan2DView = g_pulseRuntimeSettings->property("isSideScan2DView").toBool();
    }
    if (isSideScanOnLeftHandSide_ && isSideScan2DView) {
        qDebug() << "DevDriver - Plot2D setDistance from " << -1*to << " to " << from;
        _cursor.distance.set(-1*to, from);
    } else {
        qDebug() << "DevDriver - Plot2D setDistance from " << from << " to " << to;
        _cursor.distance.set(from, to);
    }
    qDebug() << "DevDriver - ssLeftHand " << isSideScanOnLeftHandSide_ << " 2D view " << isSideScan2DView << " is horizontal " << _isHorizontal;
}

void Plot2D::zoomDistance(float ratio) {
    qDebug() << "DevDriver - Plot2D zoomDistance ratio " << ratio;
    _cursor.distance.mode = AutoRangeNone;

    int  delta = ratio;
    if(delta == 0) return;

    float from = _cursor.distance.from;
    float to = _cursor.distance.to;
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
    } else if(new_range > 500) {
        new_range = 500;
    }

    if (g_pulseRuntimeSettings) {
        int maximumTransducerRange = g_pulseRuntimeSettings->property("maximumDepth").toInt();
        if ((_cursor.distance.from + new_range) > maximumTransducerRange) {
            new_range = maximumTransducerRange;
        }
    }


    if(_cursor.isChannelDoubled()) {
        if (isHorizontal()) {
            //_cursor.distance.from = -ceil( new_range/2);
            //_cursor.distance.to = ceil(_cursor.distance.from + new_range);
            _cursor.distance.to = -ceil(_cursor.distance.from + new_range);
        } else {
            _cursor.distance.from = -ceil( new_range/2);
            _cursor.distance.to = ceil( new_range/2);
        }
        //_cursor.distance.from = -ceil( new_range/2);
        //_cursor.distance.to = ceil( new_range/2);
    } else {
       _cursor.distance.to = ceil(_cursor.distance.from + new_range);
    }

    plotUpdate();
}

void Plot2D::scrollDistance(float ratio)    {
    _cursor.distance.mode = AutoRangeNone;

    float from = _cursor.distance.from;
    float to = _cursor.distance.to;
    float absrange = abs(to - from);

    float delta_offset = ((float)absrange*(float)ratio*0.001f);

    if(from < to) {
        float round_cef = 10.0f;

        float from_n = (round((from + delta_offset)*round_cef)/round_cef);
        float to_n = (round((to + delta_offset)*round_cef)/round_cef);

        if(!_cursor.isChannelDoubled()) {
            if(from_n < 0) {
                to_n -= from_n;
                from_n = 0;
            }
        }

        _cursor.distance.from = from_n;
        _cursor.distance.to = to_n;

    } else if(from > to) {
        _cursor.distance.from = (from - delta_offset);
        _cursor.distance.to = (to - delta_offset);
    }

    plotUpdate();
}

void Plot2D::setMousePosition(int x, int y) {

    const int image_width = _canvas.width();
    const int image_height = _canvas.height();
    const int dataset_from = _cursor.getIndex(0);
    Q_UNUSED(dataset_from);

    const float distance_from = _cursor.distance.from;
    const float distance_range = _cursor.distance.to - _cursor.distance.from;
    const float image_distance_ratio = distance_range/(float)image_height;

    struct {
        int x = -1, y = -1;
    } _mouse;

    _mouse.x = _cursor.mouseX;
    _mouse.y = _cursor.mouseY;
    _cursor.setMouse(x, y);


    if(x < -1) { x = -1; }
    if(x >= image_width) { x = image_width - 1; }

    if(y < 0) { y = 0; }
    if(y >= image_height) { x = image_height - 1; }

    if(x == -1) {
        _mouse.x = -1;
        _cursor.selectEpochIndx = -1;
        _cursor.currentEpochIndx = -1;
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

    //qDebug() << "Cursor epoch" << _cursor.getIndex(x_start);
    int epoch_index = _cursor.getIndex(x_start);
    _cursor.currentEpochIndx = epoch_index;
    _cursor.lastEpochIndx = _cursor.currentEpochIndx;

    sendSyncEvent(epoch_index, EpochSelected2d);

    if(_cursor.tool() > MouseToolNothing) {

        for(int x_ind = 0; x_ind < x_length; x_ind++) {
            int epoch_index = _cursor.getIndex(x_start + x_ind);

            Epoch* epoch = _dataset->fromIndex(epoch_index);

            const int channel1 = _cursor.channel1;
            const int channel2 = _cursor.channel2;

            if(epoch != NULL) {

                float image_y_pos = ((float)y_start + (float)x_ind*y_scale);
                float dist = abs(image_y_pos*image_distance_ratio + distance_from);

                if(_cursor.tool() == MouseToolDistanceMin) {
                    epoch->setMinDistProc(channel1, dist);
                    epoch->setMinDistProc(channel2, dist);
                } else if(_cursor.tool() == MouseToolDistance) {
                    epoch->setDistProcessing(channel1, dist);
                    epoch->setDistProcessing(channel2, dist);
                } else if(_cursor.tool()== MouseToolDistanceMax) {
                    epoch->setMaxDistProc(channel1, dist);
                    epoch->setMaxDistProc(channel2, dist);
                } else if(_cursor.tool() == MouseToolDistanceErase) {
                    epoch->clearDistProcessing(channel1);
                    epoch->clearDistProcessing(channel2);
                }
            }
        }

        if (_cursor.tool() == MouseToolDistanceMin || _cursor.tool() == MouseToolDistanceMax) {
            if (auto btp = _dataset->getBottomTrackParamPtr(); btp) {
                btp->indexFrom = _cursor.getIndex(x_start);
                btp->indexTo = _cursor.getIndex(x_start + x_length);
                _dataset->bottomTrackProcessing(_cursor.channel1, _cursor.channel2);
            }
        }

        if(_cursor.tool() == MouseToolDistance || _cursor.tool() == MouseToolDistanceErase) {
            emit _dataset->bottomTrackUpdated(_cursor.getIndex(x_start), _cursor.getIndex(x_start + x_length));
        }
    }

    plotUpdate();
}

void Plot2D::simpleSetMousePosition(int x, int y)
{
    const int image_width = _canvas.width();
    const int image_height = _canvas.height();
    int mouseX = -1;

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
        _cursor.currentEpochIndx = -1;
        //_cursor.lastEpochIndx = -1; // ?
        return;
    }

    _cursor.setContactPos(x, y);

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

    _cursor.currentEpochIndx = _cursor.getIndex(x_start);
    _cursor.lastEpochIndx = _cursor.currentEpochIndx;

    //sendSyncEvent(epoch_index);
    //plotUpdate();
}

void Plot2D::setMouseTool(MouseTool tool) {
    _cursor.setTool(tool);
}

bool Plot2D::setContact(int indx, const QString& text)
{
    if (!_dataset) {
        qDebug() << "Plot2D::setContact returned: !_dataset";
        return false;
    }

    if (text.isEmpty()) {
        qDebug() << "Plot2D::setContact returned: text.isEmpty()";
        return false;
    }

    bool primary = indx == -1;
    int currIndx = primary ? _cursor.lastEpochIndx : indx;

    //qDebug() << "indx" << indx << "currIndx" << currIndx << text;

    auto* ep = _dataset->fromIndex(currIndx);
    if (!ep) {
        qDebug() << "Plot2D::setContact returned: !ep";
        return false;
    }

    ep->contact_.info = text;
    //qDebug() << "Plot2D::setContact: setted to epoch:" <<  currIndx << text;


    if (primary) {
        ep->contact_.cursorX = _cursor.contactX;
        ep->contact_.cursorY = _cursor.contactY;

        const float canvas_height = _canvas.height();
        float value_range = _cursor.distance.to - _cursor.distance.from;
        float value_scale = float(_cursor.contactY) / canvas_height;
        float cursor_distance = value_scale * value_range + _cursor.distance.from;

        ep->contact_.distance = cursor_distance;

        auto pos = ep->getPositionGNSS();

        ep->contact_.nedX = pos.ned.n;
        ep->contact_.nedY = pos.ned.e;

        ep->contact_.lat = pos.lla.latitude;
        ep->contact_.lon = pos.lla.longitude;
    }
    else {
        // update rect
    }

    sendSyncEvent(currIndx, ContactCreated);

    plotUpdate();

    return true;
}

bool Plot2D::deleteContact(int indx)
{
    if (!_dataset) {
        qDebug() << "Plot2D::deleteContact returned: !_dataset";
        return false;
    }

    //qDebug() << "indx" << indx << "currIndx" << currIndx << text;

    auto* ep = _dataset->fromIndex(indx);
    if (!ep) {
        qDebug() << "Plot2D::deleteContact returned: !ep";
        return false;
    }

    ep->contact_.clear();

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
    contacts_.setMousePos(x, y);

    plotUpdate();
}

void Plot2D::resetCash() {
    _echogram.resetCash();
}

void Plot2D::reindexingCursor() {
    if(_dataset == nullptr) { return; }

    const int image_width = _canvas.width();
    const int data_width = _dataset->size();
    const int last_indexes_size = _cursor.indexes.size();

    if(image_width != last_indexes_size) {
        _cursor.indexes.resize(image_width);
    }

    if(_cursor.last_dataset_size > 0) {
        float position = timelinePosition();

        float last_head = round(position*_cursor.last_dataset_size);
        float last_offset_head = float(_cursor.last_dataset_size) - last_head;
        float new_head = data_width - last_offset_head;

        position = float(new_head)/float(data_width);

        setTimelinePosition(position);
    }
    _cursor.last_dataset_size = data_width;

    float hor_ratio = 1.0f;

    float position = timelinePosition();

    int head_data_index = round(position*float(data_width));

    int cntZeros = 0;
    for(int i = 0; i < image_width; i++) {
        int data_index = head_data_index + round((i - image_width)/hor_ratio) - 1;
        if(data_index >= 0 && data_index < data_width) {
             _cursor.indexes[i] = data_index;
        } else {
            ++cntZeros;
             _cursor.indexes[i] = -1;
        }
    }
    _cursor.numZeroEpoch = cntZeros;
}

void Plot2D::reRangeDistance() {
    bool is2D = false;
    bool doPulseAutoRange = false;
    float pulseAutoRange = 0.5;
    if (g_pulseRuntimeSettings) {
        bool is2DTransducer = g_pulseRuntimeSettings->property("is2DTransducer").toBool();
        bool isSSTransducerIn2DView = g_pulseRuntimeSettings->property("isSideScan2DView").toBool();
        doPulseAutoRange = g_pulseRuntimeSettings->property("shouldDoAutoRange").toBool();
        pulseAutoRange = g_pulseRuntimeSettings->property("autoDepthMaxLevel").toFloat();
        if (is2DTransducer || isSSTransducerIn2DView) {
            is2D = true;
        }
    }
    if(_dataset == NULL) { return; }
    float max_range = NAN;

    if(_cursor.distance.mode == AutoRangeLastData) {
        for(int i = _dataset->endIndex() - 3; i < _dataset->endIndex(); i++) {
            Epoch* epoch = _dataset->fromIndex(i);
            if(epoch != NULL) {
                float epoch_range = epoch->getMaxRnage(_cursor.channel1);
                if(!isfinite(max_range) || max_range < epoch_range) {
                    max_range = epoch_range;
                }
            }
        }
    }

    if(_cursor.distance.mode == AutoRangeLastOnScreen) {
        for(unsigned int i = _cursor.indexes.size() - 3; i < _cursor.indexes.size(); i++) {
            Epoch* epoch = _dataset->fromIndex(_cursor.getIndex(i));
            if(epoch != NULL) {
                float epoch_range = epoch->getMaxRnage(_cursor.channel1);
                if(!isfinite(max_range) || max_range < epoch_range) {
                    max_range = epoch_range;
                }
            }
        }
    }

    if(_cursor.distance.mode == AutoRangeMaxOnScreen) {
        for(unsigned int i = 0; i < _cursor.indexes.size(); i++) {
            Epoch* epoch = _dataset->fromIndex(_cursor.getIndex(i));
            if(epoch != NULL) {
                float epoch_range = epoch->getMaxRnage(_cursor.channel1);
                if(!isfinite(max_range) || max_range < epoch_range) {
                    max_range = epoch_range;
                }
            }
        }
    }

    //qDebug() << "reRangeDistance - max_range " << max_range  << " pulseAutoRange " << pulseAutoRange;

    if (doPulseAutoRange) {
        if(isfinite(max_range)) {
            if(_cursor.isChannelDoubled()) {
                _cursor.distance.from = -ceil(pulseAutoRange);;
            } else {
                _cursor.distance.from = 0;
            }
            if (is2D) {
                _cursor.distance.from = 0;
            }
            _cursor.distance.to = ceil(pulseAutoRange);
        }
    } else {
        if(isfinite(max_range)) {
            if(_cursor.isChannelDoubled()) {
                _cursor.distance.from = -ceil(max_range);;
            } else {
                _cursor.distance.from = 0;
            }
            if (is2D) {
                _cursor.distance.from = 0;
            }
            _cursor.distance.to = ceil(max_range);
        }
    }

}

bool Plot2DAim::draw(Canvas &canvas, Dataset *dataset, DatasetCursor cursor) 
{
    if((cursor.mouseX < 0 || cursor.mouseY < 0) && (cursor.selectEpochIndx == -1) ) {
        return false;
    }

    if (cursor.selectEpochIndx != -1) {
        auto* ep = dataset->fromIndex(cursor.selectEpochIndx);
        int offsetX = 0;
        int halfCanvas = canvas.width() / 2;
        int withoutHalf = dataset->size() - halfCanvas;
        if (cursor.selectEpochIndx >= withoutHalf) {
            offsetX = cursor.selectEpochIndx - withoutHalf;
        }
        if (const auto keys{ dataset->channelsList().keys() }; !keys.empty()) {
            if (const auto chartPtr{ ep->chart(keys.at(0)) }; chartPtr) {
                const int x = canvas.width() / 2 + offsetX;
                const int y = keys.size() == 2 ? canvas.height() / 2 - canvas.height() * (chartPtr->bottomProcessing.distance / cursor.distance.range()) :
                                  canvas.height() * (chartPtr->bottomProcessing.distance / cursor.distance.range());
                cursor.setMouse(x, y);
            }
        }
    }

    QPainter* p = canvas.painter();

    QPen pen;
    pen.setWidth(_lineWidth);
    pen.setColor(_lineColor);
    p->setPen(pen);

    QFont font("Asap", 14 * scaleFactor_, QFont::Normal);
    font.setPixelSize(18 * scaleFactor_);
    p->setFont(font);

    if (cursor._tool == MouseToolNothing || beenEpochEvent_) {
        p->drawLine(0,             cursor.mouseY, canvas.width(),  cursor.mouseY);
        p->drawLine(cursor.mouseX, 0,             cursor.mouseX, canvas.height());
    }

    float canvas_height  = static_cast<float>(canvas.height());
    float value_range    = cursor.distance.to - cursor.distance.from;
    float value_scale    = float(cursor.mouseY) / canvas_height;
    float cursor_distance = value_scale * value_range + cursor.distance.from;

    p->setCompositionMode(QPainter::CompositionMode_SourceOver);

    QString distanceText = QString(QObject::tr("%1 m")).arg(cursor_distance, 0, 'g', 4);
    QString text = distanceText;

    int16_t channelId = cursor.channel2 == CHANNEL_NONE ? cursor.channel1 : cursor_distance <= 0 ? cursor.channel1 : cursor.channel2;

    if (channelId != CHANNEL_FIRST) {
        text += "\n" + QObject::tr("Channel: ") + QString::number(channelId);
    }

    if (cursor.currentEpochIndx != -1) {
        text += "\n" + QObject::tr("Epoch: ")   + QString::number(cursor.currentEpochIndx);

        if (auto* ep = dataset->fromIndex(cursor.currentEpochIndx); ep) {
            if (auto* echogram = ep->chart(channelId); echogram) {
                //qDebug() << "errs[" << cursor.currentEpochIndx << "]:"<< echogram->chartParameters_.errList;
                //qDebug() << "size[" << cursor.currentEpochIndx << "]:"<< echogram->amplitude.size();
                //qDebug() << "RES[" << cursor.currentEpochIndx << "]:" << echogram->resolution;

                if (!echogram->recordParameters_.isNull()) {
                    auto& recParams = echogram->recordParameters_;
                    QString boostStr = recParams.boost ? QObject::tr("ON") : QObject::tr("OFF");
                    text += "\n" + QObject::tr("Resolution, mm: ")      + QString::number(recParams.resol);
                    //text += "\n" + QObject::tr("Number of Samples: ") + QString::number(recParams.count);
                    //text += "\n" + QObject::tr("Offset of samples: ")     + QString::number(recParams.offset);
                    text += "\n" + QObject::tr("Frequency, kHz: ")      + QString::number(recParams.freq);
                    text += "\n" + QObject::tr("Pulse count: ")         + QString::number(recParams.pulse);
                    text += "\n" + QObject::tr("Booster: ")             + boostStr;
                    text += "\n" + QObject::tr("Speed of sound, m/s: ") + QString::number(recParams.soundSpeed / 1000);
                }
            }
        }
    }

    QRect textRect = p->fontMetrics().boundingRect(QRect(0, 0, 9999, 9999), Qt::AlignLeft | Qt::AlignTop, text);

    int xShift    = 50 * scaleFactor_;
    int yShift    = 40 * scaleFactor_;
    int xCheck    = xShift + 15 * scaleFactor_;
    int yCheck    = yShift + 15 * scaleFactor_;

    bool onTheRight = (p->window().width() - cursor.mouseX - xCheck) < textRect.width();

    int spaceBelow = cursor.mouseY;
    bool placeAbove = false;

    int neededSpaceBelow = textRect.height() + yCheck;
    if (spaceBelow < neededSpaceBelow) {
        placeAbove = true;
    }

    QPoint shiftedPoint;
    if (!placeAbove) {
        shiftedPoint = onTheRight
                           ? QPoint(cursor.mouseX - xShift - textRect.width(),
                                    cursor.mouseY - yShift - textRect.height())
                           : QPoint(cursor.mouseX + xShift,
                                    cursor.mouseY - yShift - textRect.height());
    } else {
        shiftedPoint = onTheRight
                           ? QPoint(cursor.mouseX - xShift - textRect.width(),
                                    cursor.mouseY + yShift)
                           : QPoint(cursor.mouseX + xShift,
                                    cursor.mouseY + yShift);
    }

    textRect.moveTopLeft(shiftedPoint);

    // back
    p->setPen(Qt::NoPen);
    p->setBrush(QColor(45, 45, 45));
    int margin = 5 * scaleFactor_;
    QRect backgroundRect = textRect.adjusted(-margin, -margin, margin, margin);
    p->drawRect(backgroundRect);

    // text
    p->setPen(QColor(255,255,255));
    p->drawText(textRect, Qt::AlignLeft | Qt::AlignTop, text);

    return true;
}


//Pulse
void Plot2D::setMeasuresMetric(bool metric) {
    qDebug() << "Plot2d setMeasuresMetric:" << metric;
    _grid.setMeasuresMetric(metric);
    plotUpdate();
}

void Plot2D::setGridHorizontal(bool horizontal) {
    qDebug() << "Plot2d setGridHorizontal:" << horizontal;
    _grid.setGridHorizontal(horizontal);
    plotUpdate();
}

void Plot2D::setSideScanOnLeftHandSide (bool leftSideInstall) {
    qDebug() << "Plot2d setSideScanOnLeftHandSide:" << leftSideInstall;
    _grid.setSideScanOnLeftHandSide(leftSideInstall);
    plotUpdate();
}

Plot2DContact::Plot2DContact()
{

}

bool Plot2DContact::draw(Canvas &canvas, Dataset *dataset, DatasetCursor cursor)
{
    QPen pen;
    pen.setWidth(lineWidth_);
    pen.setColor(lineColor_);

    QPainter* p = canvas.painter();
    p->setPen(pen);
    QFont font = QFont("Asap", 14, QFont::Normal);
    font.setPixelSize(18);
    p->setFont(font);
    p->setCompositionMode(QPainter::CompositionMode_SourceOver);
    qreal adjPix = 5;
    qreal shiftXY = 20;

    setVisibleContact(false);

    for (auto& indx : cursor.indexes) {
        auto* epoch = dataset->fromIndex(indx);

        if (!epoch) {
            continue;
        }

        if (epoch->contact_.isValid()) {
            float xPos = cursor.numZeroEpoch + indx - cursor.indexes[0];
            const float canvasHeight = canvas.height();
            float valueRange = cursor.distance.to - cursor.distance.from;
            float valueScale = canvasHeight / valueRange;
            float yPos = (epoch->contact_.distance - cursor.distance.from) * valueScale;
            bool intersects = false;

            auto& epRect = epoch->contact_.rectEcho;
            if (!epRect.isEmpty()) {
                QRectF locRect = epRect.translated(QPointF(xPos + shiftXY, yPos + shiftXY) - epRect.topLeft());
                locRect = locRect.adjusted(-adjPix, -adjPix, adjPix, adjPix);

                if (locRect.contains(QPointF(mouseX_, mouseY_))) {
                    indx_ = indx;
                    position_ = QPoint(xPos + shiftXY * 0.75, yPos + shiftXY *0.75);
                    info_ = epoch->contact_.info;
                    lat_ = epoch->contact_.lat;
                    lon_ = epoch->contact_.lon;
                    depth_ = epoch->contact_.distance;
                    setVisibleContact(true);
                    intersects = true;
                }
            }

            QString infoText = epoch->contact_.info;
            QRectF textRect = p->fontMetrics().boundingRect(infoText);
            textRect.moveTopLeft(QPointF(xPos + shiftXY, yPos + shiftXY));

            // write rect
            if (epRect.height() != textRect.height() ||
                epRect.width() != textRect.width()) {
                epRect = textRect;
            }

            if (intersects) {
                QPointF topLeft = textRect.adjusted(-adjPix + 1, -adjPix + 1, adjPix, adjPix).topLeft();
                p->setPen(QPen(QColor(0,190,0), 2));
                p->drawLine(topLeft, topLeft + QPointF(-30, 0));
                p->drawLine(topLeft, topLeft + QPointF(0, -30));
            }
            else {
                // red back
                p->setPen(Qt::NoPen);
                p->setBrush(QColor(190, 0, 0));
                p->drawRect(textRect.adjusted(-adjPix, -adjPix, adjPix, adjPix));
                // lines
                QPointF topLeft = textRect.adjusted(-adjPix + 1, -adjPix + 1, adjPix, adjPix).topLeft();
                p->setPen(QPen(QColor(190,0,0), 2));
                p->drawLine(topLeft, topLeft + QPointF(-30, 0));
                p->drawLine(topLeft, topLeft + QPointF(0, -30));
                // gray back
                p->setPen(Qt::NoPen);
                p->setBrush(QColor(45,45,45));
                p->drawRect(textRect.adjusted(-3, -3, 3, 3));
                // text
                p->setPen(QColor(255,255,255));
                p->drawText(textRect, Qt::AlignLeft | Qt::AlignTop, infoText);
            }
        }
    }

    return true;
}

void Plot2DContact::setMousePos(int x, int y)
{
    mouseX_ = x;
    mouseY_ = y;
}

QString Plot2DContact::getInfo()
{
    return info_;
}

void Plot2DContact::setInfo(const QString &info)
{
    //qDebug() << "Plot2DContact::setInfo";

    info_ = info;
}

bool Plot2DContact::getVisible()
{
    return visible_;
}

void Plot2DContact::setVisible(bool visible)
{
    visible_ = visible;
}

QPoint Plot2DContact::getPosition()
{
    return position_;
}

int Plot2DContact::getIndx()
{
    return indx_;
}

double Plot2DContact::getLat()
{
    return lat_;
}

double Plot2DContact::getLon()
{
    return lon_;
}

double Plot2DContact::getDepth()
{
    return depth_;

}
