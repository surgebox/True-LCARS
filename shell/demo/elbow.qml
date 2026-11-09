import QtQuick
import QtQuick.Window
import Quickshell

import "theme"
import "ui"

// ---------------------------------------------------------------------------
// All four elbow orientations side by side, with the geometry that defines them
// labelled. Run it with ./dev/shot.sh elbow-test.qml dev/shots/elbows.png
//
// Every elbow is the same 360x200 box: a 60-thick bar arm, a 210-thick column
// arm, a 46 outer corner and a 26 concave shoulder.
// ---------------------------------------------------------------------------
Window {
    id: win

    width: 1600
    height: 640
    visible: true
    color: LcarsUi.black
    title: "LCARS // elbow test"

    // The shell derives its scale from the SCREEN height. A demo pins it to 1
    // instead, so a component renders at the same size here as it does in the
    // shell. Without this, a 560-tall window would scale everything to half
    // size and you would misjudge every dimension you were studying.
    Binding { target: LcarsUi; property: "scale"; value: 1 }

    property var spots: [
        { c: "topLeft", x: 40, y: 60 },
        { c: "topRight", x: 530, y: 60 },
        { c: "bottomLeft", x: 40, y: 360 },
        { c: "bottomRight", x: 530, y: 360 }
    ]

    Repeater {
        model: win.spots

        delegate: Item {
            x: modelData.x
            y: modelData.y
            width: 400
            height: 220

            // the full bounding box, so it is obvious where the shape sits
            LcarsRect {
                anchors.fill: parent
                color: "transparent"
                borderColor: Qt.rgba(1, 1, 1, 0.12)
                borderWidth: 1
            }

            LcarsElbow {
                x: 0
                y: 0
                width: LcarsUi.u(360)
                height: LcarsUi.u(200)
                corner: modelData.c
                color: LcarsUi.violet
                barThickness: LcarsUi.u(60)
                columnThickness: LcarsUi.u(210)
                outerRadius: LcarsUi.u(46)
                innerRadius: LcarsUi.u(26)
            }

            LcarsLabel {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: LcarsUi.u(212)
                text: modelData.c
                color: LcarsUi.orange
                size: 26
                caps: false
            }
        }
    }

    LcarsLabel {
        x: 1050
        y: 60
        width: 500
        text: "barThickness 60\ncolumnThickness 210\nouterRadius 46  (convex)\ninnerRadius 26  (concave)"
        color: LcarsUi.amber
        size: 24
        caps: false
        lineHeight: 1.4
    }
}
