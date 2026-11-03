import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Focused window icon, desaturated like Nothing's monochrome icon pack;
// regains colour on hover.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  readonly property var activeToplevel: ToplevelManager.activeToplevel
  readonly property string appId: activeToplevel && activeToplevel.appId ? String(activeToplevel.appId) : ""
  readonly property string appTitle: activeToplevel && activeToplevel.title ? String(activeToplevel.title) : appId
  readonly property bool hasActive: appId !== ""
  readonly property bool tooltipHovered: hover.hovered

  visible: hasActive
  implicitWidth: hasActive ? 26 : 0
  implicitHeight: hasActive ? 26 : 0

  function resolveIcon(cls) {
    if (!cls) return Quickshell.iconPath("application-x-executable", true)
    var entry = (typeof DesktopEntries.heuristicLookup === "function")
      ? DesktopEntries.heuristicLookup(cls)
      : DesktopEntries.byId(cls)
    var name = entry && entry.icon ? String(entry.icon) : cls
    if (name.indexOf("/") === 0) return "file://" + name
    if (name.indexOf("://") > 0) return name
    return Quickshell.iconPath(name, true) || Quickshell.iconPath("application-x-executable", true)
  }

  onTooltipHoveredChanged: {
    if (!bar) return
    if (tooltipHovered && appTitle) bar.showTooltip(root, appTitle)
    else bar.hideTooltip(root)
  }

  onAppTitleChanged: {
    if (bar && tooltipHovered && appTitle) bar.showTooltip(root, appTitle)
  }

  HoverHandler { id: hover }

  IconImage {
    anchors.centerIn: parent
    width: 22
    height: 22
    source: root.resolveIcon(root.appId)

    layer.enabled: true
    layer.effect: MultiEffect {
      saturation: root.tooltipHovered ? 0 : -1
      brightness: root.tooltipHovered ? 0 : -0.05
      Behavior on saturation { NumberAnimation { duration: 180 } }
    }
  }
}
