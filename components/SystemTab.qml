import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// Battery limit, display, FN-lock, firmware switches and the GPU.
Column {
  id: tab

  property var deck: null
  readonly property var service: deck ? deck.service : null
  readonly property var status: deck ? deck.status : null
  readonly property var battery: status && status.battery ? status.battery : null
  readonly property var display: status && status.display ? status.display : null
  readonly property var armoury: status && status.armoury ? status.armoury : ({})
  readonly property int limit: battery && service ? service.pick("battery.limit", battery.limit) || 100 : 100
  readonly property bool fnlockAvailable: !!(status && status.fnlock && status.fnlock.available)
  readonly property var gpu: status && status.gpu ? status.gpu : null
  readonly property string gpuNext: gpu && service ? String(service.pick("gpu.next", gpu.next)) : ""
  readonly property bool gpuPending: !!gpu && gpuNext !== gpu.mode

  function armouryOn(name) {
    var attr = armoury[name]
    return attr && service ? Number(service.pick("armoury." + name, attr.value)) === 1 : false
  }

  spacing: Style.space(12)

  // ---------- Battery ----------
  SectionHeader {
    icon: tab.status && tab.status.ac ? "󰂄" : "󰁹"
    title: "BATTERY"
    detail: tab.battery ? (Model.batteryLine(tab.battery, tab.status.ac) + (tab.battery.status ? " · " + tab.battery.status : "")).toUpperCase() : ""
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    visible: !!tab.battery && tab.battery.limit !== null
  }

  Column {
    width: parent.width
    spacing: Style.space(10)
    visible: !!tab.battery && tab.battery.limit !== null

    SliderField {
      width: parent.width
      label: "Charge limit (%)"
      from: 20
      to: 100
      step: 1
      showField: true
      value: tab.limit
      bar: tab.deck.bar
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      onCommitted: function(v) { tab.service.setChargeLimit(Math.max(20, Math.min(100, Math.round(v)))) }
    }

    Seg {
      width: parent.width
      options: [
        { value: 60, label: "60%", icon: "󰁿", hint: "Plugged in most of the time" },
        { value: 80, label: "80%", icon: "󰂁", hint: "A good everyday balance" },
        { value: 100, label: "100%", icon: "󰁹", hint: "Full charge" }
      ]
      value: tab.limit
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      onPicked: function(v) { tab.service.setChargeLimit(v) }
    }

    Item {
      width: parent.width
      height: Math.max(onceButton.visible ? onceButton.implicitHeight : 0, onceText.implicitHeight)

      Text {
        id: onceText
        anchors.left: parent.left
        anchors.right: onceButton.visible ? onceButton.left : parent.right
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: tab.limit < 100 ? "Stops at " + tab.limit + "% to spare the battery." : "Charges to full."
        color: tab.deck.fg
        opacity: 0.55
        font.family: tab.deck.fontFamily
        font.pixelSize: Style.font.caption
      }

      Button {
        id: onceButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: tab.limit < 100
        text: "Full once"
        iconText: "󰂅"
        tooltipText: "Charge to 100% this time only, then go back to the limit"
        fontSize: Style.font.bodySmall
        foreground: tab.deck.fg
        fontFamily: tab.deck.fontFamily
        bordered: true
        onClicked: tab.service.chargeOnce()
      }
    }
  }

  // ---------- Display ----------
  PanelSeparator { foreground: tab.deck.fg; visible: !!tab.display }

  SectionHeader {
    icon: "󰍹"
    title: "DISPLAY"
    detail: tab.display ? (tab.service ? tab.service.pick("display.refresh", tab.display.refresh) : tab.display.refresh) + " HZ" : ""
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    visible: !!tab.display
  }

  Seg {
    width: parent.width
    visible: !!tab.display
    options: [{ value: "auto", label: "Auto", icon: "󰁪", hint: "Highest when plugged in, 60 Hz on battery" }]
      .concat((tab.display ? tab.display.rates : []).map(function(r) { return { value: String(r), label: r + " Hz" } }))
    value: tab.service && tab.service.settings.refresh
      ? tab.service.settings.refresh
      : String(tab.service && tab.display ? tab.service.pick("display.refresh", tab.display.refresh) : "")
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onPicked: function(v) { tab.service.setRefreshMode(v) }
  }

  SwitchRow {
    width: parent.width
    visible: !!tab.armoury.panel_overdrive
    icon: "󱐋"
    label: "Panel overdrive"
    hint: "Faster pixel response, less ghosting"
    checked: tab.armouryOn("panel_overdrive")
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setArmoury("panel_overdrive", checked ? 0 : 1)
  }

  // ---------- Keyboard and firmware ----------
  PanelSeparator { foreground: tab.deck.fg }

  SectionHeader {
    icon: "󰒓"
    title: "KEYBOARD AND FIRMWARE"
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
  }

  SwitchRow {
    width: parent.width
    interactive: tab.fnlockAvailable
    icon: "󰌾"
    label: "FN-lock"
    hint: tab.fnlockAvailable ? "Action row does its printed media actions; hold Fn for F1–F12. Shift+Esc toggles too"
                              : "Not set up: needs the fnlock command (see the README)"
    checked: tab.fnlockAvailable && tab.service ? !!tab.service.pick("fnlock", tab.status.fnlock.on) : false
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setFnlock(!checked)
  }

  SwitchRow {
    width: parent.width
    visible: !!tab.armoury.boot_sound
    icon: "󰕾"
    label: "Boot sound"
    hint: "The chime when the laptop powers on"
    checked: tab.armouryOn("boot_sound")
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onToggled: tab.service.setArmoury("boot_sound", checked ? 0 : 1)
  }

  // ---------- GPU ----------
  PanelSeparator { foreground: tab.deck.fg; visible: !!tab.gpu }

  SectionHeader {
    icon: "󰢮"
    title: "GRAPHICS"
    detail: tab.gpu ? (Model.gpuModeInfo(tab.gpu.mode).label + " · NVIDIA " + Model.dgpuLabel(tab.status.dgpu)).toUpperCase() : ""
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    visible: !!tab.gpu
  }

  Seg {
    width: parent.width
    visible: !!tab.gpu
    options: Model.gpuModes(tab.gpu)
    value: tab.gpuNext
    foreground: tab.deck.fg
    fontFamily: tab.deck.fontFamily
    onPicked: function(v) { tab.deck.askGpuMode(v) }
  }

  Item {
    width: parent.width
    height: Math.max(restartButton.visible ? restartButton.implicitHeight : 0, gpuText.implicitHeight)
    visible: !!tab.gpu

    Text {
      id: gpuText
      anchors.left: parent.left
      anchors.right: restartButton.visible ? restartButton.left : parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      text: tab.gpuPending
        ? "Starts in " + Model.gpuModeInfo(tab.gpuNext).label + " mode after the next restart."
        : Model.gpuModeInfo(tab.gpuNext).hint + ". Switching restarts the laptop."
      color: tab.deck.fg
      opacity: 0.55
      font.family: tab.deck.fontFamily
      font.pixelSize: Style.font.caption
    }

    Button {
      id: restartButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: tab.gpuPending
      text: "Restart now"
      iconText: "󰜉"
      tooltipText: "Restart to finish switching GPU mode"
      fontSize: Style.font.bodySmall
      foreground: tab.deck.fg
      fontFamily: tab.deck.fontFamily
      bordered: true
      onClicked: tab.deck.askGpuMode(tab.gpuNext)
    }
  }
}
