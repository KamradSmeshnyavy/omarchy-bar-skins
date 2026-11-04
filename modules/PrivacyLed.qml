import QtQuick
import Quickshell.Services.Pipewire
import "../dotmatrix" as DotMatrix

// Pulsing red privacy LED visible whenever an application is capturing audio.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  readonly property bool tooltipHovered: hover.hovered
  // bar.urgent is the skin's active colour; battery/privacy alerts stay on theme urgent.
  readonly property color urgentColor: DotMatrix.Palette.danger

  readonly property bool micInUse: {
    var nodes = Pipewire.nodes && Pipewire.nodes.values ? Pipewire.nodes.values : []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (!n || !n.audio || !n.isStream || n.isSink) continue
      var label = String(n.name || "") + " " + String(n.description || "")
      if (!/cava|pavucontrol|quickshell/i.test(label)) return true
    }
    return false
  }

  visible: micInUse
  implicitWidth: micInUse ? 12 : 0
  implicitHeight: micInUse ? 12 : 0

  onTooltipHoveredChanged: {
    if (!bar) return
    if (tooltipHovered && micInUse) bar.showTooltip(root, "Microphone active")
    else bar.hideTooltip(root)
  }

  HoverHandler { id: hover }

  Rectangle {
    id: led
    anchors.centerIn: parent
    width: 6
    height: 6
    radius: 3
    color: root.urgentColor

    SequentialAnimation on opacity {
      running: root.micInUse
      loops: Animation.Infinite
      NumberAnimation { to: 0.25; duration: 900; easing.type: Easing.InOutSine }
      NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
    }
  }
}
