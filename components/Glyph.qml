import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Rooms.js" as Rooms

// The icon in every part of the panel kit. The kit hands it a Nerd Font
// glyph, `icon` being the character. Where the glyph has a pixel icon
// (Rooms.PIXEL_GLYPHS) that is drawn instead, so the kit's icons match the
// rooms'; anything else is typed. The other kit files are the same in all
// four plugins; this one is each plugin's own.
Item {
  id: glyph

  property string icon: ""
  property real size: Style.font.body
  property color color: Commons.Color.foreground
  property string fontFamily: Style.font.family

  // A banner at work (Notice's `busy`: an update installing) has no icon of
  // its own that turns, so it shows the reload arrows going round a quarter
  // at a time. Notice is the glyph's parent and no longer spins it.
  readonly property bool busy: !!parent && parent.busy === true
  readonly property string pixel: busy ? "reload" : Rooms.pixelFor(icon)

  implicitWidth: size
  implicitHeight: size

  // Plays as its page comes into view, top to bottom, and again when the
  // kit swaps its glyph (a switch flipping).
  PixelIcon {
    id: pixelIcon
    visible: glyph.pixel !== ""
    playOnShow: true
    showDelay: Math.min(420, Math.max(0, Math.round(glyph.mapToItem(null, 0, 0).y * 0.6)))
    onNameChanged: play(0)
    anchors.centerIn: parent
    name: glyph.pixel
    size: glyph.size
    color: glyph.color
    loop: glyph.busy ? "turn" : ""
    loopEvery: 300
  }

  Text {
    visible: glyph.pixel === ""
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: glyph.icon
    color: glyph.color
    // The typed glyphs are Nerd Font icons, which only the shell's font has;
    // Monocraft would leave them to a random fallback.
    font.family: Style.font.family
    font.pixelSize: glyph.size
  }
}
