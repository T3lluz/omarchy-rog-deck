import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// The battery room opened: the power flowing, where charging stops, a
// one-off charge to full, Battery saver, and the bar switch.
Column {
  id: drawer

  required property var host
  readonly property var service: host.service
  readonly property var status: host.status
  readonly property var battery: status && status.battery ? status.battery : null
  readonly property int limit: battery && service ? service.pick("battery.limit", battery.limit) || 100 : 100
  readonly property var saver: service ? service.settings.saver : ({ enabled: false, wifi: true })
  readonly property color tone: host.toneOf("battery")

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  // What flows in or out, and what the kernel says it is doing.
  Facts {
    host: drawer.host
    facts: Model.batteryFacts(drawer.battery, !!drawer.status && drawer.status.ac)
  }

  LevelPick {
    host: drawer.host
    visible: !!drawer.battery && drawer.battery.limit !== null
    label: "Stop charging at"
    value: drawer.limit
    from: 0
    to: 100
    step: 5
    floor: 20
    segments: 10
    unit: "%"
    tone: drawer.tone
    onCommitted: function(v) { drawer.service.setChargeLimit(Math.max(20, Math.min(100, Math.round(v)))) }
  }

  Item {
    width: parent.width
    visible: !!drawer.battery && drawer.battery.limit !== null
    height: Math.max(onceButton.visible ? onceButton.implicitHeight : 0, onceText.implicitHeight)

    Caption {
      id: onceText
      anchors.left: parent.left
      anchors.right: onceButton.visible ? onceButton.left : parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: drawer.limit < 100 ? "Holding below full spares the battery. About 80% suits a laptop that stays plugged in."
                               : "Charges to full every time."
      foreground: drawer.host.fg
      fontFamily: drawer.host.fontFamily
    }

    Button {
      id: onceButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: drawer.limit < 100
      text: "Full once"
      tooltipText: "Charge to 100% this time only, then go back to the limit"
      fontSize: Style.font.bodySmall
      foreground: drawer.host.fg
      fontFamily: drawer.host.fontFamily
      bordered: true
      onClicked: drawer.service.chargeOnce()
    }
  }

  SwitchRow {
    width: parent.width
    icon: ""
    label: "Battery saver"
    hint: "On battery: 60 Hz, panel overdrive off, screen power saving" + (drawer.saver.wifi ? ", Wi-Fi power save" : "")
      + ". All back when plugged in"
    checked: drawer.saver.enabled
    foreground: drawer.host.fg
    accent: drawer.tone
    fontFamily: drawer.host.fontFamily
    onToggled: drawer.service.setSaver(!checked)
  }

  RoomPicks {
    host: drawer.host
    tone: drawer.tone
    stats: ["battery"]
  }
}
