import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property color badgeColor: Color.urgent
  property bool crossed: false
  property bool warning: false
  property bool spinning: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  // Native rendering of the Syncthing mark: a circle with a hub node right of
  // center, spoked to three rim nodes. Canvas keeps it crisp at bar sizes
  // where the official SVG turns to mush.
  Canvas {
    id: canvas
    anchors.fill: parent

    // The mark spins while a sync is in flight, mirroring the tray icon.
    RotationAnimation on rotation {
      running: root.spinning
      from: 0
      to: 360
      duration: 1600
      loops: Animation.Infinite
    }

    onPaint: {
      var ctx = getContext("2d")
      var w = width
      var c = w / 2
      var line = Math.max(1.1, w * 0.085)
      var r = c - line
      var dot = Math.max(1.4, w * 0.115)
      var hub = { x: c + r * 0.42, y: c }
      var rim = [
        { x: c + r, y: c },
        { x: c + r * Math.cos(2.42), y: c - r * Math.sin(2.42) },
        { x: c + r * Math.cos(2.42), y: c + r * Math.sin(2.42) }
      ]

      ctx.reset()
      ctx.strokeStyle = root.color
      ctx.fillStyle = root.color
      ctx.lineWidth = line
      ctx.lineCap = "round"

      ctx.beginPath()
      ctx.arc(c, c, r, 0, 2 * Math.PI)
      ctx.stroke()

      for (var i = 0; i < rim.length; i++) {
        ctx.beginPath()
        ctx.moveTo(hub.x, hub.y)
        ctx.lineTo(rim[i].x, rim[i].y)
        ctx.stroke()
      }

      ctx.beginPath()
      ctx.arc(hub.x, hub.y, dot, 0, 2 * Math.PI)
      ctx.fill()
      for (var j = 0; j < rim.length; j++) {
        ctx.beginPath()
        ctx.arc(rim[j].x, rim[j].y, dot, 0, 2 * Math.PI)
        ctx.fill()
      }
    }
  }

  onColorChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onSpinningChanged: if (!spinning) canvas.rotation = 0

  Rectangle {
    visible: root.crossed
    anchors.centerIn: parent
    width: parent.width * 1.22
    height: Math.max(2, parent.height * 0.14)
    radius: height / 2
    color: root.color
    rotation: -45
  }

  BorderSurface {
    visible: root.warning
    width: Math.max(7, parent.width * 0.42)
    height: width
    radius: width / 2
    color: root.badgeColor
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    borderSpec: Border.flat(Color.popups.background, 1)

    Text {
      anchors.centerIn: parent
      text: "!"
      color: Color.background
      font.family: Style.font.family
      font.pixelSize: Math.max(6, parent.height * 0.72)
      font.bold: true
    }
  }
}
