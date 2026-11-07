#pragma once

#include <stdint.h>
#include <QMap>
#include <QPair>
#include <QVector>

#include "dataset_defs.h"
#include "epoch.h"
#include "id_binnary.h"


using VecCntAndBrightness = QVector<QPair<uint8_t, uint8_t>>; // first - counter, second - brightness

class BlackStripesProcessor
{
public:
    enum class Direction : uint8_t {
        kForward = 0,
        kBackward
    };

    BlackStripesProcessor();

    // What the last update() did, for the STRIPES: instrument (P3 of the motor-noise plan, 7 Nov 2026):
    // masked = samples the epoch's error list (and a short length) marked for repair, summed over the sub
    // channels; repaired = those the reference could fill; grown = the trace was lengthened to the
    // reference's length; hadErrors = the epoch arrived with a non-empty error list.
    struct UpdateStats {
        int  masked    = 0;
        int  repaired  = 0;
        bool grown     = false;
        bool hadErrors = false;
    };

    bool update(const ChannelId& channelId, Epoch* epoch, Direction direction, float resolution, float offset);
    const UpdateStats& lastUpdateStats() const { return lastStats_; }
    void clear();
    void clearEthalonData(const ChannelId& channelId, Direction direction);
    void tryResizeEthalonData(const ChannelId& channelId, uint8_t numSubChannels, Direction direction, int size);

    void setState(bool state);
    void setForwardSteps(int val);
    void setBackwardSteps(int val);
    bool getState() const;
    int  getForwardSteps() const;
    int  getBackwardSteps() const;

private:
    // methods
    int getLastValidEthalonIndex(const ChannelId& channelId, uint8_t subChannelId, Direction direction) const;
    QVector<uint8_t> createErrorMask(const QList<Segment>& errList, int dataSize) const;

    // data
    QMap<ChannelId, QVector<VecCntAndBrightness>> forwardEthalonData_; // QVector - data for subchannels
    QMap<ChannelId, QVector<VecCntAndBrightness>> backwardEthalonData_;
    bool state_;
    int forwardSteps_;
    int backwardSteps_;
    UpdateStats lastStats_;
};
