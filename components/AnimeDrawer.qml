import QtQuick
import qs.Commons
import "../Model.js" as Model

// The AniMe room opened: the banner or the ROG logo, and when the display
// turns itself off. The startup, sleep and shutdown animations are on the
// settings page.
Column {
  id: drawer

  required property var host
  readonly property var service: host.service
  readonly property var anime: host.status && host.status.anime ? host.status.anime : ({ builtins: {} })
  readonly property string awake: service ? service.pick("anime.awake", (anime.builtins || {}).awake) || "" : ""
  readonly property bool offWhenSuspended: service ? !!service.pick("anime.option.suspended", anime.offWhenSuspended) : false
  readonly property color tone: host.toneOf("anime")

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  ChoiceRow {
    host: drawer.host
    tone: drawer.tone
    options: Model.ANIME_CONTENT.map(function(c) { return { value: c.builtin, label: c.label, pixel: c.pixel, hint: c.hint } })
    value: drawer.awake
    onPicked: function(v) {
      for (var i = 0; i < Model.ANIME_CONTENT.length; i++)
        if (Model.ANIME_CONTENT[i].builtin === v) drawer.service.setAnimeContent(Model.ANIME_CONTENT[i].value)
    }
  }

  SwitchRow {
    width: parent.width
    icon: ""
    label: "Off on battery"
    checked: drawer.service ? !!drawer.service.pick("anime.option.unplugged", drawer.anime.offWhenUnplugged) : false
    foreground: drawer.host.fg
    accent: drawer.tone
    fontFamily: drawer.host.fontFamily
    onToggled: drawer.service.setAnimeOption("unplugged", !checked)
  }

  SwitchRow {
    width: parent.width
    icon: ""
    label: "Off while the laptop sleeps"
    hint: drawer.offWhenSuspended ? "Turn this off to see the sleep animation" : "The sleep animation plays while suspended"
    checked: drawer.offWhenSuspended
    foreground: drawer.host.fg
    accent: drawer.tone
    fontFamily: drawer.host.fontFamily
    onToggled: drawer.service.setAnimeOption("suspended", !checked)
  }

  SwitchRow {
    width: parent.width
    icon: ""
    label: "Off with the lid closed"
    checked: drawer.service ? !!drawer.service.pick("anime.option.lid", drawer.anime.offWhenLidClosed) : false
    foreground: drawer.host.fg
    accent: drawer.tone
    fontFamily: drawer.host.fontFamily
    onToggled: drawer.service.setAnimeOption("lid", !checked)
  }
}
