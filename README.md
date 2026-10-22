# ROG Deck

An Omarchy bar widget and control panel for ASUS ROG laptops, built on
[`asusctl`/`asusd`](https://asus-linux.org/). It's the Omarchy successor to
[Power-Deck](https://github.com/T3lluz/Power-Deck) for KDE Plasma.

The bar icon shows the power mode: scroll it to switch, middle-click it to turn
the keyboard light on or off, and hover it for temperatures, fans and battery.
Click it for the panel. Tabs appear only for hardware your laptop has.

## Panel

**Main**
- Silent, Balanced and Turbo power modes, plus the mode Omarchy keeps for
  AC and for battery.
- Live tiles: both fans, package power, battery, the dedicated GPU (read
  without waking it) and the screen rate.
- Keyboard light slider, plus AniMe and FN-lock switches.

**Keys** (keyboard lighting)
- Brightness slider.
- Auto-off after a set time without typing or touchpad use: slider plus exact
  seconds, from 5 s to 10 min. Optionally stays on while plugged in, or dims
  instead of turning off.
- Light up during boot, awake, sleep and shutdown.
- On RGB keyboards: effect, speed, and a colour that follows the Omarchy theme
  or one you pick. A white-only keyboard stays on Static. asusd lists animated
  effects for those too, but they only pulse the white and can get stuck.

**AniMe**
- Display on/off.
- Show the firmware's Banner or ROG Logo.
- Brightness slider.
- Startup, sleep and shutdown animations (Glitch/Emerge, Starfield/Swipe,
  See ya/Glitch out).
- Turn off on battery, when the laptop sleeps, or when the lid closes.

**Fans**
- A curve per power mode: eight points per fan.
- Drag a bar, or pick a point and type its exact °C and %.
- Presets: Silent (fans off until about 70 °C), Stock, Cool, Max, plus Reset.
- A marker shows the live temperature on the curve.
- Curves go into asusd's own per-mode store, so asusd puts the right curve on
  the fans whenever the mode changes.

**System**
- Charge limit: slider plus exact %, 20–100, with 60/80/100 presets, and
  "Full once" for a one-off full charge.
- Refresh rate: Auto (highest on AC, 60 Hz on battery) or a fixed rate.
- Panel overdrive.
- FN-lock.
- Boot sound.
- GPU mode: Integrated (NVIDIA off), Hybrid, or Dedicated (MUX: NVIDIA drives
  the built-in screen). A switch only takes hold on restart, so picking a mode
  asks first, then restarts. Picking the running mode cancels a pending switch.

## What runs in the background

`Service.qml` stays loaded even when the panel is closed. It handles:

- **Keyboard auto-off.** Uses the same Wayland idle signal as Omarchy's lock
  screen, but ignores "keep awake" inhibitors (a video keeps the screen on,
  not the keyboard). It remembers its own level instead of brightnessctl's
  shared slot, and refreshes that slot on restore, so unlocking never leaves
  the keyboard dark.
- **Mode switching on plug/unplug is left to Omarchy.** Omarchy and asusd both
  switch modes when the charger changes, and they race. On first run ROG Deck
  turns asusd's switching off.
- **After login.** Puts back the FN-lock state, and the firmware AniMe
  animations if another tool left an image up. Moves the Auto refresh rate
  with the charger.
- **After an Omarchy theme change.** Re-applies your keyboard effect, since the
  theme switcher resets the keyboard to a static colour.

Settings live in `~/.config/rog-deck/settings.json`.

## Install

```sh
omarchy plugin add https://github.com/T3lluz/omarchy-rog-deck.git --enable
```

Needs:
- `asusd` running (Omarchy installs `asusctl` on ROG laptops).
- `power-profiles-daemon` and `brightnessctl`.

The only root step is Integrated GPU mode, which writes `/etc/supergfxd.conf`
the same way Omarchy's own GPU switch does; that goes through `pkexec`, so you
get a password prompt. Integrated also needs `supergfxctl`.

FN-lock calls a `fnlock on|off|status` command on your `PATH` (or in
`~/.local/bin`). On this G14 that's a small keyd setup: the Fn key never
reaches Linux, so keyd swaps the action row and F1–F12 while the lock is on.
Without a `fnlock` command the switch is greyed out.

## Shortcuts and IPC

```sh
omarchy-shell io.github.t3lluz.rog-deck cycleProfile    # Silent → Balanced → Turbo → Silent
omarchy-shell io.github.t3lluz.rog-deck nextProfile     # one step up, stops at Turbo
omarchy-shell io.github.t3lluz.rog-deck prevProfile
omarchy-shell io.github.t3lluz.rog-deck profile turbo   # silent | balanced | turbo
omarchy-shell io.github.t3lluz.rog-deck cycleAura       # next keyboard effect
omarchy-shell io.github.t3lluz.rog-deck toggleKeyboard  # keyboard light off / back on
omarchy-shell io.github.t3lluz.rog-deck fnlock toggle   # on | off | toggle
omarchy-shell io.github.t3lluz.rog-deck anime toggle    # on | off | toggle
omarchy-shell io.github.t3lluz.rog-deck openTab fans    # main | lighting | anime | fans | system
omarchy-shell io.github.t3lluz.rog-deck gpu hybrid      # integrated | hybrid | dedicated; asks before restarting
omarchy-shell io.github.t3lluz.rog-deck status          # JSON snapshot
```

The ROG keys, in `~/.config/hypr/bindings.lua`:

```lua
o.bind("XF86Launch3", "Next keyboard lighting effect", "omarchy-shell io.github.t3lluz.rog-deck cycleAura")
o.bind("XF86Launch4", "Next power mode", "omarchy-shell io.github.t3lluz.rog-deck cycleProfile")
```

## How it works

- `bin/rog-deck` is the backend. `rog-deck status` returns everything as one
  JSON object in about 0.2 s, read from asusd's D-Bus API,
  power-profiles-daemon, sysfs and hyprctl. Every change is one `rog-deck`
  command. Run `bin/rog-deck --help` for the list.
- `Service.qml` holds the state, the settings file and the background jobs, and
  owns the IPC target.
- `Panel.qml` and `components/` draw the bar icon and panel.
- `Model.js` holds the pure logic, tested under node.

Some details that matter:
- **Effect changes.** The keyboard can keep animating an old effect while
  asusd reports the new one. So `rog-deck aura` blanks the keyboard, writes
  the effect, then re-sends the power state and brightness.
- **Refresh rate.** Hyprland 0.56's Lua config rejects
  `hyprctl keyword monitor`, so the rate goes through
  `hyprctl eval "hl.monitor({...})"`. If hyprmoncfg's daemon has an active
  profile, that profile is saved too, so the change sticks.
- **GPU readings.** `nvidia-smi` is only asked while the dGPU is already awake.
- **GPU modes.** The running mode comes from the hardware: no NVIDIA card (or
  one parked on vfio-pci) is Integrated, an NVIDIA card driving the eDP panel
  is Dedicated. asusd doesn't write `gpu_mux_mode` or `dgpu_disable` straight
  away; it queues them (`QueuedGpuValue`) and its `asus-shutdown` helper writes
  them on the way down, so the mode after restart is read from that queue plus
  supergfxd's config. Integrated sets the MUX to Hybrid and supergfxd to
  Integrated, with Omarchy's delayed supergfxd start and its sleep hook that
  turns the dGPU back off after resume. The restart is `omarchy-system-reboot`.

## Development

The plugin folder is the git checkout. Saving a file hot-reloads the panel.
Changes to `Service.qml`, or to new files under `components/`, need
`omarchy restart shell`.

```sh
node tests/model.test.js
bin/rog-deck status | jq
omarchy plugin validate .
```

## Credits

- [Power-Deck](https://github.com/T3lluz/Power-Deck): AniMe, fan curve and
  keyboard-idle behaviour, the bar-style curve editor.
- [omarchy-asus](https://github.com/moneytosms/omarchy-asus) by moneytosms:
  hardware-gated tabs, the scrollable panel with every tab built up front, and
  the Hyprland 0.56 refresh-rate path.
- [g-helper-linux](https://github.com/utajum/g-helper-linux) and
  [G-Helper](https://github.com/seerge/g-helper): feature reference.

## License

MIT
