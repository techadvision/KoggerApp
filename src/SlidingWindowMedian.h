// SlidingWindowMedian.h
#ifndef SLIDINGWINDOWMEDIAN_H
#define SLIDINGWINDOWMEDIAN_H

#include <deque>
#include <vector>
#include <algorithm>

class SlidingWindowMedian {
public:
    // Constructor: windowSize defaults to 5
    SlidingWindowMedian(size_t windowSize = 5) : windowSize(windowSize) {}

    // Process a new sample and return the median of the current window
    double processSample(double sample) {
        if (window.size() == windowSize) {
            window.pop_front();
        }
        window.push_back(sample);

        // Copy the current window to a vector for sorting
        std::vector<double> sortedWindow(window.begin(), window.end());
        std::sort(sortedWindow.begin(), sortedWindow.end());
        size_t n = sortedWindow.size();
        // With odd count, the median is the middle element
        return sortedWindow[n / 2];
    }

    // Reset the entire window to a constant value:
    void reset(double sample) {
        window.clear();
        for(size_t i=0; i<windowSize; ++i)
            window.push_back(sample);
    }

private:
    std::deque<double> window;
    size_t windowSize;
};

#endif // SLIDINGWINDOWMEDIAN_H

