import QtQuick
import Quickshell
import "../dotmatrix" as DotMatrix

// Dot-matrix clock in Doto Bold: stacked HH over mm on vertical bars,
// inline HH:mm on horizontal bars. Click opens the dashboard.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property bool tooltipHovered: hover.hovered
  readonly property color inkColor: bar && bar.barForeground ? bar.barForeground : DotMatrix.Palette.fg
  readonly property color dimColor: Qt.rgba(inkColor.r, inkColor.g, inkColor.b, 0.56)
  readonly property string dateTip: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")

  implicitWidth: vertical ? 36 : horizontalRow.implicitWidth + 8
  implicitHeight: vertical ? verticalCol.implicitHeight : 26

  function triggerPress(button) {
    Quickshell.execDetached(["omarchy-shell", "widgets", "toggleDashboard"])
  }

  onTooltipHoveredChanged: {
    if (!bar) return
    if (tooltipHovered) bar.showTooltip(root, dateTip)
    else bar.hideTooltip(root)
  }

  onDateTipChanged: {
    if (bar && tooltipHovered) bar.showTooltip(root, dateTip)
  }

  HoverHandler { id: hover }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Column {
    id: verticalCol
    visible: root.vertical
    anchors.centerIn: parent
    spacing: -6

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDateTime(clock.date, "HH")
      font.family: DotMatrix.Palette.fontDot
      font.weight: Font.Bold
      font.pixelSize: 20
      color: root.inkColor
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDateTime(clock.date, "mm")
      font.family: DotMatrix.Palette.fontDot
      font.weight: Font.Bold
      font.pixelSize: 20
      color: root.dimColor
    }
  }

  Row {
    id: horizontalRow
    visible: !root.vertical
    anchors.centerIn: parent
    spacing: 1

    Text {
      text: Qt.formatDateTime(clock.date, "HH")
      font.family: DotMatrix.Palette.fontDot
      font.weight: Font.Bold
      font.pixelSize: 18
      color: root.inkColor
    }

    Text {
      text: ":"
      font.family: DotMatrix.Palette.fontDot
      font.weight: Font.Bold
      font.pixelSize: 18
      color: root.dimColor
    }

    Text {
      text: Qt.formatDateTime(clock.date, "mm")
      font.family: DotMatrix.Palette.fontDot
      font.weight: Font.Bold
      font.pixelSize: 18
      color: root.dimColor
    }
  }
}
