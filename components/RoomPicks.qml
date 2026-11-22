import QtQuick
import qs.Commons
import "../Model.js" as Model

// An open room's switches for what of it the bar shows: the same picks as
// the settings page, here beside the reading they put in the bar.
Column {
  id: picks

  required property var host
  // The Model.BAR_STATS stats this room owns.
  property var stats: []
  property color tone: host.fg
  readonly property var list: Model.BAR_STATS.filter(function(s) { return picks.stats.indexOf(s.stat) !== -1 })

  visible: list.length > 0
  width: parent ? parent.width : 0
  spacing: Style.space(6)

  Repeater {
    model: picks.list

    SwitchRow {
      required property var modelData
      readonly property bool on: picks.host.setting(modelData.key, modelData.fallback) === true
      width: picks.width
      // No icon: the label says it all, and the room's own icon is above.
      icon: ""
      label: modelData.label + " in the bar"
      hint: modelData.hint || ""
      checked: on
      foreground: picks.host.fg
      accent: picks.tone
      fontFamily: picks.host.fontFamily
      onToggled: picks.host.setBarStat(modelData.key, !on)
    }
  }
}
