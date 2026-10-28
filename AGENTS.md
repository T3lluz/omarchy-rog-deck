# AGENTS.md

How ROG Deck is put together, for anyone (or any agent) changing it. The user-facing story is in [README.md](README.md).

## Layout

- `Service.qml`: always loaded. Owns the status poller, the action queue to `bin/rog-deck`, `~/.config/rog-deck/settings.json`, the background jobs (keyboard auto-off, FN-lock after login, Auto refresh rate, theme re-apply) and the IPC target.
- `Panel.qml`: the bar entry and panel, once per monitor, drawing the service's state. Bar picks come from `WidgetSettings.qml`.
- `components/`: the tabs and controls. `ModeIcon.qml` is the animated Silent/Balanced/Turbo icon, `Notice.qml` the banners over every tab (built from `Service.notices`), `ToggleTile.qml` the half-width switch tiles for the bar picks.
- `Model.js`: parsing and formatting, tested by `tests/model.test.js`.
- `bin/rog-deck`: the backend (Python): asusd over D-Bus, power-profiles-daemon, sysfs, hyprctl, `nvidia-smi` only while the dGPU is awake.
- `docs/PLAN.md`: the original design notes.

## Test

```bash
node tests/model.test.js
bin/rog-deck status | jq
omarchy-shell io.github.t3lluz.rog-deck status | jq
```

`ModeIcon.qml` runs one 50 ms clock, not a per-frame animation, so the bar on three monitors redraws a handful of times a second. Keep it that way.

## Rules that are easy to break

- **Settings** are read with `setting(key, fallback)` and saved with `persistSettings({...})`. Both go through `WidgetSettings.qml`, which reads `~/.config/omarchy/shell.json` itself. Never read `settings.foo` directly: the bar's copy turns a list into a Qt sequence that fails `Array.isArray`, and after a plugin reload it can be older than the file. Either one makes a pick look unset, which is how choices "reset after a reboot" or differ between monitors.
- **One widget per monitor.** The bar draws the widget on every screen. Long-running work (a poller, a client, a process) lives in one place, a leader instance or the service, and the others read from it. Never start it per instance.
- **IPC** is answered by whichever monitor's widget registered first, so `open`, `close` and `toggle` go through the shell's `summon`, `hide` and `toggle`, which pick the focused monitor.
- **Nothing may write inside the plugin folder at runtime.** The shell watches it and reloads every plugin when a file appears there. Python sets `sys.dont_write_bytecode`; state goes to `~/.local/state` or `~/.config`. Two exceptions: `.git/` is ignored by the watcher, so `update check` may fetch; and `update apply` rewrites the folder on purpose, which is why it runs detached (`Quickshell.execDetached`) and reports through `~/.local/state/rog-deck/update.json`.
- **Integrated GPU mode is supergfxd's**, never a queued `dgpu_disable=1`: asusd writes queued GPU values at shutdown, nvidia_drm (from the initramfs) still holds the card then, and the write fails with EIO, leaving the laptop in Hybrid.
- **QML changes need `omarchy restart shell`.** Hot reload can keep the old component cached.
- **Pure logic goes in `Model.js`** (a `.pragma library` with no QML) so `node tests/*.test.js` can run it. Change it with a test.
- Comments say why, in plain sentences. Match the surrounding code.

## Release

Bump `version` in `manifest.json` and the version badge in `README.md` together, run the tests, and describe the change for the person using it in the commit message.
