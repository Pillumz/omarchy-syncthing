import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "explify.syncthing"
  ipcTarget: "explify.syncthing"
  manageIpc: false

  property string focusSection: "header"
  property int folderIndex: 0
  property int deviceIndex: 0
  property bool cursorActive: false
  property int phraseIndex: 0
  readonly property var syncPhrases: [
    "Shoveling bytes",
    "Comparing hashes",
    "Negotiating blocks",
    "Herding files",
    "Reconciling realities",
    "Moving the truth around",
    "Deduplicating destiny",
    "Chasing deltas"
  ]

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "transparent"

  readonly property bool showFolders: syncthing.active && syncthing.folders.length > 0
  readonly property bool showDevices: syncthing.active && syncthing.devices.length > 0
  readonly property bool syncing: syncthing.overall === "syncing" || syncthing.overall === "scanning"
  readonly property color iconColor: syncthing.active ? foreground : dim
  readonly property color barIconColor: syncthing.active ? barForeground : Qt.darker(barForeground, 1.55)
  readonly property string toggleHint: syncthing.active ? "Stop Syncthing" : "Start Syncthing"

  readonly property string heroMeta: {
    if (!syncthing.installed) return "No Syncthing config found"
    if (!syncthing.active) return "Syncthing is stopped"
    if (syncthing.overall === "error") return "Sync errors — check folders"
    if (syncthing.overall === "syncing")
      return syncPhrases[phraseIndex % syncPhrases.length] + " · " + Math.floor(syncthing.syncPercent) + "%"
    if (syncthing.overall === "scanning") return "Scanning folders"
    if (syncthing.overall === "paused") return "All folders paused"
    if (syncthing.overall === "idle") return "Up to date"
    return "Checking…"
  }

  function selectedFolder() {
    if (syncthing.folders.length === 0) return null
    return syncthing.folders[Math.max(0, Math.min(folderIndex, syncthing.folders.length - 1))]
  }

  function selectedDevice() {
    if (syncthing.devices.length === 0) return null
    return syncthing.devices[Math.max(0, Math.min(deviceIndex, syncthing.devices.length - 1))]
  }

  function ensureCursor() {
    if (folderIndex >= syncthing.folders.length) folderIndex = Math.max(0, syncthing.folders.length - 1)
    if (deviceIndex >= syncthing.devices.length) deviceIndex = Math.max(0, syncthing.devices.length - 1)
    if (focusSection === "folders" && !showFolders) focusSection = showDevices ? "devices" : "header"
    if (focusSection === "devices" && !showDevices) focusSection = showFolders ? "folders" : "header"
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    ensureCursor()
    if (dy === 0) return
    if (focusSection === "header") {
      if (dy > 0) {
        if (showFolders) { focusSection = "folders"; folderIndex = 0 }
        else if (showDevices) { focusSection = "devices"; deviceIndex = 0 }
        else focusSection = "webui"
      }
    } else if (focusSection === "folders") {
      if (dy < 0) {
        if (folderIndex <= 0) focusSection = "header"
        else folderIndex--
      } else {
        if (folderIndex < syncthing.folders.length - 1) folderIndex++
        else if (showDevices) { focusSection = "devices"; deviceIndex = 0 }
        else focusSection = "webui"
      }
    } else if (focusSection === "devices") {
      if (dy < 0) {
        if (deviceIndex <= 0) focusSection = showFolders ? "folders" : "header"
        else deviceIndex--
      } else {
        if (deviceIndex < syncthing.devices.length - 1) deviceIndex++
        else focusSection = "webui"
      }
    } else if (focusSection === "webui") {
      if (dy < 0) {
        if (showDevices) focusSection = "devices"
        else if (showFolders) focusSection = "folders"
        else focusSection = "header"
      }
    }
    ensureCursor()
    scrollCursorIntoView()
  }

  function activateCursor() {
    ensureCursor()
    if (focusSection === "header") syncthing.toggleService()
    else if (focusSection === "folders") syncthing.openFolder(selectedFolder())
    else if (focusSection === "devices") syncthing.copyDeviceId(selectedDevice())
    else if (focusSection === "webui") openWebUIAndClose()
  }

  function openWebUIAndClose() {
    syncthing.openWebUI()
    close()
  }

  function scrollItemIntoView(item) {
    if (!panelFlick || !item) return
    Qt.callLater(function() {
      if (!item) return
      var margin = Style.space(6)
      var point = item.mapToItem(panelFlick.contentItem, 0, 0)
      var top = point.y
      var bottom = top + item.height
      var viewTop = panelFlick.contentY
      var viewBottom = viewTop + panelFlick.height
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (top < viewTop + margin) panelFlick.contentY = Math.max(0, top - margin)
      else if (bottom > viewBottom - margin) panelFlick.contentY = Math.min(maxY, bottom + margin - panelFlick.height)
    })
  }

  function scrollCursorIntoView() {
    if (focusSection === "folders" && folderColumn && folderIndex >= 0 && folderIndex < folderColumn.children.length)
      scrollItemIntoView(folderColumn.children[folderIndex])
    else if (focusSection === "devices" && deviceColumn && deviceIndex >= 0 && deviceIndex < deviceColumn.children.length)
      scrollItemIntoView(deviceColumn.children[deviceIndex])
  }

  function setFolderCursor(index) {
    cursorActive = true
    focusSection = "folders"
    folderIndex = index
  }

  function setDeviceCursor(index) {
    cursorActive = true
    focusSection = "devices"
    deviceIndex = index
  }

  function setHeaderCursor() {
    cursorActive = true
    focusSection = "header"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    if (panelFlick) panelFlick.contentY = 0
    syncthing.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  onFolderIndexChanged: scrollCursorIntoView()
  onDeviceIndexChanged: scrollCursorIntoView()
  onShowFoldersChanged: ensureCursor()
  onShowDevicesChanged: ensureCursor()

  Service {
    id: syncthing
    settings: root.settings
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { syncthing.refresh(); return "ok" }
    function toggleService(): string { syncthing.toggleService(); return "ok" }
    function status(): string { return syncthing.overall }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        SyncthingIcon {
          anchors.centerIn: parent
          iconSize: Style.space(11)
          color: root.barIconColor
          badgeColor: root.urgent
          crossed: !syncthing.active
          warning: syncthing.overall === "error"
          spinning: root.syncing
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) syncthing.openWebUI()
      else if (buttonCode === Qt.MiddleButton) syncthing.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "t" || t === "T") syncthing.toggleService()
        else if (t === "o" || t === "O") root.openWebUIAndClose()
        else if (t === "r" || t === "R") syncthing.rescan(root.focusSection === "folders" && root.selectedFolder() ? root.selectedFolder().id : "")
        else if ((t === "p" || t === "P") && root.focusSection === "folders" && root.selectedFolder())
          syncthing.setFolderPaused(root.selectedFolder().id, !root.selectedFolder().paused)
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          Item {
            id: header
            width: parent.width
            implicitHeight: hero.implicitHeight
            readonly property bool ringVisible: root.cursorActive && root.focusSection === "header" && syncthing.installed
            function focusHero() { root.setHeaderCursor() }

            PanelHero {
              id: hero
              width: parent.width
              title: syncthing.myName !== "" ? syncthing.myName : "Syncthing"
              meta: root.heroMeta
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: syncthing.active ? 1.0 : 0.5
              iconComponent: Component {
                SyncthingIcon {
                  iconSize: Style.font.display
                  color: root.iconColor
                  badgeColor: root.urgent
                  crossed: !syncthing.active
                  warning: syncthing.overall === "error"
                  spinning: root.syncing
                }
              }

              trailingControl: Component {
                ToggleSwitch {
                  id: powerSwitch
                  visible: syncthing.installed
                  checked: syncthing.active
                  busy: syncthing.busy
                  hasCursor: header.ringVisible
                  foreground: hero.foreground
                  onHovered: function(on) { if (on) header.focusHero() }
                  onToggled: syncthing.toggleService()

                  PanelToolTip {
                    visible: powerSwitch.containsMouse
                    text: root.toggleHint
                    fontFamily: hero.fontFamily
                  }
                }
              }
            }
          }

          Text {
            visible: syncthing.actionStatus !== "" || syncthing.lastError !== ""
            width: parent.width
            text: syncthing.actionStatus !== "" ? syncthing.actionStatus : syncthing.lastError
            color: syncthing.lastError !== "" && syncthing.actionStatus === "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          CursorSurface {
            visible: !syncthing.installed
            width: parent.width
            implicitHeight: missingText.implicitHeight + Style.spacing.rowPaddingX
            foreground: root.foreground

            Text {
              id: missingText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(12)
              text: "Syncthing config not found. Is syncthing installed and started once?"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator {
            visible: root.showFolders
            foreground: root.foreground
          }

          Column {
            visible: root.showFolders
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "FOLDERS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              id: folderColumn
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: syncthing.folders
                FolderRow {
                  required property var modelData
                  required property int index
                  width: folderColumn.width
                  folder: modelData
                  rowIndex: index
                }
              }
            }
          }

          PanelSeparator {
            visible: root.showDevices
            foreground: root.foreground
          }

          Column {
            visible: root.showDevices
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "DEVICES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              id: deviceColumn
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: syncthing.devices
                DeviceRow {
                  required property var modelData
                  required property int index
                  width: deviceColumn.width
                  device: modelData
                  rowIndex: index
                }
              }
            }
          }

          PanelSeparator {
            visible: syncthing.active
            foreground: root.foreground
          }

          WebUiRow {
            visible: syncthing.active
            width: parent.width
          }
        }
      }
    }
  }

  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened && root.syncing
    repeat: true
    onTriggered: root.phraseIndex = (root.phraseIndex + 1) % root.syncPhrases.length
  }

  component FolderRow: CursorSurface {
    id: folderRow
    property var folder: null
    property int rowIndex: 0
    readonly property bool folderPaused: folder && folder.paused === true
    readonly property bool folderBusy: folder && (folder.state === "syncing" || folder.state === "scanning" || folder.state === "sync-preparing")
    readonly property bool folderTrouble: folder && (folder.errors > 0 || folder.state === "error" || folder.state === "outofsync")

    hasCursor: root.cursorActive && root.focusSection === "folders" && root.folderIndex === rowIndex
    foreground: root.foreground
    fill: root.hoverFill

    implicitHeight: Math.max(folderContent.implicitHeight, pauseButton.implicitHeight) + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) root.setFolderCursor(folderRow.rowIndex)
      onClicked: syncthing.openFolder(folderRow.folder)
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: folderRow.folderPaused ? "󰏤" : "󰉋"
        color: folderRow.folderTrouble ? root.urgent : (folderRow.folderPaused ? root.dim : root.foreground)
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        id: folderContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: folderRow.folder ? String(folderRow.folder.label || folderRow.folder.id) : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: {
            var parts = [syncthing.folderStatusText(folderRow.folder)]
            if (folderRow.folder && folderRow.folder.path) parts.push(syncthing.prettyPath(folderRow.folder.path))
            return parts.join(" · ")
          }
          color: folderRow.folderTrouble ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      PanelActionButton {
        visible: !folderRow.folderPaused
        iconText: "󰑐"
        tooltipText: "Rescan"
        foreground: root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: syncthing.rescan(folderRow.folder ? folderRow.folder.id : "")
      }

      PanelActionButton {
        id: pauseButton
        iconText: folderRow.folderPaused ? "󰐊" : "󰏤"
        tooltipText: folderRow.folderPaused ? "Resume" : "Pause"
        foreground: root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: if (folderRow.folder) syncthing.setFolderPaused(folderRow.folder.id, !folderRow.folderPaused)
      }
    }
  }

  component DeviceRow: CursorSurface {
    id: deviceRow
    property var device: null
    property int rowIndex: 0
    readonly property bool connected: device && device.connected === true
    readonly property string deviceName: device ? String(device.name || "Unknown") : "Unknown"

    hasCursor: root.cursorActive && root.focusSection === "devices" && root.deviceIndex === rowIndex
    foreground: root.foreground
    fill: root.hoverFill

    implicitHeight: Math.max(deviceContent.implicitHeight, copyButton.implicitHeight) + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onContainsMouseChanged: if (containsMouse) root.setDeviceCursor(deviceRow.rowIndex)
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: "󰇅"
        color: deviceRow.connected ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        id: deviceContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: deviceRow.deviceName
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: {
            if (deviceRow.connected)
              return "Connected" + (deviceRow.device.address !== "" ? " · " + deviceRow.device.address : "")
            var seen = syncthing.relativeTime(deviceRow.device ? deviceRow.device.lastSeen : "")
            return seen !== "" ? "Last seen " + seen : "Disconnected"
          }
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      PanelActionButton {
        id: copyButton
        iconText: "󰆏"
        tooltipText: "Copy device ID"
        foreground: root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: syncthing.copyDeviceId(deviceRow.device)
      }
    }
  }

  component WebUiRow: CursorSurface {
    id: webUiRow

    hasCursor: root.cursorActive && root.focusSection === "webui"
    foreground: root.foreground
    fill: root.hoverFill

    implicitHeight: webUiInner.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) { root.cursorActive = true; root.focusSection = "webui" }
      onClicked: root.openWebUIAndClose()
    }

    RowLayout {
      id: webUiInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: "󰖟"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: "Open Web UI"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: "http://" + syncthing.guiAddress
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }
}
