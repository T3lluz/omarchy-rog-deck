import QtQuick
import qs.Commons
import qs.Ui

// The panel's main page: the title in a room of its own, the banners, then a
// room for each part of the laptop this one has, two to a row where they are
// small: the power mode, the battery and the fans, the screen and the
// graphics, the keyboard light and the AniMe Matrix. A row with one room
// gives it the whole width. Panel.qml shows it; the offscreen audit renders
// it on its own.
Column {
  id: page

  required property var host

  spacing: host.roomGap

  // The title in a neutral room of its own, so the top-left corner is
  // a room like the rest.
  Room {
    id: heroRoom
    host: page.host
    tone: page.host.fg
    clickable: false

    HeroBlock {
      width: parent.width
      host: page.host
      icon: "fire"
      iconColor: page.host.toneOf("mark")
      markSize: Math.round(Style.font.title * 1.5)
      keepLines: 1
      title: "ROG Deck"
      line: page.host.heroLine
      lineColor: page.host.gpuAsk !== "" || (page.host.status && !page.host.ready) ? page.host.lowTone : Qt.darker(page.host.fg, 1.3)

      PixelButton {
        icon: "settings-cog"
        angle: Math.round(page.host.gearTurn * -2) * 45
        tooltipText: "Settings (s)"
        foreground: page.host.fg
        fontFamily: page.host.fontFamily
        onClicked: page.host.setView("settings")
      }
    }
  }

  // Errors, a GPU switch waiting on a restart, and updates, the panel
  // kit's banners, above the rooms so they can't be missed.
  Column {
    width: parent.width
    spacing: Style.space(6)
    topPadding: Style.space(3)
    bottomPadding: Style.space(3)
    visible: page.host.notices.length > 0

    Repeater {
      model: page.host.notices

      Notice {
        required property var modelData
        width: page.width
        icon: modelData.icon || ""
        text: modelData.text
        tone: modelData.tone || "accent"
        actionLabel: modelData.actionLabel || ""
        busy: !!modelData.busy
        dismissable: !!modelData.dismissable
        foreground: page.host.fg
        accent: page.host.accent
        urgent: page.host.urgent
        fontFamily: page.host.fontFamily
        onActioned: page.host.noticeAction(modelData)
        onDismissed: if (page.host.service) page.host.service.dismissNotice(modelData)
      }
    }
  }

  PowerRoom {
    host: page.host
    visible: page.host.ready && page.host.profiles.length > 0
    delay: 70
  }

  // The CPU and GPU take most of a row; the fans and the battery are two
  // tiles stacked into a square beside them. Then two rooms to a row: the
  // graphics and the display, the keyboard and the AniMe Matrix. A room
  // missing on this laptop leaves its neighbours the space; an open room's
  // drawer runs the width of the row under it. Two rooms sharing a row share
  // a header height, so their names and what sits under them line up.
  Column {
    width: parent.width
    visible: page.host.ready && (page.host.hasHeat || page.host.hasFans || page.host.hasBattery)

    Row {
      id: row1
      readonly property bool tiles: page.host.hasFans || page.host.hasBattery
      readonly property bool both: page.host.hasFans && page.host.hasBattery
      // Beside the CPU and GPU the tiles stack; without it they share the row.
      readonly property bool stacked: page.host.hasHeat
      readonly property real stackHeight: (page.host.hasFans ? fansRoom.implicitHeight : 0)
        + (page.host.hasBattery ? batteryRoom.implicitHeight : 0) + (both ? spacing : 0)
      readonly property real rowHeight: Math.max(page.host.hasHeat ? heatRoom.implicitHeight : 0,
        stacked ? stackHeight : Math.max(page.host.hasFans ? fansRoom.implicitHeight : 0, page.host.hasBattery ? batteryRoom.implicitHeight : 0))
      // A square, or wider where a tile's figure needs it.
      readonly property real stackWidth: !tiles ? 0 : !page.host.hasHeat ? width
        : Math.max(rowHeight, page.host.hasFans ? fansRoom.naturalWidth : 0, page.host.hasBattery ? batteryRoom.naturalWidth : 0)
      readonly property real tileHeight: stacked && both ? (rowHeight - spacing) / 2 : rowHeight
      readonly property real tileWidth: stacked || !both ? stackWidth : (stackWidth - spacing) / 2
      width: parent.width
      spacing: page.host.roomGap

      HeatRoom {
        id: heatRoom
        host: page.host
        visible: page.host.hasHeat
        width: row1.tiles ? row1.width - row1.stackWidth - row1.spacing : row1.width
        height: row1.rowHeight
        delay: 140
      }

      Grid {
        visible: row1.tiles
        columns: row1.stacked ? 1 : 2
        spacing: row1.spacing

        FansRoom { id: fansRoom; host: page.host; visible: page.host.hasFans; width: row1.tileWidth; height: row1.tileHeight; delay: 210 }
        BatteryRoom { id: batteryRoom; host: page.host; visible: page.host.hasBattery; width: row1.tileWidth; height: row1.tileHeight; delay: 260 }
      }
    }

    PairDrawer {
      id: drawer1
      host: page.host
      keys: ["heat", "fans", "battery"]

      HeatDrawer { host: page.host; visible: drawer1.shownKey === "heat" }
      FansDrawer { host: page.host; visible: drawer1.shownKey === "fans" }
      BatteryDrawer { host: page.host; visible: drawer1.shownKey === "battery" }
    }
  }

  Column {
    width: parent.width
    visible: page.host.ready && (page.host.hasGraphics || page.host.hasDisplay)

    Row {
      id: row2
      readonly property bool both: page.host.hasGraphics && page.host.hasDisplay
      readonly property real cellWidth: both ? (width - spacing) / 2 : width
      readonly property real headerHeight: Math.max(page.host.hasGraphics ? graphicsRoom.headerNatural : 0, page.host.hasDisplay ? displayRoom.headerNatural : 0)
      readonly property real rowHeight: Math.max(page.host.hasGraphics ? graphicsRoom.implicitHeight : 0, page.host.hasDisplay ? displayRoom.implicitHeight : 0)
      width: parent.width
      spacing: page.host.roomGap

      GraphicsRoom { id: graphicsRoom; host: page.host; visible: page.host.hasGraphics; width: row2.cellWidth; height: row2.rowHeight; headerMin: row2.headerHeight; delay: 280 }
      DisplayRoom { id: displayRoom; host: page.host; visible: page.host.hasDisplay; width: row2.cellWidth; height: row2.rowHeight; headerMin: row2.headerHeight; delay: 350 }
    }

    PairDrawer {
      id: drawer2
      host: page.host
      keys: ["graphics", "display"]

      GraphicsDrawer { host: page.host; visible: drawer2.shownKey === "graphics" }
      DisplayDrawer { host: page.host; visible: drawer2.shownKey === "display" }
    }
  }

  Column {
    width: parent.width
    visible: page.host.ready && (page.host.hasKeyboard || page.host.hasAnime)

    Row {
      id: row3
      readonly property bool both: page.host.hasKeyboard && page.host.hasAnime
      readonly property real cellWidth: both ? (width - spacing) / 2 : width
      readonly property real headerHeight: Math.max(page.host.hasKeyboard ? keyboardRoom.headerNatural : 0, page.host.hasAnime ? animeRoom.headerNatural : 0)
      readonly property real rowHeight: Math.max(page.host.hasKeyboard ? keyboardRoom.implicitHeight : 0, page.host.hasAnime ? animeRoom.implicitHeight : 0)
      width: parent.width
      spacing: page.host.roomGap

      KeyboardRoom { id: keyboardRoom; host: page.host; visible: page.host.hasKeyboard; width: row3.cellWidth; height: row3.rowHeight; headerMin: row3.headerHeight; delay: 420 }
      AnimeRoom { id: animeRoom; host: page.host; visible: page.host.hasAnime; width: row3.cellWidth; height: row3.rowHeight; headerMin: row3.headerHeight; delay: 490 }
    }

    PairDrawer {
      id: drawer3
      host: page.host
      keys: ["keyboard", "anime"]

      KeyboardDrawer { host: page.host; visible: drawer3.shownKey === "keyboard" }
      AnimeDrawer { host: page.host; visible: drawer3.shownKey === "anime" }
    }
  }
}
