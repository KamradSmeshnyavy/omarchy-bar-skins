import QtQuick
import Quickshell
import Quickshell.Hyprland
import "glyphrice"

// Из glyph-rice (bar/Bar.qml, GPL-3.0) — модуль бара kamradsmeshnyavy.bar. k — масштаб от пилюли glyph-rice (64 px) к толщине бара.
// Столы точками: текущий вытягивается в пилюлю, занятые серые, пустые — тусклые. Шесть, больше — если занят дальний.
// Клик — перейти, колесо — соседний.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property int across: bar && bar.barSize ? bar.barSize : 32
  readonly property real k: Math.max(0.5, across / 64)
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : GTheme.fg

  readonly property int active: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property int count: {
    var ids = Hyprland.workspaces.values.filter(function(w) { return w.toplevels.values.length > 0 }).map(function(w) { return w.id })
    return Math.min(10, Math.max.apply(null, [6, root.active].concat(ids)))
  }
  function go(ws) { Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = '" + ws + "' }))"]) }

  implicitWidth: vertical ? across : pile.implicitWidth + 8
  implicitHeight: vertical ? pile.implicitHeight + 8 : across
  Grid {
    id: pile
    anchors.centerIn: parent
    columns: root.vertical ? 1 : root.count
    spacing: 8 * root.k
    Repeater {
      model: root.count
      Rectangle {
        required property int index
        readonly property int n: index + 1
        readonly property bool occ: {
          var w = Hyprland.workspaces.values.find(function(x) { return x.id === n })
          return !!w && w.toplevels.values.length > 0
        }
        readonly property bool on: root.active === n
        property real len: (on ? 28 : 8) * root.k
        width: root.vertical ? 8 * root.k : len
        height: root.vertical ? len : 8 * root.k
        radius: 4 * root.k
        color: on ? root.fg : occ ? GTheme.grey : GTheme.s3
        Behavior on len { NumberAnimation { duration: GTheme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: GTheme.glide } }
        Behavior on color { ColorAnimation { duration: GTheme.t } }
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.go(parent.n) }
      }
    }
  }
  WheelHandler { onWheel: function(e) { root.go(e.angleDelta.y > 0 ? "e-1" : "e+1") } }
}
