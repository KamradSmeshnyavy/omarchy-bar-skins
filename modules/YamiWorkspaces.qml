import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons as Commons

// Столы yami (по мотивам Trendorin/yami, MIT; код свой) — модуль бара kamradsmeshnyavy.bar.
// Квадратные ячейки с номером: занятые и текущий; текущий — светлая заливка, остальные — только рамка. Стол, где окно
// просит внимания, — ячейка цветом акцента. Клик — перейти, колесо — соседний.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: !!bar && bar.vertical === true
  readonly property int across: bar && bar.barSize ? bar.barSize : 30
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : Commons.Color.foreground
  readonly property color acc: Commons.Color.accent
  readonly property string font: bar && bar.fontFamily ? bar.fontFamily : "Tiny5"
  readonly property real cell: Math.max(16, Math.round(across * 0.62))

  readonly property int active: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
  readonly property var marks: {
    var ids = Hyprland.workspaces.values.filter(function(w) { return w.id > 0 && w.id <= 10 && w.toplevels.values.length > 0 }).map(function(w) { return w.id })
    if (active > 0 && ids.indexOf(active) === -1) ids.push(active)
    ids.sort(function(a, b) { return a - b })
    return ids
  }
  function urgentOf(id) {
    var w = Hyprland.workspaces.values.find(function(x) { return x.id === id })
    return !!w && w.urgent === true
  }
  function go(ws) { Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = '" + ws + "' }))"]) }

  implicitWidth: vertical ? across : grid.implicitWidth + 8
  implicitHeight: vertical ? grid.implicitHeight + 8 : across

  Grid {
    id: grid
    anchors.centerIn: parent
    columns: root.vertical ? 1 : Math.max(1, root.marks.length)
    spacing: 5
    Repeater {
      model: root.marks
      Rectangle {
        id: c
        required property var modelData
        readonly property int n: modelData
        readonly property bool on: n === root.active
        readonly property bool urg: !on && root.urgentOf(n)
        width: root.cell; height: root.cell
        color: on ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.42) : urg ? root.acc : hov.hovered ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12) : "transparent"
        border.width: 1
        border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, on ? 0.6 : 0.22)
        Text {
          anchors.centerIn: parent
          text: c.n === 10 ? "0" : String(c.n)
          color: c.on ? Commons.Color.background : root.fg
          opacity: c.on || c.urg ? 1 : 0.75
          font.family: root.font
          font.pixelSize: Math.round(root.cell * 0.62)
        }
        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        // клики бар передаёт через свою область нажатий (triggerPress)
        function triggerPress(button) { root.go(c.n) }
        property BarClick click: BarClick { bar: root.bar; target: c }
      }
    }
  }
  WheelHandler { onWheel: function(e) { root.go(e.angleDelta.y > 0 ? "e-1" : "e+1") } }
}
