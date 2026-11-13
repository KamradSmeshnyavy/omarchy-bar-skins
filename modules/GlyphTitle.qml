import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland
import "glyphrice"

// Из glyph-rice (bar/Bar.qml, GPL-3.0) — модуль бара kamradsmeshnyavy.bar. k — масштаб от пилюли glyph-rice (64 px) к толщине бара.
// Заголовок окна: «приложение · заголовок» меткой Space Mono, сбоку — повёрнутый. Длина — settings.length (по умолчанию 220).
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property int across: bar && bar.barSize ? bar.barSize : 32
  readonly property real k: Math.max(0.5, across / 64)
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : GTheme.fg

  readonly property var win: ToplevelManager.activeToplevel
  readonly property bool any: !!Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.toplevels.values.length > 0
  readonly property real length: (Number(settings && settings.length) || 220) * k

  implicitWidth: vertical ? across : length
  implicitHeight: vertical ? length : across
  clip: true
  Lb {
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: root.length
    rotation: root.vertical ? 90 : 0
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    visible: root.any
    text: root.win ? String(root.win.appId || "").split(".").pop() + " · " + (root.win.title || "") : ""
    px: 11 * root.k
  }
}
