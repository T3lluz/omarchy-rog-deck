# ROG Deck

An Omarchy bar widget and control panel for ASUS ROG laptops, built on
[`asusctl`/`asusd`](https://asus-linux.org/). It's the Omarchy successor to
[Power-Deck](https://github.com/T3lluz/Power-Deck) for KDE Plasma.

> **Status: early (v0.1).** Power modes and live readings work. Keyboard lighting
> with auto-off, AniMe Matrix, FN-lock, fan curves, battery limit and display
> controls are next. See [docs/PLAN.md](docs/PLAN.md).

## What works now

- **Power mode**: Silent, Balanced and Turbo tiles. Scroll on the bar icon to
  switch, and an OSD shows the new mode. The choice is saved for the current
  power source through Omarchy's own `omarchy powerprofiles`, so the built-in
  Power widget always agrees.
- **Live readings**: CPU and GPU temperature, both fan speeds, battery
  charge/discharge watts, dGPU state (awake or asleep, read without waking it),
  charge limit and refresh rate. They show in the panel and the icon tooltip.
  You can also put CPU temperature and fan speed in the bar.
- **One owner for plug/unplug switching.** Omarchy and asusd both switch the
  power profile when the charger changes, each from its own memory, so they
  race. On first run ROG Deck turns off asusd's switching and leaves it to
  Omarchy.

## Install

```sh
omarchy plugin add https://github.com/T3lluz/omarchy-rog-deck.git --enable
```

Requires `asusd` running (`omarchy-hw-asus-rog` machines get `asusctl` from the
Omarchy installer) and `power-profiles-daemon`. Nothing in the plugin needs
root.

## Shortcuts and IPC

```sh
omarchy-shell io.github.t3lluz.rog-deck cycleProfile   # Silent → Balanced → Turbo → Silent
omarchy-shell io.github.t3lluz.rog-deck nextProfile    # one step up, stops at Turbo
omarchy-shell io.github.t3lluz.rog-deck prevProfile
omarchy-shell io.github.t3lluz.rog-deck profile turbo  # silent | balanced | turbo
omarchy-shell io.github.t3lluz.rog-deck status         # JSON snapshot
omarchy-shell shell toggle io.github.t3lluz.rog-deck   # open or close the panel
```

For example, to make the ROG fan key (F5) cycle modes, put this in
`~/.config/hypr/bindings.lua`:

```lua
o.bind("XF86Launch4", "Next power mode", "omarchy-shell io.github.t3lluz.rog-deck cycleProfile")
```

## How it works

- `Service.qml` stays loaded whether or not the widget is in the bar. It runs
  the one status poller every monitor's widget reads from: every 3 s while a
  panel is open or the bar shows live numbers, every 20 s otherwise. It also
  owns the IPC target.
- `Panel.qml` is the bar icon and panel. It only draws service state.
- `bin/rog-deck` is the backend. `rog-deck status` returns everything as one
  JSON object, taking about 0.2 s, from asusd D-Bus, power-profiles-daemon,
  sysfs and hyprctl. It only asks `nvidia-smi` while the dGPU is already awake,
  so polling never wakes it.
- `Model.js` holds the pure formatting and parsing, tested under node.

## Development

The plugin folder is the git checkout. Saving a file under
`~/.config/omarchy/plugins/` hot-reloads it.

```sh
node tests/model.test.js
bin/rog-deck status | jq
omarchy plugin validate .
```

## Credits

- [Power-Deck](https://github.com/T3lluz/Power-Deck): fan curve, AniMe and
  keyboard-idle logic.
- [omarchy-asus](https://github.com/moneytosms/omarchy-asus) by moneytosms:
  capability-gated controls, tab layout and the Hyprland 0.56 refresh-rate path.
- [g-helper-linux](https://github.com/utajum/g-helper-linux): fan curve
  behaviour on GA402-class machines.

## License

MIT
