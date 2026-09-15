#include "black_stripes_processor.h"


BlackStripesProcessor::BlackStripesProcessor() :
    state_(false),
    forwardSteps_(15),
    backwardSteps_(15)
{}

bool BlackStripesProcessor::update(const ChannelId& channelId, Epoch* epoch, Direction direction, float resolution, float offset)
{
    bool beenUpdated = false;

    if (!epoch) {
        return beenUpdated;
    }

    if (!epoch->getChartsSizeByChannelId(channelId)) {
        auto& data = direction == Direction::kForward ? forwardEthalonData_ : backwardEthalonData_;
        QVector<VecCntAndBrightness>* allDirData = nullptr;
        if (data.contains(channelId)) {
            allDirData = &data[channelId];
        }
        if (allDirData) {
            int newNumSubCh = allDirData->size();
            QVector<QVector<uint8_t>> data(newNumSubCh);
            epoch->setChart(channelId, data, resolution, offset);
        }
    }

    uint8_t chartSize = epoch->getChartsSizeByChannelId(channelId);

    for (uint8_t subChannelId = 0; subChannelId < chartSize; ++subChannelId) {
        const int dataSize = epoch->chartSize(channelId, subChannelId);
        const int lastValidEthalonIndex = getLastValidEthalonIndex(channelId, subChannelId, direction);
        const int newDataSize = (lastValidEthalonIndex >= dataSize) ? lastValidEthalonIndex + 1 : dataSize;
        const bool isForward = direction == Direction::kForward;

        auto& allForwardEthalonDataByChannelId = forwardEthalonData_[channelId];
        auto& allBackwardEthalonDataByChannelId = backwardEthalonData_[channelId];
        if (isForward) {
            if (subChannelId >= allForwardEthalonDataByChannelId.size()) {
                allForwardEthalonDataByChannelId.resize(subChannelId + 1);
            }
        }
        else {
            if (subChannelId >= allBackwardEthalonDataByChannelId.size()) {
                allBackwardEthalonDataByChannelId.resize(subChannelId + 1);
            }
        }

        auto& ethalonVector = isForward ? allForwardEthalonDataByChannelId[subChannelId] : allBackwardEthalonDataByChannelId[subChannelId];
        if (ethalonVector.size() < newDataSize) {
            ethalonVector.resize(newDataSize);
        }

        if (epoch->chartAvail(channelId, subChannelId)) {
            auto& amplitude = epoch->chart(channelId, subChannelId)->amplitude;
            auto chartParameters = epoch->getChartParameters(channelId);

            if (dataSize < newDataSize) {
                chartParameters.errList.append(Segment(dataSize, newDataSize));
                epoch->setChartParameters(channelId, chartParameters);
                amplitude.resize(newDataSize);
                beenUpdated = true;

                // AND THE GROW PATH IS THE ONE THAT CAN READ PAST THE END, not merely draw
                // something stale. chartTo() takes rawSize from amplitude.size(), and its
                // guards for imageType 1 and 4 are isEmpty() alone - so a `compensated` or
                // `tgc` buffer left at the OLD, SHORTER length is accepted and then indexed
                // to the new rawSize. The two TVG buffers happen to be safe because their
                // guards compare size, which is luck rather than design: the same mistake
                // one buffer away is an overread.
                epoch->chart(channelId, subChannelId)->invalidateDerived();
            }
        }
        else {
            if (lastValidEthalonIndex == -1) {
                continue;
            }

            QVector<uint8_t> data(lastValidEthalonIndex + 1, 0);
            for (int i = 0; i < data.size(); ++i) {
                if (ethalonVector[i].first) {
                    data[i] = ethalonVector[i].second;
                    --ethalonVector[i].first;
                }
            }

            epoch->setChartBySubChannelId(channelId, subChannelId, data, resolution, offset);
            auto chartParameters = epoch->getChartParameters(channelId);
            chartParameters.errList.append(Segment(0, data.size()));
            epoch->setChartParameters(channelId, chartParameters);
            beenUpdated = true;
        }

        auto* echogram = epoch->chart(channelId, subChannelId);
        auto& amplitude = echogram->amplitude;
        auto chartParameters = epoch->getChartParameters(channelId);

        const auto errorMask = createErrorMask(chartParameters.errList, newDataSize);
        const bool isMaskAvailable = !errorMask.isEmpty();

        bool repairedSamples = false;

        for (int i = 0; i < newDataSize; ++i) {
            if (isMaskAvailable && errorMask[i]) {
                if (ethalonVector[i].first) {
                    beenUpdated = true;
                    repairedSamples = true;
                    amplitude[i] = ethalonVector[i].second;
                    --ethalonVector[i].first;
                }
            }
            else {
                ethalonVector[i] = qMakePair(isForward ? forwardSteps_ : backwardSteps_, amplitude.at(i));
            }
        }

        // THE REPAIR HAS TO REACH THE GAIN BUFFERS, AND THIS IS THE ONE WRITER THAT HAS TO
        // SAY SO ITSELF.
        //
        // Epoch::setChart and Epoch::setChartBySubChannelId invalidate on their own, so
        // every caller of those is covered without knowing the caches exist. This loop is
        // different: it writes through a reference to the epoch's own vector, which Epoch
        // cannot observe, at an unchanged length - and an unchanged length is precisely what
        // chartTo()'s cache guards test. Without this the repaired samples are invisible to
        // imageType 1 to 4 and visible only on the raw render, which is why the black stripes
        // removal looked as though the TVG switch disabled it.
        //
        // Guarded on repairedSamples rather than beenUpdated: the branches above that set
        // beenUpdated without touching this vector have already invalidated through Epoch's
        // own setters, and the resize case rebuilds anyway. The cost is bounded by the step
        // counts - at most forward + backward epochs re-gained per ping.
        if (repairedSamples) {
            echogram->invalidateDerived();
        }
    }

    return beenUpdated;
}

void BlackStripesProcessor::clear()
{
    forwardEthalonData_.clear();
    backwardEthalonData_.clear();
}

void BlackStripesProcessor::clearEthalonData(const ChannelId& channelId, Direction direction)
{
    auto& ethalonData = direction == Direction::kForward ? forwardEthalonData_ : backwardEthalonData_;

    if (ethalonData.contains(channelId)) {
        ethalonData[channelId].clear();
    }
}

void BlackStripesProcessor::tryResizeEthalonData(const ChannelId& channelId, uint8_t numSubChannels, Direction direction, int size)
{
    auto& ethalonData = direction == Direction::kForward ? forwardEthalonData_ : backwardEthalonData_;

    if (ethalonData.contains(channelId)) {
        auto& allChannelData = ethalonData[channelId];

        if (allChannelData.size() < numSubChannels) {
            allChannelData.resize(numSubChannels);
        }

        for (auto& iChannelData : allChannelData) {
            if (size < iChannelData.size()) {
                iChannelData.resize(size);
            }
        }
    }
}

void BlackStripesProcessor::setState(bool state)
{
    state_ = state;
}

void BlackStripesProcessor::setForwardSteps(int val)
{
    forwardSteps_ = val;
}

void BlackStripesProcessor::setBackwardSteps(int val)
{
    backwardSteps_ = val;
}

bool BlackStripesProcessor::getState() const
{
    return state_;
}

int BlackStripesProcessor::getForwardSteps() const
{
    return forwardSteps_;
}

int BlackStripesProcessor::getBackwardSteps() const
{
    return backwardSteps_;
}

int BlackStripesProcessor::getLastValidEthalonIndex(const ChannelId& channelId, uint8_t subChannelId, Direction direction) const
{
    int retVal = -1;

    const auto& ethData = direction == Direction::kForward ? forwardEthalonData_ : backwardEthalonData_;

    auto it = ethData.constFind(channelId);
    if (it == ethData.cend()) {
        return retVal;
    }

    const auto& allChannelData = it.value();

    if (subChannelId >= allChannelData.size()) {
        return retVal;
    }

    const auto& selectedChannelData = allChannelData[subChannelId];
    for (int i = selectedChannelData.size() - 1; i >= 0; --i) {
        if (selectedChannelData.at(i).first) {
            return i;
        }
    }

    return retVal;
}

QVector<uint8_t> BlackStripesProcessor::createErrorMask(const QList<Segment>& errList, int dataSize) const
{
    if (dataSize <= 0) {
        return {};
    }

    QVector<uint8_t> retVal(dataSize, 0);

    for (const auto& seg : errList) {
        const int start = std::max(static_cast<int>(seg.first), 0);
        const int end   = std::min(static_cast<int>(seg.second), dataSize);
        if (start > dataSize ||
            end > dataSize) {
            return {};
        }

        for (int i = start; i < end; ++i) {
            retVal[i] = 1;
        }
    }

    return retVal;
}
