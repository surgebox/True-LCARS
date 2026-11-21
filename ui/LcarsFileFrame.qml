import QtQuick
import "../theme"

// Frame shared by the Archives directory columns and preview pane.
Item {
    id: root
    property string title: ""
    property color accent: LcarsUi.lilac
    property color endAccent: LcarsUi.salmon
    readonly property real railWidth: LcarsUi.u(8)
    readonly property real headerHeight: LcarsUi.u(58)
    readonly property real capWidth: Math.min(LcarsUi.u(46), width / 5)
    readonly property real headerBarX: Math.min(
        capWidth + LcarsUi.u(8) + titleMetrics.advanceWidth + LcarsUi.u(13),
        Math.max(capWidth + LcarsUi.u(16), width - capWidth - LcarsUi.u(32)))

    TextMetrics {
        id: titleMetrics
        font.family: LcarsUi.font
        font.pixelSize: Math.round(LcarsUi.u(25))
        font.weight: Font.DemiBold
        text: root.title.toUpperCase()
    }

    LcarsRect {
        x: 0; y: root.headerHeight - 1
        width: root.railWidth; height: Math.max(0, root.height - y)
        color: root.accent; radiusBL: width / 2
    }
    LcarsRect {
        x: root.width - width; y: root.headerHeight - 1
        width: root.railWidth; height: Math.max(0, root.height - y)
        color: root.endAccent; radiusBR: width / 2
    }
    LcarsRect {
        x: 0; y: root.height - height
        width: Math.max(0, (root.width - LcarsUi.u(8)) / 2)
        height: root.railWidth
        color: root.accent; radiusBL: height / 2
    }
    LcarsRect {
        x: (root.width + LcarsUi.u(8)) / 2; y: root.height - height
        width: Math.max(0, (root.width - LcarsUi.u(8)) / 2)
        height: root.railWidth
        color: root.endAccent; radiusBR: height / 2
    }
    LcarsRect {
        x: 0; y: 0
        width: root.capWidth; height: root.headerHeight
        color: root.accent; radiusTL: height / 2
    }
    LcarsLabel {
        x: root.capWidth + LcarsUi.u(8); y: 0
        width: Math.max(0, root.headerBarX - x - LcarsUi.u(8))
        height: root.headerHeight
        text: root.title; color: root.accent; size: 25; fit: true
        elide: Text.ElideMiddle
    }
    Rectangle {
        x: root.headerBarX; y: 0
        width: Math.max(0, root.width - root.capWidth - x - LcarsUi.u(5))
        height: root.headerHeight
        color: root.accent
    }
    LcarsRect {
        x: root.width - width; y: 0
        width: root.capWidth; height: root.headerHeight
        color: root.endAccent; radiusTR: height / 2
    }
}
