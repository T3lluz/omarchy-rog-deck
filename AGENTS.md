# AGENTS.md

How ROG Deck is put together, for anyone (or any agent) changing it. The user-facing story is in [README.md](README.md).

## Layout

- `Service.qml`: always loaded. Owns the status poller, the action queue to `bin/rog-deck`, `~/.config/rog-deck/settings.json`, the background jobs (keyboard auto-off, FN-lock after login, Auto refresh rate, theme re-apply) and the IPC target.
- `Panel.qml`: the bar entry and panel, once per monitor, drawing the service's state. Bar picks come from `WidgetSettings.qml`.
- `components/`: the tabs, the panel kit (below) and the shared updater. The mode icons are the Nerd Font glyphs Omarchy's own power menu uses, from `Model.PROFILES`.
- `Model.js`: parsing and formatting, tested by `tests/model.test.js`.
- `bin/rog-deck`: the backend (Python): asusd over D-Bus, power-profiles-daemon, sysfs, hyprctl, `nvidia-smi` only while the dGPU is awake. `rog-deck update` hands over to `bin/plugin-update`.
- `docs/PLAN.md`: the original design notes.

## Test

```bash
node tests/model.test.js
node tests/update.test.js
python3 -B -m unittest discover tests
bin/rog-deck status | jq
omarchy-shell io.github.t3lluz.rog-deck status | jq
```

## Panel kit

`SectionHeader`, `StatTile`, `ToggleTile`, `SwitchRow`, `Seg`, `Notice`, `LevelBar`, `OptionRow`, `Caption` and `UpdateSection` in `components/` are the panel kit: the same files, byte for byte, in ROG Deck, Batteries, Sonus and Server Dashboard, so the four look like one family. Change a kit file in all four or not at all. `Glyph.qml` is the one part each plugin owns: Nerd Font glyphs here, drawn Tabler icons in Batteries.

`Updater.qml`, `Update.js` and `bin/plugin-update` are the shared updater (ROG Deck, Batteries and Server Dashboard; Sonus's engine updates itself the same way). It stashes local edits, untracked files too, before fast-forwarding, and drops the stash when the edits already are the update. `tests/update.test.js` and `tests/test_plugin_update.py` cover it.

Panels never cut text: a `Notice` shows all of its message, a `Caption` breaks long words and paths, and a `ToggleTile` label that does not fit shows in full in its tooltip.

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
