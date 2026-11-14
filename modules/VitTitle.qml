import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons as Commons

// Заголовок окна Vitreus (по мотивам natepayn3/Vitreus, MIT; код свой) — модуль бара kamradsmeshnyavy.bar.
// Две строки: приложение крупнее и жирнее (17), под ним заголовок (13.5), оба обрезаются многоточием; сбоку — повёрнуто
// вдоль полосы. Длина — settings.length (по умолчанию 220). Нет окна — пусто. Клик — дашборд (календарь, плеер).
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property int across: bar && bar.barSize ? bar.barSize : 32
  readonly property real k: Math.max(0.55, across / 62)
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : Commons.Color.foreground
  readonly property string sans: bar && bar.fontFamily ? bar.fontFamily : "sans-serif"

  readonly property var win: ToplevelManager.activeToplevel
  readonly property bool any: !!Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.toplevels.values.length > 0 && !!win
  readonly property string app: {
    if (!win) return ""
    var id = String(win.appId || "").split(".").pop()
    return id.length ? id.charAt(0).toUpperCase() + id.slice(1) : ""
  }
  readonly property real length: (Number(settings && settings.length) || 220) * k

  implicitWidth: vertical ? across : length
  implicitHeight: vertical ? length : across
  clip: true

  Column {
    id: lines
    visible: root.any
    width: root.length - 16 * root.k
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    rotation: root.vertical ? -90 : 0
    spacing: 0
    Text {
      width: parent.width
      text: root.app
      elide: Text.ElideRight
      font.family: root.sans
      font.pixelSize: Math.round(Math.min(17 * root.k, root.across * 0.36))
      font.weight: Font.DemiBold
      color: root.fg
    }
    Text {
      width: parent.width
      text: root.win ? String(root.win.title || "") : ""
      elide: Text.ElideRight
      font.family: root.sans
      font.pixelSize: Math.round(Math.min(13.5 * root.k, root.across * 0.28))
      font.weight: Font.Medium
      color: root.fg
      opacity: 0.62
    }
  }
  HoverHandler { cursorShape: Qt.PointingHandCursor }
  TapHandler { onTapped: Quickshell.execDetached(["omarchy-shell", "widgets", "toggleDashboard"]) }
}
