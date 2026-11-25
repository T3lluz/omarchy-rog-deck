import QtQuick
import QtQuick.Window
import qs.Commons
import "Pixels.js" as Pixels
import "Motion.js" as Motion

// A pixel icon from Pixels.js, drawn as rectangles on whole device pixels so
// it stays sharp at any scale. The icon comes out as close to `size` as the
// grid allows: the 24-unit grid where a unit gets whole device pixels, the
// same grid halved (12 cells) where it would not. On a 1.25 scale a 14 px
// request draws 12 device pixels; a 20 px one draws 24.
// Never scaled: a fractional scale only ever picks the nearest sharp size.
// The cells are laid from a whole device pixel: at 1.25 a cell is exactly one
// device pixel, and from half a pixel off rounding doubled some strokes and
// dropped others, so a dense icon (the CPU) came out a blob.
//
// It also plays the icon's motion (Motion.js): `play()` acts it out once,
// and `loop` keeps it going off the shared clock while something is live
// (the fans spinning, a hot reading, a battery charging). Its moving parts
// shift in whole cells of the 12-cell grid and swap frames; nothing is
// scaled or turned off the quarter turns, so the art stays sharp. Nothing
// ticks while the icon is hidden or its window is closed.
Item {
  id: icon

  property string name: ""
  // Art drawn elsewhere ({ g12, g24 }, as Pixels.js keeps it), in place of a
  // named icon: the Sonus mark, whose knobs move.
  property var custom: null
  property real size: 16
  property color color: "white"
  // Device pixels per cell of the halved grid, to match other pixel art
  // (PixelText) stroke for stroke; 0 picks it from `size`.
  property int unit: 0
  // A live state that keeps the icon moving: "spin" flips the fan's blades
  // every `loopEvery` ms, "burst" plays the story at the start of every
  // `loopEvery` ms. Empty rests.
  property string loop: ""
  property int loopEvery: 0
  // Plays each time the icon comes into view (its page opens, the card
  // shows), after `showDelay` ms.
  property bool playOnShow: false
  property int showDelay: 0

  readonly property var art: custom || Pixels.icons[name] || null
  readonly property bool moving: !!art && !!art.parts
  // The window's scale, not Screen's: on a 1.25 monitor Screen.devicePixelRatio
  // says 2, and everything snapped for 2x there.
  readonly property real dpr: Window.window && Window.window.devicePixelRatio > 0 ? Window.window.devicePixelRatio : 1
  // Device pixels across, in twelfths: odd counts take the halved grid. Its
  // strokes are this many device pixels thick either way.
  readonly property int twelfths: unit > 0 ? unit : Math.max(1, Math.round(size * dpr / 12))
  readonly property bool fine: twelfths % 2 === 0
  readonly property real cell: (fine ? twelfths / 2 : twelfths) / dpr
  // One cell of the 12-cell grid, the step every motion moves in.
  readonly property real step: fine ? cell * 2 : cell
  readonly property var rects: art ? (moving ? (fine ? art.base.g24 : art.base.g12) : (fine ? art.g24 : art.g12)) : []

  implicitWidth: twelfths * 12 / dpr
  implicitHeight: implicitWidth

  // ---- motion ----------------------------------------------------------------

  property var pose: Motion.REST
  property string poseKey: ""
  property bool playing: false
  property real startedAt: 0
  property real playMs: 0
  readonly property bool shown: visible && !!Window.window && Window.window.visible
  readonly property bool looping: loop !== "" && loopEvery > 0 && !Style.reduceMotion

  // Acts the icon out once, after `delay` ms. A play already running goes
  // on rather than starting over, so a hover never cuts one short.
  function play(delay) {
    if (Style.reduceMotion || !Motion.hasStory(name) || playing) return
    if (delay > 0) {
      wait.interval = delay
      wait.restart()
      return
    }
    playMs = Style.duration(Motion.duration(name))
    if (!(playMs > 0)) return
    startedAt = Date.now()
    playing = true
    frame()
  }

  function frame() {
    var now = Date.now()
    var next = Motion.REST
    var wake = 0
    if (playing) {
      var k = (now - startedAt) / playMs
      if (k >= 1) playing = false
      else {
        next = Motion.poseAt(name, k)
        wake = Motion.storyNext(name, k, playMs)
      }
    }
    if (!playing && looping) {
      var t = now % Motion.LOOP_MS
      next = Motion.loopAt(name, loop, loopEvery, t)
      wake = Motion.loopNext(name, loop, loopEvery, t)
    }
    var key = JSON.stringify(next)
    if (key !== poseKey) {
      poseKey = key
      pose = next
    }
    // Wake when the pose next changes, not on a fixed beat.
    ticker.stop()
    if (wake > 0 && shown) {
      ticker.interval = Math.max(1, Math.round(wake))
      ticker.start()
    }
  }

  onNameChanged: if (!playing) frame()
  onLoopingChanged: frame()
  onLoopEveryChanged: frame()
  onShownChanged: {
    if (!shown) { wait.stop(); playing = false; frame() }
    else if (playOnShow) play(showDelay)
    else frame()
  }

  Timer {
    id: wait
    onTriggered: icon.play(0)
  }

  // Fires once, when the pose next changes (Motion.storyNext, loopNext);
  // frame() aims it again.
  Timer {
    id: ticker
    onTriggered: icon.frame()
  }

  // ---- drawing ---------------------------------------------------------------

  // How far the cells move to start on a whole device pixel, checked before
  // each frame the window draws (it draws only when something changed).
  property real snapX: 0
  property real snapY: 0

  function snap() {
    if (!visible) return
    var p = icon.mapToItem(null, 0, 0)
    var dx = Math.round(p.x * dpr) / dpr - p.x
    var dy = Math.round(p.y * dpr) / dpr - p.y
    if (Math.abs(dx - snapX) > 0.001) snapX = dx
    if (Math.abs(dy - snapY) > 0.001) snapY = dy
  }

  Component.onCompleted: snap()

  Connections {
    target: icon.Window.window
    ignoreUnknownSignals: true
    function onAfterAnimating() { icon.snap() }
  }

  Item {
    x: icon.snapX + icon.pose.x * icon.step
    y: icon.snapY + icon.pose.y * icon.step
    width: icon.implicitWidth
    height: icon.implicitHeight
    visible: !icon.pose.hide
    rotation: icon.pose.turn

    Repeater {
      model: icon.rects

      Rectangle {
        required property var modelData
        x: Math.round(modelData[0] * icon.cell * icon.dpr) / icon.dpr
        y: Math.round(modelData[1] * icon.cell * icon.dpr) / icon.dpr
        width: Math.round(modelData[2] * icon.cell * icon.dpr) / icon.dpr
        height: Math.round(modelData[3] * icon.cell * icon.dpr) / icon.dpr
        color: icon.color
        antialiasing: false
      }
    }

    // Each moving part, every frame laid out and only the current one shown,
    // so a frame change builds nothing.
    Repeater {
      model: icon.moving ? icon.art.parts : []

      Item {
        id: part
        required property var modelData
        readonly property var p: icon.pose.parts[modelData.name] || null
        readonly property int frame: p && p.f !== undefined ? p.f : modelData.rest
        x: p && p.x ? p.x * icon.step : 0
        y: p && p.y ? p.y * icon.step : 0
        visible: !(p && p.hide)

        Repeater {
          model: part.modelData.frames

          Item {
            id: shot
            required property var modelData
            required property int index
            visible: index === part.frame

            Repeater {
              model: icon.fine ? shot.modelData.g24 : shot.modelData.g12

              Rectangle {
                required property var modelData
                x: Math.round(modelData[0] * icon.cell * icon.dpr) / icon.dpr
                y: Math.round(modelData[1] * icon.cell * icon.dpr) / icon.dpr
                width: Math.round(modelData[2] * icon.cell * icon.dpr) / icon.dpr
                height: Math.round(modelData[3] * icon.cell * icon.dpr) / icon.dpr
                color: icon.color
                antialiasing: false
              }
            }
          }
        }
      }
    }
  }
}
