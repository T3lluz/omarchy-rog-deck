<div align="center">
  <img src="assets/icon.svg" width="72" height="72" alt="ROG Deck" />
  <h1>ROG Deck</h1>
  <p>An Omarchy bar widget and control panel for <b>ASUS ROG</b> laptops, built on <a href="https://asus-linux.org/">asusctl/asusd</a>:<br/>
  power modes, temperatures and fans, keyboard lighting with auto-off, AniMe Matrix, FN-lock, battery limit and Battery saver, a CPU power limit for Silent, display and GPU mode.</p>
  <p>
    <img alt="Version" src="https://img.shields.io/badge/v0.8.1-111111?label=version" />
    <img alt="Omarchy 4" src="https://img.shields.io/badge/Omarchy-4-ff8f6b" />
    <img alt="asusd 6" src="https://img.shields.io/badge/asusd-6-ff8f6b" />
    <a href="https://github.com/T3lluz/omarchy-rog-deck/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/T3lluz/omarchy-rog-deck/actions/workflows/ci.yml/badge.svg" /></a>
    <img alt="License" src="https://img.shields.io/badge/license-MIT-34413e" />
  </p>
  <p><a href="#install"><b>Install</b></a> · <a href="#features">Features</a> · <a href="#shortcuts-and-ipc">Shortcuts</a> · <a href="#how-it-works">How it works</a></p>
  <img src="assets/preview.png" width="400" alt="The ROG Deck panel: power modes, live fans and power, keyboard light" />
</div>

## Features

- **The power mode in the bar:** the leaf, gauge and speedometer Omarchy's own power menu shows for Silent, Balanced and Turbo.
- **Scroll the icon** to switch modes, middle-click it for the keyboard light, hover it for temperatures, fans and battery.
- **Pick the bar stats** from a grid of switches in the System tab: the mode name, CPU and GPU temperature (tinted as they heat up), fan speed, package power, the NVIDIA GPU's state or draw, battery and refresh rate. None picked leaves the icon alone. The GPU temperature appears only while the dGPU is awake.
- **Updates itself:** the System tab checks the plugin's GitHub every few hours and updates in place when you click Update. Local edits in the plugin folder, new files included, are kept in `git stash` rather than blocking the update, and dropped when they already are the new version.
- **Banners over every tab** for what needs you: an error, a GPU switch waiting on a restart, or a new version.
- **Every monitor agrees:** one service owns the state, and the bar settings are read straight from `shell.json`, so a pick made on one screen shows on all of them and survives a restart.
- Tabs appear only for hardware your laptop has.

**Main** · Silent, Balanced and Turbo, plus the mode Omarchy keeps for AC and for battery. Live tiles for both fans, package power, battery, the dGPU (read without waking it) and the screen rate. In Silent, a CPU power limit like G-Helper's: one slider, 15–35 W sustained, with the boosts raised to the firmware's minimum (15 W holds 15 W sustained and boosts to 25 / 35 W). The firmware only honours limits while the mode runs a custom fan curve, so the limit switches Silent's on (asusd's copy of the firmware curve, so the fans behave the same) and switching the limit off puts it back. Keyboard light, AniMe and FN-lock.

**Keys** · Brightness. Auto-off after a set time without typing or touchpad use (5 s to 10 min), optionally staying on while plugged in or dimming instead. Light during boot, awake, sleep and shutdown. On RGB keyboards: effect, speed, and a colour that follows the Omarchy theme or one you pick. A white-only keyboard stays on Static: asusd lists animated effects for those too, but they only pulse the white and can get stuck.

**AniMe** · Display on/off, the firmware's Banner or ROG Logo, brightness, startup/sleep/shutdown animations, and off on battery, asleep or with the lid closed.

**Fans** · A curve per power mode, eight points per fan. Drag a bar or type a point's exact °C and %. Presets: Silent (off until about 70 °C), Stock, Cool, Max, plus Reset. A marker shows the live temperature. Curves go into asusd's own per-mode store, so the right one is on the fans whenever the mode changes.

**System** · Charge limit 20–100 (slider or type it) and "Full once". Battery saver: on battery, 60 Hz, panel overdrive off, screen power saving and Wi-Fi power save, all put back when the charger returns; the switches show each change as it happens. Refresh rate: Auto (highest on AC, 60 Hz on battery) or fixed. Panel overdrive, screen power saving (amdgpu's panel power savings at level 3 on battery; power-profiles-daemon's own version waits for 50% battery, so Battery saver switches it off and sets the level itself), FN-lock, boot sound. GPU mode: Integrated (NVIDIA off), Hybrid or Dedicated (MUX); a switch only takes hold on restart, so it asks first. What the bar shows, whether the icon moves, the version and updates.

### In the background

`Service.qml` stays loaded with the panel closed:

- **Keyboard auto-off** uses the same Wayland idle signal as Omarchy's lock screen but ignores "keep awake" inhibitors (a video keeps the screen on, not the keyboard), and keeps its own level so unlocking never leaves the keyboard dark.
- **Mode switching on plug/unplug is Omarchy's.** Omarchy and asusd both switch modes when the charger changes and race; on first run ROG Deck turns asusd's switching off.
- **After login** it puts back FN-lock and the firmware AniMe animations, and moves the Auto refresh rate with the charger.
- **On plug and unplug**, about 2 s after Omarchy has switched the mode, it applies Battery saver and the refresh rate, and checks again a few seconds later. Your overdrive choice on the charger is remembered and put back.
- **Silent's CPU limit** is written whenever Silent starts, the charger changes or the laptop wakes, since the firmware loads each mode's own limits then; leaving Silent hands them back to the firmware.
- **After an Omarchy theme change** it re-applies your keyboard effect, since the theme switcher resets the keyboard to a static colour.

Settings live in `~/.config/rog-deck/settings.json`; what the bar shows lives in the widget's entry in `~/.config/omarchy/shell.json`.

## Install

```bash
omarchy plugin add https://github.com/T3lluz/omarchy-rog-deck.git --enable
```

Needs `asusd` running (Omarchy installs `asusctl` on ROG laptops), `power-profiles-daemon` and `brightnessctl`.

Two steps need root, both through `pkexec`. The first is Integrated GPU mode, done the same way Omarchy's own GPU switch does it: the first time, it installs `supergfxctl` from the Omarchy repo, then it writes `/etc/supergfxd.conf`. Integrated is supergfxd's job, not the firmware `dgpu_disable` switch: asusd can only write that switch at shutdown, when the NVIDIA driver still holds the card, so the write fails and the laptop starts in Hybrid.

The second is the power helper, for the CPU limit, screen power saving and Wi-Fi power save. Turning either on the first time asks for your password once, to install `bin/rog-deck-power` as `/usr/local/libexec/rog-deck-power` (owned by root) and a polkit rule in `/etc/polkit-1/rules.d/49-rog-deck-power.rules` that lets you, at the laptop, run that one program without a password. It only takes CPU limits inside the firmware's range for your laptop and power source (from the kernel's asus-armoury table; GA402NV for now) panel power savings 0–4 and Wi-Fi power save on or off. To remove both: `bin/rog-deck power uninstall`.

FN-lock calls a `fnlock on|off|status` command on your `PATH` (or in `~/.local/bin`). On a G14 that's a small keyd setup: the Fn key never reaches Linux, so keyd swaps the action row and F1–F12 while the lock is on. Without a `fnlock` command the switch is greyed out.

## Shortcuts and IPC

```bash
omarchy-shell io.github.t3lluz.rog-deck cycleProfile    # Silent → Balanced → Turbo → Silent
omarchy-shell io.github.t3lluz.rog-deck nextProfile     # one step up, stops at Turbo
omarchy-shell io.github.t3lluz.rog-deck prevProfile
omarchy-shell io.github.t3lluz.rog-deck profile turbo   # silent | balanced | turbo
omarchy-shell io.github.t3lluz.rog-deck cycleAura       # next keyboard effect
omarchy-shell io.github.t3lluz.rog-deck toggleKeyboard  # keyboard light off / back on
omarchy-shell io.github.t3lluz.rog-deck fnlock toggle   # on | off | toggle
omarchy-shell io.github.t3lluz.rog-deck anime toggle    # on | off | toggle
omarchy-shell io.github.t3lluz.rog-deck saver toggle    # Battery saver: on | off | toggle
omarchy-shell io.github.t3lluz.rog-deck toggle          # the panel, on the focused monitor
omarchy-shell io.github.t3lluz.rog-deck openTab fans    # main | lighting | anime | fans | system
omarchy-shell io.github.t3lluz.rog-deck gpu hybrid      # integrated | hybrid | dedicated; asks before restarting
omarchy-shell io.github.t3lluz.rog-deck status          # JSON snapshot
omarchy-shell io.github.t3lluz.rog-deck version         # installed version
omarchy-shell io.github.t3lluz.rog-deck checkUpdates    # look for a newer version now
omarchy-shell io.github.t3lluz.rog-deck update          # install it, if one was found
```

The ROG keys, in `~/.config/hypr/bindings.lua`:

```lua
o.bind("XF86Launch1", "ROG Deck", "omarchy-shell io.github.t3lluz.rog-deck toggle")
o.bind("XF86Launch3", "Next keyboard lighting effect", "omarchy-shell io.github.t3lluz.rog-deck cycleAura")
o.bind("XF86Launch4", "Next power mode", "omarchy-shell io.github.t3lluz.rog-deck cycleProfile")
```

## How it works

- `bin/rog-deck` is the backend. `rog-deck status` returns everything as one JSON object in about 0.2 s, read from asusd's D-Bus API, power-profiles-daemon, sysfs and hyprctl. Every change is one `rog-deck` command; `bin/rog-deck --help` lists them.
- `Service.qml` holds the state, the settings file and the background jobs, and owns the IPC target.
- `Panel.qml` and `components/` draw the bar icon and panel, with the panel kit shared by all four plugins in this family.
- `Model.js` holds the pure logic, tested under node.

Details that matter:

- **Effect changes.** The keyboard can keep animating an old effect while asusd reports the new one, so `rog-deck aura` blanks the keyboard, writes the effect, then re-sends the power state and brightness.
- **Refresh rate.** Hyprland 0.56's Lua config rejects `hyprctl keyword monitor`, so the rate goes through `hyprctl eval "hl.monitor({...})"`. hyprmoncfg's daemon puts the screens back the way its best-matching profile has them after any change, so the new rate is saved into the active profile. With the laptop off its desk no profile is active and the daemon falls back to the desk profile and its rate; ROG Deck then keeps a "Laptop" profile with just the built-in screen, which the daemon matches exactly. A profile with only some of a desk's screens isn't made for you: save that layout once in hyprmoncfg and the rate sticks there too.
- **CPU limits.** The same three ASUS ACPI limits G-Helper sets on this laptop (sustained `0x1200A3`, slow boost `0x1200A0`, fast boost `0x1200C1`), through the kernel's asus-nb-wmi attributes. The firmware doesn't report them back, so the panel shows what was last written. On a GA402NV on battery, a full-load test with 15 W held about 15–25 W at 75 °C; without the custom fan curve the same writes did nothing (33 W, 95 °C).
- **GPU readings.** `nvidia-smi` is only asked while the dGPU is already awake.
- **GPU modes.** The running mode comes from the hardware: no NVIDIA card (or one parked on vfio-pci) is Integrated, an NVIDIA card driving the eDP panel is Dedicated. asusd queues `gpu_mux_mode` writes (`QueuedGpuValue`) for its `asus-shutdown` helper, so the mode after restart is read from that queue plus supergfxd's config. A queued `dgpu_disable=1` from an earlier version is cancelled. The restart is `omarchy-system-reboot`.
- **Updates.** `bin/plugin-update check` (or `rog-deck update check`) fetches the plugin's remote (only `.git` changes, which the shell ignores) and compares versions; `apply` runs detached, stashes local edits with untracked files, and calls `omarchy plugin update`, which fast-forwards, validates and reloads the plugins. The result lands in `~/.local/state/rog-deck/update.json` for the reloaded panel.

## Development

```bash
node tests/model.test.js
node tests/update.test.js
python3 -B -m unittest discover tests
bin/rog-deck status | jq
omarchy plugin validate .
omarchy restart shell    # pick up QML changes
```

See [AGENTS.md](AGENTS.md) for how the pieces fit. [docs/PLAN.md](docs/PLAN.md) has the original design notes.

## Credits

- [Power-Deck](https://github.com/T3lluz/Power-Deck), the KDE Plasma original: AniMe, fan curve and keyboard-idle behaviour, the bar-style curve editor.
- [omarchy-asus](https://github.com/moneytosms/omarchy-asus) by moneytosms: hardware-gated tabs, every tab built up front, and the Hyprland 0.56 refresh-rate path.
- [g-helper-linux](https://github.com/utajum/g-helper-linux) and [G-Helper](https://github.com/seerge/g-helper): feature reference, and the evidence that Eco/Integrated has to happen before the display stack holds the dGPU.

## License

MIT. Not affiliated with ASUS or Republic of Gamers.

One of a set of Omarchy plugins: [Batteries](https://github.com/T3lluz/omarchy-batteries) · **ROG Deck** · [Sonus](https://github.com/T3lluz/omarchy-sonus) · [Server Dashboard](https://github.com/T3lluz/omarchy-server-dashboard)
