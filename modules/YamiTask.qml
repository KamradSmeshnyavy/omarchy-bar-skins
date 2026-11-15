import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons as Commons

// Активное окно yami (по мотивам Trendorin/yami, MIT; код свой) — модуль бара kamradsmeshnyavy.bar: кнопка, залитая
// акцентом, со значком «›_» и «приложение — заголовок» пиксельным шрифтом бара. Ширина — settings.width (190, как
// taskWidth у yami). Нет окна — модуль пустой. Клик — обзор столов.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: !!bar && bar.vertical === true
  readonly property int across: bar && bar.barSize ? bar.barSize : 30
  readonly property string font: bar && bar.fontFamily ? bar.fontFamily : "Tiny5"
  readonly property color acc: Commons.Color.accent
  readonly property real len: Math.max(60, Number(settings && settings.width) || 190)

  readonly property var win: ToplevelManager.activeToplevel
  readonly property bool any: !!win && !!Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.toplevels.values.length > 0
  readonly property string label: {
    if (!win) return ""
    var app = String(win.appId || "").split(".").pop()
    var t = String(win.title || "")
    return t && app && t.toLowerCase().indexOf(app.toLowerCase()) === -1 ? t + " — " + app : (t || app)
  }

  implicitWidth: vertical ? across : (any ? len : 0)
  implicitHeight: vertical ? (any ? len : 0) : across
  visible: any

  Rectangle {
    anchors.centerIn: parent
    width: root.vertical ? Math.round(root.across * 0.7) : root.len
    height: root.vertical ? root.len : Math.round(root.across * 0.7)
    color: hov.hovered ? Qt.lighter(root.acc, 1.15) : root.acc
    border.width: 1
    border.color: Qt.lighter(root.acc, 1.3)
    clip: true
    Row {
      x: 6
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6
      rotation: root.vertical ? 90 : 0
      Text { text: "›_"; color: "white"; font.family: root.font; font.pixelSize: Math.round(root.across * 0.42) }
      Text {
        width: root.len - 34
        elide: Text.ElideRight
        text: root.label
        color: "white"
        font.family: root.font
        font.pixelSize: Math.round(root.across * 0.42)
      }
    }
  }
  HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
  function triggerPress(button) { Quickshell.execDetached(["omarchy-shell", "widgets", "toggleOverview"]) }
}
