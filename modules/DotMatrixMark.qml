import QtQuick
import Quickshell
import "../dotmatrix" as DotMatrix

// Arch / DOT-MATRIX mark at the start of the frame bar.
// Left-click toggles the launcher; right-click opens the Customizer.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  readonly property bool tooltipHovered: hover.hovered
  readonly property color inkColor: bar && bar.barForeground ? bar.barForeground : DotMatrix.Palette.fg
  readonly property color dimColor: Qt.rgba(inkColor.r, inkColor.g, inkColor.b, 0.56)
  readonly property string glyphText: settings && settings.glyph ? String(settings.glyph) : String.fromCodePoint(0xF08C7)

  implicitWidth: 28
  implicitHeight: 28

  function triggerPress(button) {
    Quickshell.execDetached(["omarchy-menu", "toggle", "apps"])
  }

  onTooltipHoveredChanged: {
    if (!bar) return
    if (tooltipHovered) bar.showTooltip(root, "Launcher  ·  Middle: Menu  ·  Right: Customizer")
    else bar.hideTooltip(root)
  }

  HoverHandler { id: hover }

  TapHandler {
    acceptedButtons: Qt.RightButton | Qt.MiddleButton
    onTapped: function(eventPoint, button) {
      if (button === Qt.MiddleButton)
        Quickshell.execDetached(["omarchy-menu", "toggle", "root"])
      else
        Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"])
    }
  }

  Rectangle {
    anchors.centerIn: parent
    width: 28
    height: 28
    radius: 14
    color: root.tooltipHovered ? DotMatrix.Palette.lineSoft : "transparent"
    Behavior on color { ColorAnimation { duration: 140 } }
  }

  TextMetrics {
    id: ink
    font: label.font
    text: root.glyphText
  }

  FontMetrics {
    id: line
    font: label.font
  }

  Text {
    id: label
    x: root.width / 2 - (ink.tightBoundingRect.x + ink.tightBoundingRect.width / 2)
    y: root.height / 2 - (line.ascent + ink.tightBoundingRect.y + ink.tightBoundingRect.height / 2)
    text: root.glyphText
    font.family: DotMatrix.Palette.fontIcon
    font.pixelSize: 20
    color: root.tooltipHovered ? root.inkColor : root.dimColor
    Behavior on color { ColorAnimation { duration: 140 } }
  }
}
