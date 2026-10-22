# ROG Deck: plan

Working name **ROG Deck**. Repo `T3lluz/omarchy-rog-deck`, plugin id `io.github.t3lluz.rog-deck`
(same naming as `omarchy-server-dashboard`). It's an Omarchy shell plugin: a bar icon plus a
themed control panel for ASUS ROG laptops. Think of it as Power-Deck rebuilt for Omarchy.

---

## 1. What this laptop exposes (checked on this machine)

ROG Zephyrus G14 **GA402NV**, Ryzen + RTX 4060, asusd **6.5.0** running, kernel 7.2.

| Area | Where it comes from | What's there |
|---|---|---|
| Power profile | power-profiles-daemon → `platform_profile` | quiet / balanced / performance. Omarchy remembers one for AC and one for battery (`omarchy powerprofiles set`) |
| Keyboard brightness | `asus::kbd_backlight` (0–3), asusd `Aura.Brightness` | off / low / med / high. Hardware keys emit `brightness_hw_changed` |
| Keyboard RGB | asusd `/xyz/ljones/aura/19b6_2_3` | Supported modes **Static, Breathe, Rainbow Cycle, Rainbow Wave, Pulse** (`SupportedBasicModes = 0 1 2 3 10`), one zone, two colours, speed, direction |
| Keyboard power states | asusd `Aura.LedPower` | keyboard lit at **boot / awake / sleep / shutdown** |
| AniMe Matrix | asusd `/xyz/ljones/aura/anime` | display on/off, brightness 0–3, built-in animations (boot: GlitchConstruction/StaticEmergence, awake: BinaryBannerScroll/RogLogoGlitch, sleep: BannerSwipe/Starfield, shutdown: GlitchOut/SeeYa), PNG/GIF (normal + pixel-perfect), `OffWhenUnplugged`, `OffWhenSuspended`, `OffWhenLidClosed`, raw `Write` of frames |
| Fans | `asus` hwmon (RPM), `asus_custom_fan_curve` via asusd `FanCurves` | CPU + GPU fans, 8-point temp→duty curve per profile. The EC owns live speed; there is no fixed "set fans to 50%" on GA402 |
| Battery | asusd / `charge_control_end_threshold` | charge limit 20–100 (now 100), one-shot full charge |
| Firmware toggles | asusd `asus_armoury` | **boot_sound**, **panel_overdrive** (on), gpu_mux_mode, dgpu_disable, charge_mode |
| Not available here | asusd reports *unavailable* | ppt_* power limits, nv_dynamic_boost, nv_temp_target, Slash LED bar, ScreenPad, mini-LED |
| Display | Hyprland | eDP-1 2560×1600 @ **60 / 165 Hz** |
| GPU | PCI runtime PM | iGPU Radeon 680M + dGPU RTX 4060 (Hybrid). supergfxd is **not** installed |
| FN-lock | your existing **keyd** setup | `~/.local/bin/fnlock` + `/usr/local/bin/fnlock-keyd` (sudoers) + `/etc/keyd/fnlock.map`, bound to Shift+Esc. The Fn key never reaches Linux, so this software swap is the only option |
| Sensors | hwmon | k10temp (CPU), amdgpu edge + PPT W, nvidia-smi (only when the dGPU is awake), BAT0 W |

### Already in Omarchy (the plugin must work alongside these)

- **Theme → keyboard colour**: `omarchy-theme-set-keyboard-asus-rog` sets the keyboard to the theme's `keyboard.rgb` on every theme change.
- **Power profile memory**: `omarchy powerprofiles set ac|battery <profile>`.
- **Lock screen** turns the keyboard light off with `omarchy-brightness-keyboard off`, which uses brightnessctl's single save slot (`-s`/`-r`).
- **Hybrid GPU toggle**: `omarchy toggle hybrid gpu` (installs supergfxd on first use).
- Your `bindings.lua` already maps F4 (`XF86Launch3`) to the next Aura mode and F5 (`XF86Launch4`) to the next fan profile.

### What [omarchy-asus](https://github.com/moneytosms/omarchy-asus) already does (MIT, v2.1)

A G-Helper-style **tabbed** panel (Main / RGB / Fan / Advanced), bar widget only:
- Live temps, fan RPM, GPU W/util, battery rate in the panel and the icon tooltip.
- Profile saved per power source through `asusctl profile set --ac/--battery`; scroll the icon to cycle.
- GPU mode, refresh rate, panel overdrive, charge limit.
- RGB filtered by `asusctl info --show-supported`, plus aura power states.
- Per-profile draggable fan curves with a master switch. PL1/PL2/NV limits gated on `armoury list`.
- Refresh rate on Hyprland 0.56 goes through `hyprctl eval "hl.monitor({...})"`, because
  `hyprctl keyword monitor` is rejected under the Lua config. It also detects hyprmoncfg.

**What it lacks, which ROG Deck covers:** AniMe Matrix, keyboard auto-off, FN-lock, boot sound,
a background service (so nothing runs while the panel is closed: no idle timer, no restore at
login or resume, no AC-driven actions), and live sync when keys change things.

**What we borrow:**
- The tab layout.
- "Only show what `asusctl info --show-supported` / `armoury list` report".
- The `hyprctl eval` refresh-rate path and the hyprmoncfg handling.
- The tooltip with live readings.
- Its parser tests as a model.

Credit it in the README.

**Why a new repo instead of a fork:** ROG Deck needs a `service` kind and a different backend
(one helper CLI, events instead of polling). Most of the hard parts (fan curves, AniMe,
keyboard idle) already exist in your own Power-Deck. A fork would mean rewriting most of
omarchy-asus anyway.

---

## 2. Features

### v1 (MVP)

**1. Power modes.** Tiles for Silent / Balanced / Turbo, with the active one highlighted.
- Calls `omarchy powerprofiles set` so Omarchy's AC/battery memory stays the source of truth. Optional "same mode on AC and battery".
- Scroll on the bar icon to cycle modes, plus an OSD.
- Each mode applies its fan curve (see 6).
- asusd's own AC/battery profile switching (now AC=Performance, Battery=Quiet) fights Omarchy, so the plugin turns it off with one owner. Lesson from Power-Deck.

**2. Keyboard lighting**
- Brightness off / low / med / high (segmented).
- Effect: Static, Breathe, Rainbow Cycle, Rainbow Wave, Pulse. The list is read from `SupportedBasicModes`, not hardcoded.
- Colour: a swatch row plus a hex field. **"Follow Omarchy theme"** is on by default. When it's off, the service watches `keyboard.rgb` and puts your colour back after a theme change.
- Speed (and direction for Wave) when the effect has them.
- "Light up during": boot / awake / sleep / shutdown (`LedPower`).

**3. Keyboard light auto-off (the idle timer).** Runs in the plugin's **service**, so it works even if the bar widget is hidden.
- Uses Quickshell's `IdleMonitor`, the same Wayland idle protocol Omarchy's idle service uses. No swayidle, no systemd unit.
- Timeout: 10 s / 30 s / 1 min / 2 min / 5 min / 10 min / never.
- "Stay on while plugged in" and "Only dim, don't turn off" (drop to low).
- `respectInhibitors: false`, so a video playing doesn't keep the keyboard lit.
- Keeps its **own** saved level instead of brightnessctl's `-s` slot, so it can't clash with the lock screen. If you change brightness with the keys while it's off, that new level wins.
- Wakes on any input, including touchpad. Optional fade (step 3→0 over about 1 s).

**4. AniMe Matrix**
- On/off, brightness, and a big preview tile for the current pick.
- Awake animation: Banner (BinaryBannerScroll), ROG Logo (RogLogoGlitch), Static ROG logo (PNG from Power-Deck), or **Custom image/GIF**. The picker uses Omarchy's built-in `omarchy.image-picker` overlay on `~/Pictures/anime/`.
- Boot / sleep / shutdown animation pickers.
- Turn off when unplugged / suspended / lid closed. These are asusd properties, so the firmware handles them.
- Custom images get re-pushed after resume and on login, because asusd doesn't keep them.

**5. FN-lock**
- Toggle in the panel, plus a lock badge on the bar icon while it's on.
- Uses your existing keyd setup. The plugin calls `fnlock on|off` and keeps Shift+Esc.
- Fix: the state lives in `$XDG_RUNTIME_DIR`, so it's lost on reboot. Move it to `~/.local/state/rog-deck/` and have the service restore it at login.
- Other machines: if keyd isn't set up, show **"Set up FN-lock…"**. It opens a terminal running `extras/fnlock/install.sh` (keyd map + sudoers, with sudo in the terminal). The plugin itself never runs sudo.

**6. Fans**
- Live CPU/GPU RPM and temperatures in the panel, and optionally in the bar.
- 8-point CPU/GPU curve editor per power mode, ported from Power-Deck's `fan-ctl` + `FanCurveStrip`. Writes go through asusd D-Bus `FanCurves`, never raw sysfs.
- Presets: Silent (fans off until about 70 °C), Stock, Cool, Max. Custom vs Firmware per mode.
- Clear note in the UI: the EC sets live speed. You shape the curve; you can't pin an RPM.

**7. Battery**
- Charge-limit slider 60–100 % in 5 % steps (`asusctl battery limit`), and a "Charge to 100 % once" button.
- Header pill: %, charge/discharge W, time left.

**8. Display**
- Refresh: Auto (60 Hz on battery, 165 Hz on AC) / 60 / 165, using the modes detected from
  Hyprland. Applied with `hyprctl eval "hl.monitor({...})"` (the Lua-config path omarchy-asus
  found), keeping position and scale. Your existing `hypr-monitor-scale` stays in charge of scale.
  Auto runs in the service, so it also works when the panel is closed.
- Panel Overdrive toggle (`armoury panel_overdrive`).

### v1.1 extras

- **Boot sound** toggle (`armoury boot_sound`).
- **GPU status chip**: iGPU only / dGPU asleep / dGPU awake / dGPU drives display. Reads PCI `runtime_status`, so it never wakes the card. Switching modes stays a button that runs `omarchy toggle hybrid gpu` in a terminal; I'd skip MUX switching (reboot risk).
- **ROG keys go through the plugin**: F4/F5 call `omarchy-shell io.github.t3lluz.rog-deck cycleAura|cycleProfile`, so the OSD and panel stay in sync.
- **Notifications** (optional) on mode change, plug/unplug, and charge limit reached.
- **Extreme Saver** mode from Power-Deck (Wi-Fi powersave, ASPM powersave, dGPU D3cold, 60 Hz). Needs the root helper, so it's opt-in.

### Later (v2 ideas)

- **AniMe live widgets**: clock, CPU/GPU bars, battery, audio visualizer, now-playing text. The service renders frames and sends them over asusd's `Write`.
- **Per-app profiles**: a Hyprland window rule switches to Turbo when Steam or a game is focused, then back.
- **Capability-driven support for other ROGs**: Slash LED bar, per-key RGB, mini-LED, PPT sliders, and dGPU dynamic boost all appear automatically where asusd reports them.

---

## 3. Panel layout

Tabs, like omarchy-asus/G-Helper: **Main · Lighting · AniMe · Fans · System**. Each tab only
appears if the laptop supports it. Main is the at-a-glance view:

```
┌─ ROG Deck ───────────────────────── CPU 62° 18W  GPU asleep  🔋 84% −12W ─┐
│ ┌────────┐ ┌────────┐ ┌────────┐                                            │
│ │ Silent │ │Balanced│ │ Turbo  │   Fans  2600 / 2800 rpm   [Edit curve]     │
│ └────────┘ └────────┘ └────────┘                                            │
├──────────────────────────────────┬──────────────────────────────────────────┤
│ KEYBOARD                         │ ANIME MATRIX                    [ on ]   │
│ Brightness [off|low|med|high]    │ [ preview ]  Banner · Logo · Static ·    │
│ Effect  Static ▾  ● theme colour │              Custom…                     │
│ Auto-off after [1 min ▾]         │ Brightness ▬▬▬○  Off on battery [x]      │
│ Stay on while plugged in [ ]     │                                          │
├──────────────────────────────────┼──────────────────────────────────────────┤
│ FN-LOCK            [ off ]       │ BATTERY limit ▬▬▬▬○ 80%  [Full once]     │
│ DISPLAY  Auto · 60 · 165   OD [x]│ Boot sound [ ]                           │
└──────────────────────────────────┴──────────────────────────────────────────┘
```

The fan editor opens as an overlay over the panel, like Power-Deck. Colours, font, corners, and
spacing come from the Omarchy theme (`qs.Commons`), same as server-dashboard.

**Bar icon**: a profile glyph tinted per mode, a small lock dot when FN-lock is on, and optional
temps / RPM / battery W (picked in settings). Scroll changes the mode, click opens the panel, and
middle-click toggles the keyboard light.

---

## 4. Architecture

```
omarchy-rog-deck/
├── manifest.json        kinds: ["service", "bar-widget"], service keepLoaded
├── Service.qml          headless brain: capability probe, state, IdleMonitor (kbd auto-off),
│                        AC watch (UPower), login/resume restore, IPC target, theme-colour watch
├── BarWidget.qml        bar icon + panel host
├── Panel.qml            dashboard
├── components/          ProfileTiles, KeyboardCard, AnimeCard, FanCurveEditor, Segmented, …
├── Model.js             pure parsing/formatting, unit-tested with node (like server-dashboard)
├── bin/rog-deck         one helper CLI: `status --json` returns everything in one call;
│                        setters wrap asusctl / busctl / brightnessctl / powerprofilesctl / hyprctl
├── bin/rog-deck-fans    port of Power-Deck fan-ctl (asusd D-Bus FanCurves)
├── assets/anime/        static ROG logo PNG
├── extras/fnlock/       keyd map + sudoers + install.sh (opt-in, sudo in a terminal)
└── tests/
```

Design rules:

1. **No root in the plugin.** Everything goes through asusd D-Bus, logind (brightnessctl), PPD,
   and hyprctl, which all work as your user. Omarchy's `plugin add` never runs install hooks or
   sudo, and this keeps it that way. The only root piece is the opt-in FN-lock setup.
2. **Capability-driven UI.** At start the service checks asusd's objects, `armoury list`, and
   `SupportedBasicModes`, then hides anything the laptop lacks. It works on other ROGs and never
   shows controls that do nothing.
3. **Events first, polling second.** The service watches asusd `PropertiesChanged` (`busctl
   monitor`) and `brightness_hw_changed`. F-key changes show up in the panel right away, with no
   polling. Temps and RPM are polled every 3 s only while the panel is open, or the bar is set to
   show them.
4. **One status call.** The panel reads one JSON from `rog-deck status --json` instead of a dozen
   asusctl calls. asusctl takes about 50–100 ms per call, so this keeps the panel fast.
5. **Coexist with Omarchy.** Power profiles go through `omarchy powerprofiles`. Theme colour is
   followed by default. The lock screen's brightness slot is never touched. OSD goes through
   `omarchy-osd`.

---

## 5. Milestones

| # | What | Done when |
|---|---|---|
| M0 | Repo, manifest, `rog-deck status --json`, bar icon with mode cycling | `omarchy plugin validate` passes and the icon cycles modes |
| M1 | Keyboard card + **auto-off service** | Light turns off after the timeout, comes back on input, and survives the lock screen |
| M2 | AniMe card (built-ins, static, custom image/GIF, power options) | All shapes stick after suspend and reboot |
| M3 | FN-lock (keyd, persisted), battery limit, display (refresh, overdrive), boot sound | Each control matches `asusctl` and the keys stay in sync |
| M4 | Fan curve editor + per-mode curves | Switching modes applies that mode's curve, and it survives reboot |
| M5 | GPU status, ROG-key IPC, notifications, README + screenshots, publish | `omarchy plugin add https://github.com/T3lluz/omarchy-rog-deck.git` works on a clean setup |

---

## 6. Decisions

Settled on 2026-10-22, all with the recommended answer: public MIT repo
`T3lluz/omarchy-rog-deck`; three native modes in v1 (Extreme Saver later, opt-in); Omarchy
owns plug/unplug switching (asusd's auto-switch is turned off on first run); GPU is status
plus a button for `omarchy toggle hybrid gpu`; F4/F5 go through the plugin's IPC.

The original questions:

1. **Repo**: `T3lluz/omarchy-rog-deck`, public, MIT? (Name alternatives: *Armoury*, *ROG Control*.)
2. **Power modes**: the 3 native modes in v1, with Extreme Saver later as opt-in (recommended)? Or
   Power-Deck's 4 modes from the start?
2b. **Who owns AC/battery switching**: right now *both* asusd (AC=Performance, Battery=Quiet) and
   Omarchy's `powerprofiles` switch on plug/unplug, and they disagree (PPD says power-saver,
   asusd says Quiet). I recommend Omarchy's, so the built-in Power widget agrees, with asusd's
   auto-switch turned off. omarchy-asus went with asusd instead.
3. **GPU switching**: status only plus a button that runs `omarchy toggle hybrid gpu` (recommended)?
   Or leave GPU out entirely?
4. **F4/F5 keys**: move them to the plugin's IPC so OSD and panel stay in sync (recommended)?

Sources: [g-helper-linux](https://github.com/utajum/g-helper-linux) (feature reference),
[asusctl 6.4.0 release notes](https://newreleases.io/project/github/OpenGamingCollective/asusctl/release/6.4.0),
[asus-armoury kernel driver (LWN)](https://lwn.net/Articles/1040830), plus Power-Deck's AGENTS.md
and live probing of asusd on this laptop.
