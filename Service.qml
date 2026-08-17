import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var settings: ({})

  property bool installed: true
  property bool serviceRunning: false

  // Optimistic state so the toggle reacts instantly; -1 follows reality,
  // 0/1 while a systemctl start/stop is still catching up.
  property int _desired: -1
  readonly property bool active: _desired === -1 ? serviceRunning : (_desired === 1)

  property string overall: "unknown"
  property real syncPercent: 100
  property string myName: ""
  property string myID: ""
  property string guiAddress: "127.0.0.1:8384"
  property var folders: []
  property var devices: []
  property string actionStatus: ""
  property string lastError: ""

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 10, 2, 3600)
  readonly property bool busy: statusProcess.running || actionProcess.running || serviceProcess.running
  readonly property string helperPath: {
    var u = Qt.resolvedUrl("syncthingctl").toString()
    return u.indexOf("file://") === 0 ? decodeURIComponent(u.substring(7)) : u
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    if (n < min) n = min
    if (n > max) n = max
    return n
  }

  function formatBytes(bytes) {
    var n = Number(bytes) || 0
    if (n < 1024) return n + " B"
    var units = ["KB", "MB", "GB", "TB"]
    var i = -1
    do { n /= 1024; i++ } while (n >= 1024 && i < units.length - 1)
    return (n >= 100 ? Math.round(n) : n.toFixed(1)) + " " + units[i]
  }

  function relativeTime(isoString) {
    var text = String(isoString || "")
    if (text === "") return ""
    var then = new Date(text).getTime()
    if (!isFinite(then) || then <= 0) return ""
    var mins = Math.floor((Date.now() - then) / 60000)
    if (mins < 1) return "just now"
    if (mins < 60) return mins + "m ago"
    var hours = Math.floor(mins / 60)
    if (hours < 24) return hours + "h ago"
    var days = Math.floor(hours / 24)
    if (days < 30) return days + "d ago"
    return new Date(text).toLocaleDateString(Qt.locale(), Locale.ShortFormat)
  }

  function prettyPath(path) {
    var home = Quickshell.env("HOME") || ""
    var p = String(path || "")
    return home !== "" && p.indexOf(home) === 0 ? "~" + p.substring(home.length) : p
  }

  function folderStatusText(folder) {
    if (!folder) return ""
    var state = String(folder.state || "unknown")
    if (state === "paused") return "Paused"
    if (folder.errors > 0) return folder.errors + (folder.errors === 1 ? " error" : " errors")
    if (state === "syncing" || state === "sync-preparing")
      return "Syncing · " + Math.floor(folder.completion) + "%"
    if (state === "scanning") return "Scanning"
    if (folder.needBytes > 0) return formatBytes(folder.needBytes) + " behind"
    if (state === "idle") return "Up to date"
    return state.charAt(0).toUpperCase() + state.slice(1)
  }

  function copyToClipboard(value) {
    var text = String(value || "")
    if (text === "") return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(text) + " | wl-copy"])
  }

  function refresh() {
    if (statusProcess.running) return
    statusProcess.command = ["bash", helperPath, "status"]
    statusProcess.running = true
    if (!pollWatchdog.running) pollWatchdog.start()
  }

  function applyStatus(raw) {
    var data
    try {
      data = JSON.parse(raw)
    } catch (e) {
      lastError = "Could not parse Syncthing status"
      return
    }
    installed = data.installed !== false
    serviceRunning = data.running === true
    if (_desired !== -1 && serviceRunning === (_desired === 1)) _desired = -1
    if (!serviceRunning) {
      overall = "stopped"
      folders = []
      devices = []
      lastError = ""
      return
    }
    overall = String(data.overall || "unknown")
    syncPercent = Number(data.syncPercent) || 0
    myName = String(data.myName || "")
    myID = String(data.myID || "")
    guiAddress = String(data.guiAddress || "127.0.0.1:8384")
    folders = data.folders || []
    devices = data.devices || []
    lastError = ""
  }

  function toggleService() {
    if (serviceProcess.running) return
    var starting = !active
    _desired = starting ? 1 : 0
    serviceProcess.command = ["systemctl", "--user", starting ? "start" : "stop", "syncthing.service"]
    serviceProcess.running = true
  }

  function rescan(folderId) {
    var args = ["bash", helperPath, "rescan"]
    if (folderId) args.push(String(folderId))
    runAction(args, folderId ? "Rescanning " + folderId + "…" : "Rescanning all folders…")
  }

  function setFolderPaused(folderId, paused) {
    if (!folderId) return
    runAction(["bash", helperPath, "setpaused", String(folderId), paused ? "true" : "false"],
              (paused ? "Pausing " : "Resuming ") + folderId + "…")
  }

  function runAction(command, label) {
    if (actionProcess.running) return
    actionStatus = label || ""
    actionProcess.command = command
    actionProcess.running = true
  }

  function openWebUI() {
    Quickshell.execDetached(["omarchy-launch-browser", "http://" + guiAddress])
  }

  function openFolder(folder) {
    if (!folder || !folder.path) return
    Quickshell.execDetached(["xdg-open", String(folder.path)])
  }

  function copyDeviceId(device) {
    if (!device) return
    copyToClipboard(device.id)
    actionStatus = "Copied " + String(device.name || "device") + " ID"
    actionStatusTimer.restart()
  }

  Timer {
    id: refreshTimer
    // Tighten the poll while a sync is in flight so progress actually moves.
    interval: (root.overall === "syncing" || root.overall === "scanning")
      ? Math.min(3000, root.refreshIntervalSec * 1000)
      : root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    // After a service start the REST API needs a moment; poll quickly until
    // it answers or ~20 seconds pass.
    id: startupRamp
    property int ticks: 0
    interval: 2000
    repeat: true
    running: false
    onTriggered: {
      ticks += 1
      if (root.serviceRunning || ticks >= 10) startupRamp.running = false
      else root.refresh()
    }
  }

  Timer {
    id: delayedRefresh
    interval: 800
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    // A hung curl would silently stop all future polls; reap it well inside
    // the refresh interval so the next tick starts clean.
    id: pollWatchdog
    interval: 15000
    repeat: false
    onTriggered: if (statusProcess.running) statusProcess.running = false
  }

  Timer {
    id: actionStatusTimer
    interval: 2200
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var out = String(statusStdout.text || "")
      if (exitCode === 0 && out.trim() !== "") root.applyStatus(out)
      else root.lastError = "Syncthing status check failed"
    }
  }

  Process {
    id: actionProcess
    running: false
    command: []
    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = String(actionStderr.text || actionStdout.text || "Syncthing action failed").trim()
        root.actionStatus = ""
      } else {
        root.lastError = ""
      }
      actionStatusTimer.restart()
      delayedRefresh.restart()
    }
  }

  Process {
    id: serviceProcess
    running: false
    command: []
    stderr: StdioCollector { id: serviceStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root._desired = -1
        root.lastError = String(serviceStderr.text || "systemctl failed").trim()
      } else {
        root.lastError = ""
        startupRamp.ticks = 0
        startupRamp.running = true
      }
      delayedRefresh.restart()
    }
  }
}
