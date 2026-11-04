import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../dotmatrix" as DotMatrix

// 10-LED battery meter with charging scan animation and Space Mono % readout.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property bool tooltipHovered: hover.hovered
  readonly property color inkColor: bar && bar.barForeground ? bar.barForeground : DotMatrix.Palette.fg
  readonly property color unlitColor: Qt.rgba(inkColor.r, inkColor.g, inkColor.b, 0.16)
  readonly property color mutedColor: Qt.rgba(inkColor.r, inkColor.g, inkColor.b, 0.42)
  // bar.urgent is the skin's active colour; battery/privacy alerts stay on theme urgent.
  readonly property color urgentColor: DotMatrix.Palette.danger

  readonly property var device: UPower.displayDevice
  readonly property bool present: device ? device.isLaptopBattery : false
  readonly property real level: {
    var p = device && device.percentage !== undefined ? Number(device.percentage) : 0
    return Math.max(0, Math.min(1, p > 1 ? p / 100 : p))
  }
  readonly property bool charging: device ? (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge) : false
  readonly property bool full: device ? device.state === UPowerDeviceState.FullyCharged : false
  readonly property bool low: present && !charging && level <= 0.15

  readonly property int count: 10
  readonly property int dotSize: 5
  readonly property int gap: 3
  readonly property int litCount: Math.round(level * count)
  property int scanIndex: -1

  readonly property string tipText: {
    var pct = Math.round(level * 100) + "%"
    var st = full ? "Full" : (charging ? "Charging" : "Battery")
    return st + " · " + pct
  }

  visible: present
  implicitWidth: !present ? 0 : (vertical ? 24 : meterBox.width + 6 + pctText.implicitWidth)
  implicitHeight: !present ? 0 : (vertical ? meterBox.height + 6 + pctText.implicitHeight : 20)

  function triggerPress(button) {
    Quickshell.execDetached(["omarchy-shell", "widgets", "toggleSettings"])
  }

  onTooltipHoveredChanged: {
    if (!bar) return
    if (tooltipHovered) bar.showTooltip(root, tipText)
    else bar.hideTooltip(root)
  }

  onTipTextChanged: {
    if (bar && tooltipHovered) bar.showTooltip(root, tipText)
  }

  HoverHandler { id: hover }

  Timer {
    running: root.present && root.charging && !root.full
    interval: 160
    repeat: true
    onTriggered: root.scanIndex = root.scanIndex >= root.count - 1 ? root.litCount : root.scanIndex + 1
    onRunningChanged: if (!running) root.scanIndex = -1
  }

  Item {
    id: content
    anchors.centerIn: parent
    width: root.vertical ? Math.max(meterBox.width, pctText.implicitWidth) : (meterBox.width + 6 + pctText.implicitWidth)
    height: root.vertical ? (meterBox.height + 6 + pctText.implicitHeight) : Math.max(meterBox.height, pctText.implicitHeight)

    Item {
      id: meterBox
      width: root.vertical ? root.dotSize : (root.count * root.dotSize + (root.count - 1) * root.gap)
      height: root.vertical ? (root.count * root.dotSize + (root.count - 1) * root.gap) : root.dotSize
      x: root.vertical ? Math.round((content.width - width) / 2) : 0
      y: root.vertical ? 0 : Math.round((content.height - height) / 2)

      Repeater {
        model: root.count

        Rectangle {
          required property int index

          width: root.dotSize
          height: root.dotSize
          radius: root.dotSize / 2
          x: root.vertical ? 0 : index * (root.dotSize + root.gap)
          y: root.vertical ? (root.count - 1 - index) * (root.dotSize + root.gap) : 0
          color: (index < root.litCount || index === root.scanIndex)
            ? (root.low ? root.urgentColor : root.inkColor)
            : root.unlitColor

          Behavior on color { ColorAnimation { duration: 140 } }
        }
      }
    }

    Text {
      id: pctText
      x: root.vertical ? Math.round((content.width - implicitWidth) / 2) : (meterBox.width + 6)
      y: root.vertical ? (meterBox.height + 6) : Math.round((content.height - implicitHeight) / 2)
      text: String(Math.round(root.level * 100))
      font.family: DotMatrix.Palette.fontMono
      font.pixelSize: 9
      color: root.low ? root.urgentColor : root.mutedColor
    }
  }
}
