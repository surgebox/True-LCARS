import QtQuick

// ---------------------------------------------------------------------------
// LcarsStrip - a horizontal bar. LCARS strips are square-ended by default;
// `capLeft` / `capRight` turn an end into a half-round cap, and `round` gives
// the plain corners a uniform radius.
// ---------------------------------------------------------------------------
LcarsRect {
    id: root

    property bool capLeft: false
    property bool capRight: false
    property real round: 0

    radiusTL: capLeft ? height / 2 : round
    radiusBL: capLeft ? height / 2 : round
    radiusTR: capRight ? height / 2 : round
    radiusBR: capRight ? height / 2 : round
}
