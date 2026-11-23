import QtQuick
import qs.Commons
import "../Model.js" as Model

// The AniMe Matrix on the lid: a button that turns it off and on, then its
// brightness as three cells, each one click. Its drawer (AnimeDrawer) picks
// the picture and when it turns itself off.
Room {
  id: room

  readonly property var service: host.service
  readonly property var anime: host.status ? host.status.anime : null
  readonly property bool enabled: !!anime && !!service && !!service.pick("anime.enabled", anime.enabled)
  readonly property int brightness: anime && service ? Math.max(1, Math.min(3, service.pick("anime.brightness", anime.brightness) || 1)) : 1
  readonly property string awake: anime && service ? service.pick("anime.awake", anime.builtins ? anime.builtins.awake : "") || "" : ""
  readonly property var info: Model.animeRoom(anime, enabled, brightness, awake)

  tone: host.toneOf("anime")
  expanded: host.openRoom === "anime"
  headerNatural: header.naturalHeight
  cells: [fader.meter]
  onClicked: host.toggleRoom("anime")

  RoomHeader {
    id: header
    host: room.host
    minHeight: room.headerMin
    icon: "matrix"
    tone: room.tone
    title: "AniMe Matrix"
    status: room.info.state
    showFigure: false
    dimmed: !room.enabled
    expanded: room.expanded
    delay: room.delay + 120
    tick: room.story
    // The lights come on again when they change.
    cue: room.enabled + "/" + room.brightness
  }

  LightFader {
    id: fader
    host: room.host
    tone: room.tone
    name: "the AniMe Matrix"
    level: room.brightness
    on: room.enabled
    delay: room.delay + 80
    onPicked: function(v) {
      if (!room.service) return
      if (!room.enabled) room.service.setAnimeEnabled(true)
      room.service.setAnimeBrightness(v)
    }
    onToggled: if (room.service) room.service.setAnimeEnabled(!room.enabled)
  }
}
