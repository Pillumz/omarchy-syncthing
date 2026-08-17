# Syncthing for Omarchy

Bar widget for the Omarchy 4.0 shell: Syncthing status at a glance, with a
popup panel for folders, devices, and quick actions.

## What it does

- **Bar icon**: the Syncthing mark, drawn natively. Dimmed + crossed when the
  service is stopped, spinning while syncing/scanning, `!` badge on sync errors.
- **Panel** (left-click the icon):
  - Hero with device name, overall status, and a start/stop toggle for
    `syncthing.service` (systemd user unit).
  - Folders with per-folder state, completion, rescan and pause/resume buttons.
    Click a folder to open it in the file manager.
  - Devices with connection state, address or last-seen time, and a
    copy-device-ID button.
  - Open Web UI shortcut.
- **Mouse on the bar icon**: left = panel, right = open Web UI, middle = refresh.
- **Keyboard in the panel**: arrows/jk navigate, Enter activates,
  `t` toggle service, `o` open Web UI, `r` rescan (selected folder, else all),
  `p` pause/resume selected folder.
- **IPC**: `omarchy-shell explify.syncthing <open|close|toggle|refresh|toggleService|status>`

## How it works

`syncthingctl` (bash + curl + jq) reads the GUI address and API key from
`~/.local/state/syncthing/config.xml` (or `~/.config/syncthing/config.xml`)
and assembles one JSON blob from the Syncthing REST API. `Service.qml` polls
it on `refreshIntervalSec` (default 10s, 3s while syncing) and exposes state
to `Panel.qml`. No credentials are stored in the plugin.

## Install on another machine

The plugin directory just needs to exist under
`~/.config/omarchy/plugins/explify.syncthing/`, then:

```bash
omarchy-shell shell rescanPlugins
omarchy bar put explify.syncthing --section right
```
