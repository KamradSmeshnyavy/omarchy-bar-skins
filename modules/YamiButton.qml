import QtQuick
import Quickshell
import qs.Commons as Commons

// Кнопка yami (по мотивам Trendorin/yami, MIT; код свой) — модуль бара kamradsmeshnyavy.bar: значок в квадратной ячейке.
// settings.icon — что нарисовать: grid (лаунчер: четыре квадрата, рисуется сам), gear, power — или любой знак Nerd Font;
// settings.command — команда (bash -c); settings.boxed: true — ячейка с рамкой (как у питания у yami).
// Значения по умолчанию по icon: grid — лаунчер Omarchy, gear — Customizer, power — меню выключения.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 30
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : Commons.Color.foreground
  readonly property string icon: String(settings && settings.icon || "grid")
  readonly property bool boxed: settings && settings.boxed !== undefined ? settings.boxed === true : icon === "power"
  readonly property var defaults: ({
    grid: "omarchy-menu toggle root",
    gear: "omarchy-shell shell toggle kamradsmeshnyavy.customizer",
    power: "omarchy-shell widgets togglePower"
  })
  readonly property string command: String(settings && settings.command || defaults[icon] || "")
  readonly property string glyph: icon === "gear" ? "󰒓" : icon === "power" ? "󰐥" : icon
  readonly property real cell: Math.max(16, Math.round(across * 0.66))

  implicitWidth: across
  implicitHeight: across

  Rectangle {
    anchors.centerIn: parent
    width: root.cell; height: root.cell
    color: hov.hovered ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.14) : root.boxed ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06) : "transparent"
    border.width: root.boxed ? 1 : 0
    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.3)
    // лаунчер: четыре квадрата
    Grid {
      visible: root.icon === "grid"
      anchors.centerIn: parent
      columns: 2; spacing: 2
      Repeater { model: 4; Rectangle { width: Math.round(root.cell * 0.24); height: width; color: root.fg; opacity: 0.8 } }
    }
    Text {
      visible: root.icon !== "grid"
      anchors.centerIn: parent
      text: root.glyph
      color: root.fg
      opacity: hov.hovered ? 1 : 0.75
      font.family: Commons.Style.font.family
      font.pixelSize: Math.round(root.cell * 0.66)
    }
  }
  HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
  function triggerPress(button) { if (root.command) Quickshell.execDetached(["bash", "-c", root.command]) }
}
