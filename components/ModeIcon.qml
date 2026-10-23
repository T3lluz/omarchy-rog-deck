import QtQuick
import QtQuick.Shapes

// The power mode, drawn rather than typed so it can move: Silent is a leaf
// that sways, Balanced a gauge whose needle idles around the middle, Turbo a
// flame that flickers over an ember in the accent colour. Outlines follow
// Tabler's 2px round strokes on a 24px grid, like the rest of ROG Deck's
// drawn icons.
//
// Motion comes from one clock at about 20 frames a second rather than an
// animation per frame, so a bar on three monitors redraws a 16px square a
// handful of times a second, not 60. `animated` off draws the resting pose.
Item {
  id: root

  // power-profiles-daemon's names: power-saver, balanced, performance.
  property string mode: "balanced"
  property color color: "white"
  property color accent: color
  property real size: 16
  property real weight: 2
  property bool animated: true

  // Seconds of motion so far; every pose is a function of it.
  property real t: 0
  readonly property real s: size / 24
  readonly property real stroke: Math.max(1, weight * s)
  readonly property bool moving: animated && visible && size > 0
  readonly property string shape: mode === "power-saver" || mode === "performance" ? mode : "balanced"

  function wave(period, offset) { return Math.sin(2 * Math.PI * (t / period) + (offset || 0)) }

  implicitWidth: size
  implicitHeight: size

  Timer {
    interval: 50
    repeat: true
    running: root.moving
    onTriggered: root.t += interval / 1000
  }

  // A new mode pops in rather than swapping in place.
  onShapeChanged: popIn.restart()

  Item {
    id: canvas
    anchors.fill: parent
    transformOrigin: Item.Center

    ParallelAnimation {
      id: popIn
      NumberAnimation { target: canvas; property: "scale"; from: 0.6; to: 1; duration: 260; easing.type: Easing.OutBack }
      NumberAnimation { target: canvas; property: "opacity"; from: 0; to: 1; duration: 160 }
    }

    // ------------------------------------------------------------ Silent
    Shape {
      anchors.fill: parent
      visible: root.shape === "power-saver"
      preferredRendererType: Shape.CurveRenderer
      // Sways from the stem, with a quicker flutter on top.
      transform: Rotation {
        origin.x: 5 * root.s
        origin.y: 21 * root.s
        angle: root.moving ? 6 * root.wave(3.2) + 1.5 * root.wave(0.9, 1) : 0
      }

      ShapePath {
        fillColor: "transparent"
        strokeColor: root.color
        strokeWidth: root.stroke
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        scale: Qt.size(root.s, root.s)
        PathSvg { path: "M5 21c.5 -4.5 2.5 -8 7 -10 M9 18c6.218 0 10.5 -3.288 11 -12v-2h-4.014c-9 0 -11.986 4 -12 9c0 1 0 3 2 5h3z" }
      }
    }

    // ---------------------------------------------------------- Balanced
    Shape {
      id: gauge
      anchors.fill: parent
      visible: root.shape === "balanced"
      preferredRendererType: Shape.CurveRenderer

      // Degrees off upright: a slow swing either side of the middle.
      readonly property real angle: root.moving ? (14 * root.wave(2.6) + 3 * root.wave(0.7, 2)) * Math.PI / 180 : 0

      ShapePath {
        fillColor: "transparent"
        strokeColor: root.color
        strokeWidth: root.stroke
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        scale: Qt.size(root.s, root.s)
        // The dial, open at the bottom, with ticks at low, middle and high.
        PathSvg { path: "M4.64 18.25a8.5 8.5 0 1 1 14.72 0 M12 5.5v1.6 M5.9 9.6l1.3 .9 M18.1 9.6l-1.3 .9" }
      }

      ShapePath {
        fillColor: "transparent"
        strokeColor: root.color
        strokeWidth: root.stroke
        capStyle: ShapePath.RoundCap
        scale: Qt.size(root.s, root.s)
        startX: 12; startY: 14
        PathLine { x: 12 + 6 * Math.sin(gauge.angle); y: 14 - 6 * Math.cos(gauge.angle) }
      }

      ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        strokeWidth: 0
        scale: Qt.size(root.s, root.s)
        startX: 13.6; startY: 14
        PathArc { x: 10.4; y: 14; radiusX: 1.6; radiusY: 1.6 }
        PathArc { x: 13.6; y: 14; radiusX: 1.6; radiusY: 1.6 }
      }
    }

    // ------------------------------------------------------------- Turbo
    Shape {
      id: flame
      anchors.fill: parent
      visible: root.shape === "performance"
      preferredRendererType: Shape.CurveRenderer
      // Breathes up and down from its base.
      transform: Scale {
        origin.x: 12 * root.s
        origin.y: 21 * root.s
        yScale: root.moving ? 1 + 0.035 * root.wave(0.43) : 1
      }

      // Uneven periods so the flicker never visibly repeats.
      readonly property real tipX: root.moving ? 0.8 * root.wave(0.53) + 0.4 * root.wave(0.31, 1) : 0
      readonly property real tipY: root.moving ? 0.7 * root.wave(0.47, 1) : 0
      readonly property real lickX: root.moving ? 0.5 * root.wave(0.67, 3) : 0
      readonly property real lickY: root.moving ? 0.9 * root.wave(0.61, 2) : 0
      readonly property real coreY: root.moving ? 0.7 * root.wave(0.37) : 0

      // The ember, under the outline.
      ShapePath {
        fillColor: root.accent
        strokeColor: "transparent"
        strokeWidth: 0
        scale: Qt.size(root.s, root.s)
        startX: 12; startY: 19.6
        PathCubic { control1X: 10.2; control1Y: 19.6; control2X: 9.2; control2Y: 18.4; x: 9.2; y: 16.9 }
        PathCubic { control1X: 9.2; control1Y: 15.2; control2X: 11.1; control2Y: 14.1; x: 11.8 + flame.tipX * 0.3; y: 12.2 + flame.coreY }
        PathCubic { control1X: 12.9; control1Y: 13.9; control2X: 14.8; control2Y: 15.1; x: 14.8; y: 16.9 }
        PathCubic { control1X: 14.8; control1Y: 18.4; control2X: 13.8; control2Y: 19.6; x: 12; y: 19.6 }
      }

      // Tabler's flame, with the tip and the side lick free to move.
      ShapePath {
        fillColor: "transparent"
        strokeColor: root.color
        strokeWidth: root.stroke
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        scale: Qt.size(root.s, root.s)
        startX: 12; startY: 10.941
        PathCubic { control1X: 14.333; control1Y: 7.633; control2X: 12.167 + flame.tipX * 0.6; control2Y: 3.118 + flame.tipY * 0.6; x: 11 + flame.tipX; y: 2 + flame.tipY }
        PathCubic { control1X: 11 + flame.tipX * 0.6; control1Y: 5.395 + flame.tipY * 0.4; control2X: 8.765; control2Y: 7.299; x: 7.333; y: 8.706 }
        PathCubic { control1X: 5.903; control1Y: 10.114; control2X: 5; control2Y: 12.327; x: 5; y: 14.294 }
        PathCubic { control1X: 5; control1Y: 17.998; control2X: 8.134; control2Y: 21; x: 12; y: 21 }
        PathCubic { control1X: 15.866; control1Y: 21; control2X: 19; control2Y: 17.998; x: 19; y: 14.294 }
        PathCubic { control1X: 19; control1Y: 12.582; control2X: 17.768; control2Y: 9.891 + flame.lickY * 0.5; x: 16.667 + flame.lickX; y: 8.706 + flame.lickY }
        PathCubic { control1X: 14.583 + flame.lickX * 0.5; control1Y: 12.059 + flame.lickY * 0.3; control2X: 13.41; control2Y: 12.059; x: 12; y: 10.941 }
      }
    }
  }
}
