import QtQuick
import qs.Commons
import "../Model.js" as Model
import "Rooms.js" as Rooms

// The power mode: its CPU icon, its name over what the charger and the mode's
// own option are doing, and the package power in the block face. The modes
// sit in the room as cells, one click each. Opening the room shows what the
// running mode adds (Silent's CPU limit, Balanced's full speed), what
// Omarchy puts back on each power source, and its bar switches.
Room {
  id: room

  readonly property var service: host.service
  readonly property var status: host.status
  readonly property var info: Model.profileInfo(host.activeProfile)
  readonly property var watts: status && status.watts ? status.watts : ({})
  readonly property var power: status && status.power ? status.power : null
  readonly property var limit: service ? service.settings.powerLimit : ({ enabled: false, watts: 15 })
  readonly property bool limitShown: !!power && power.supported && !!power.slider && host.activeProfile === "power-saver"
  readonly property var limitTriple: limitShown
    ? Model.pptTriple(Model.powerLimitWatts({ powerLimit: { enabled: true, watts: limit.watts } }, "power-saver", power), power.ranges) : null
  readonly property var speed: status && status.speed ? status.speed : null
  readonly property string helper: power ? power.helper : "missing"
  readonly property bool speedEnabled: !!service && service.settings.fullSpeed.enabled
  readonly property bool speedShown: !!speed && !!speed.epp && host.activeProfile === "balanced"
  // The charger as the service sees it, so the words and what is applied agree.
  readonly property bool onAc: !!service && !service.onBattery
  readonly property var ctx: ({
    ac: onAc,
    saverActive: !!service && service.saverActive,
    profile: host.activeProfile,
    speed: speed,
    speedOn: speedEnabled && helper === "ok",
    limit: limit,
    limitShown: limitShown
  })
  readonly property var saved: status && status.profile ? status.profile.saved : null

  tone: host.toneOf("power")
  headerNatural: header.naturalHeight
  expanded: host.openRoom === "power"
  onClicked: host.toggleRoom("power")

  // A new mode grows or shrinks the CPU's core, and the icon hops.
  Connections {
    target: room.host
    function onActiveProfileChanged() { if (room.host.opened) room.story++ }
  }

  RoomHeader {
    id: header
    host: room.host
    minHeight: room.headerMin
    icon: room.info.pixel
    tone: room.tone
    title: room.info.label
    status: Model.powerState(room.ctx)
    value: room.watts.igpu
    suffix: "W"
    mark: Model.powerMark(room.ctx)
    expanded: room.expanded
    delay: room.delay + 120
    story: Rooms.storyOf("power")
    tick: room.story
  }

  ChoiceRow {
    host: room.host
    tone: room.tone
    options: room.host.profiles.map(function(p) { return { value: p.key, label: p.label, pixel: p.pixel, hint: p.hint } })
    value: room.host.activeProfile
    keyed: room.host.cursorActive && room.host.view === "rooms" ? room.host.profileCursor : -1
    onPicked: function(v) { if (room.service) room.service.setProfile(v) }
  }

  Drawer {
    open: room.expanded
    spacing: Style.space(10)

    // Silent: hold the CPU under the firmware's own limit.
    SwitchRow {
      width: parent.width
      visible: room.limitShown
      icon: ""
      label: "CPU power limit"
      hint: {
        if (!room.limit.enabled) return "Hold Silent under the firmware's own limit" + (room.power && room.power.helper !== "ok" ? ". Asks for your password once" : "")
        return Model.limitCaption(room.limitTriple) + ". Runs Silent's custom fan curve, which the firmware needs for limits"
      }
      checked: room.limit.enabled
      foreground: room.host.fg
      accent: room.tone
      fontFamily: room.host.fontFamily
      onToggled: room.service.setPowerLimit(!checked, null)
    }

    LevelPick {
      host: room.host
      visible: room.limitShown && room.limit.enabled
      label: "Silent holds the CPU to"
      value: room.limit.watts
      from: room.power && room.power.slider ? room.power.slider[0] : 15
      to: room.power && room.power.slider ? room.power.slider[1] : 35
      step: 1
      segments: 10
      unit: " W"
      tone: room.tone
      onCommitted: function(v) { room.service.setPowerLimit(true, Math.round(v)) }
    }

    // Balanced: clock up at once on the charger.
    SwitchRow {
      width: parent.width
      visible: room.speedShown
      icon: ""
      label: "Full speed when plugged in"
      hint: Model.speedHint(room.speedEnabled, room.helper, room.onAc, room.speed ? room.speed.epp : null)
      // Shown as it acts: off without a working helper, whatever is saved.
      // A click then saves "on" and sets the helper up.
      checked: room.speedEnabled && room.helper === "ok"
      foreground: room.host.fg
      accent: room.tone
      fontFamily: room.host.fontFamily
      onToggled: room.service.setFullSpeed(!checked)
    }

    Caption {
      width: parent.width
      visible: !room.limitShown && !room.speedShown
      text: room.info.hint ? room.info.hint + "." : ""
      foreground: room.host.fg
      fontFamily: room.host.fontFamily
    }

    Facts {
      host: room.host
      facts: {
        var list = []
        // What Omarchy puts back when the charger comes and goes.
        if (room.saved && room.saved.ac) list.push({ label: "Plugged in", value: Model.profileInfo(room.saved.ac).label })
        if (room.saved && room.saved.battery) list.push({ label: "On battery", value: Model.profileInfo(room.saved.battery).label })
        return list
      }
    }

    RoomPicks {
      host: room.host
      tone: room.tone
      stats: ["mode", "power"]
    }
  }
}
