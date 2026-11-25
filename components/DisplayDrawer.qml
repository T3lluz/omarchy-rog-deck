import QtQuick
import qs.Commons

// The display room opened: the refresh rate (Auto follows the charger), the
// panel's overdrive and its power saving, and the bar switch.
Column {
  id: drawer

  required property var host
  readonly property var service: host.service
  readonly property var status: host.status
  readonly property var display: status && status.display ? status.display : null
  readonly property var armoury: status && status.armoury ? status.armoury : ({})
  readonly property var saver: service ? service.settings.saver : ({ enabled: false, wifi: true })
  readonly property var screenSaving: status && status.saver ? status.saver.screen : null
  readonly property color tone: host.toneOf("display")

  function armouryOn(name) {
    var attr = armoury[name]
    return attr && service ? Number(service.pick("armoury." + name, attr.value)) === 1 : false
  }

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  ChoiceRow {
    host: drawer.host
    visible: !!drawer.display
    tone: drawer.tone
    options: [{ value: "auto", label: "Auto", pixel: "reload", hint: "The top rate when plugged in, 60 Hz on battery" }]
      .concat((drawer.display ? drawer.display.rates : []).map(function(r) { return { value: String(r), label: r + " Hz" } }))
    value: drawer.service && drawer.service.settings.refresh
      ? drawer.service.settings.refresh
      : String(drawer.service && drawer.display ? drawer.service.pick("display.refresh", drawer.display.refresh) : "")
    onPicked: function(v) { drawer.service.setRefreshMode(v) }
  }

  SwitchRow {
    width: parent.width
    visible: !!drawer.armoury.panel_overdrive
    icon: ""
    label: "Panel overdrive"
    hint: "Faster pixel response, less ghosting" + (drawer.saver.enabled ? ". Off on battery (Battery saver)" : "")
    checked: drawer.armouryOn("panel_overdrive")
    foreground: drawer.host.fg
    accent: drawer.tone
    fontFamily: drawer.host.fontFamily
    onToggled: drawer.service.setArmoury("panel_overdrive", checked ? 0 : 1)
  }

  SwitchRow {
    width: parent.width
    visible: !!drawer.screenSaving && drawer.screenSaving.available
    interactive: drawer.saver.enabled
    icon: ""
    label: "Screen power saving"
    hint: {
      var s = drawer.screenSaving
      if (!drawer.saver.enabled) return "Part of Battery saver, in the battery room"
      if (s && s.level > 0) return "Saving now: less backlight power, less accurate colours"
      return "On battery: less backlight power, less accurate colours"
    }
    checked: drawer.saver.enabled && drawer.saver.screen
    foreground: drawer.host.fg
    accent: drawer.tone
    fontFamily: drawer.host.fontFamily
    onToggled: drawer.service.setScreenSaving(!checked)
  }

  RoomPicks {
    host: drawer.host
    tone: drawer.tone
    stats: ["refresh"]
  }
}
