import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    anchors.fill: parent

    // app state
    property bool visibleWhenPaused: pulseRuntimeSettings.echogramPause
    property bool isHorizontalGrid: pulseRuntimeSettings.isHorizontalGrid
    visible: visibleWhenPaused

    // margins
    property int baseMargin: 50
    readonly property int lm: baseMargin + insetLeft()
    readonly property int rm: baseMargin + insetRight()
    readonly property int tm: baseMargin + insetTop()
    readonly property int bm: baseMargin + insetBottom()

    // timeline position (single source of truth) – you set this from outside
    property real timeLineScrollerPosition: 1.0

    // slider range/behavior (exposed to both sliders if you want)
    property real from: 0
    property real to: 1
    property real stepSize: 0.0001

    // ensure both variants show the current position when toggling layout
    onIsHorizontalGridChanged: {
        if (isHorizontalGrid) h.setPosition(timeLineScrollerPosition)
        else v.setPosition(timeLineScrollerPosition)
    }
    Component.onCompleted: {
        if (isHorizontalGrid) h.setPosition(timeLineScrollerPosition)
        else v.setPosition(timeLineScrollerPosition)
    }
    onTimeLineScrollerPositionChanged: {
        if (isHorizontalGrid) h.setPosition(timeLineScrollerPosition)
        else v.setPosition(timeLineScrollerPosition)
    }

    // H O R I Z O N T A L (top; L/T/R margins)
    TimelineSliderHorizontal {
        id: h
        visible:  root.isHorizontalGrid
        enabled:  visible

        // You CAN keep this binding safely now (we don't write slider.value inside the component)
        value: root.timeLineScrollerPosition

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: root.tm
            leftMargin: root.lm + 190
            rightMargin: root.rm + 190
        }
        thickness: _isAndroid ? 80 : 60 //theme.controlHeight + 30
        inverted: false // 1.0 at RIGHT

        // user dragged → update app
        onPositionChangedByUser: (pos) => {
            root.timeLineScrollerPosition = pos;
            core.setTimelinePosition(pos);
            core.resetAim();
        }

        onVisibleChanged: if (visible) setPosition(root.timeLineScrollerPosition)
    }

    // V E R T I C A L (left; L/T/B margins)
    TimelineSliderVertical {
        id: v
        visible:  !root.isHorizontalGrid
        enabled:  visible

        value: root.timeLineScrollerPosition

        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: root.lm
            topMargin: root.tm + 100
            bottomMargin: root.bm + 100
        }
        thickness: _isAndroid ? 80 : 60 //theme.controlHeight + 30
        inverted: true  // 1.0 at TOP (flip to false if you want bottom)

        onPositionChangedByUser: (pos) => {
            root.timeLineScrollerPosition = pos;
            core.setTimelinePosition(pos);
            core.resetAim();
        }

        onVisibleChanged: if (visible) setPosition(root.timeLineScrollerPosition)
    }
}
