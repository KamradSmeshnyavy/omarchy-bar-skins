import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import qs.Commons as Commons

// Столы Rumda (по мотивам hexonide/rumda; код свой): карточка со столбиком наклонных штрихов — по одному на стол
// (пять или до последнего занятого); текущий — сплошной штрих цветом акцента, занятые — акцент в полтона, пустые —
// тусклые. Клик — перейти, колесо — соседний.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 48
  readonly property int active: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
  readonly property int count: {
    var ids = Hyprland.workspaces.values.filter(function(w) { return w.id > 0 && w.toplevels.values.length > 0 }).map(function(w) { return w.id })
    return Math.min(10, Math.max.apply(null, [5, root.active].concat(ids)))
  }
  function busy(n) { var w = Hyprland.workspaces.values.find(function(x) { return x.id === n }); return !!w && w.toplevels.values.length > 0 }
  function go(ws) { Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = '" + ws + "' }))"]) }
  implicitWidth: across
  implicitHeight: card.height + 8
  RumdaCard {
    id: card
    bar: root.bar
    anchors.centerIn: parent
    width: root.across - 14; height: col.implicitHeight + 18
    Column {
      id: col
      anchors.centerIn: parent
      spacing: 3
      Repeater {
        model: root.count
        Shape {
          id: st
          required property int index
          readonly property int n: index + 1
          readonly property bool on: n === root.active
          width: 14; height: 14
          preferredRendererType: Shape.CurveRenderer
          opacity: on ? 1 : root.busy(n) ? 0.55 : 0.22
          Behavior on opacity { NumberAnimation { duration: 160 } }
          ShapePath {
            fillColor: Commons.Color.accent; strokeWidth: -1
            PathMove { x: 9; y: 0 } PathLine { x: 14; y: 0 } PathLine { x: 5; y: 14 } PathLine { x: 0; y: 14 } PathLine { x: 9; y: 0 }
          }
          function triggerPress(button) { root.go(st.n) }
          property BarClick click: BarClick { bar: root.bar; target: st }
        }
      }
    }
  }
  WheelHandler { onWheel: function(e) { root.go(e.angleDelta.y > 0 ? "e-1" : "e+1") } }
}
