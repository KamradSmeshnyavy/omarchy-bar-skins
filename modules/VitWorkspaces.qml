import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons as Commons

// Столы Vitreus (по мотивам natepayn3/Vitreus, MIT; код свой) — модуль бара kamradsmeshnyavy.bar. k — масштаб от полосы
// Vitreus (62 px) к толщине бара.
// Метки — только занятые столы и текущий (как ws_all = false у Vitreus): точка, у текущего — капсула с градиентом акцента
// (светлый → акцент → тёмный). Капсула «живая»: при переходе её голова летит быстро (128 мс), хвост догоняет (340 мс) —
// она растягивается и сжимается. Стол, где окно просит внимания, — тёплая точка. После меток — «+»: первый пустой стол.
// Клик — перейти, колесо — соседний.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property int across: bar && bar.barSize ? bar.barSize : 32
  readonly property real k: Math.max(0.55, across / 62)
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : Commons.Color.foreground
  readonly property color acc: Commons.Color.accent
  readonly property color accHi: Qt.lighter(acc, 1.38)
  readonly property color accLo: Qt.darker(acc, 1.3)
  readonly property color warm: "#ff7a59"

  readonly property real dot: 8 * k          // метка-точка
  readonly property real cap: 28 * k         // капсула текущего
  readonly property real thick: 9 * k
  readonly property real gap: 9 * k

  readonly property int active: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
  // занятые (обычные, 1…10) и текущий — по порядку
  readonly property var marks: {
    var ids = Hyprland.workspaces.values.filter(function(w) { return w.id > 0 && w.id <= 10 && w.toplevels.values.length > 0 }).map(function(w) { return w.id })
    if (active > 0 && ids.indexOf(active) === -1) ids.push(active)
    ids.sort(function(a, b) { return a - b })
    return ids
  }
  readonly property int fresh: { for (var i = 1; i <= 10; i++) if (marks.indexOf(i) === -1) return i; return 0 }
  function urgentOf(id) {
    var w = Hyprland.workspaces.values.find(function(x) { return x.id === id })
    return !!w && w.urgent === true
  }
  function go(ws) { Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = '" + ws + "' }))"]) }

  // где начинается слот i вдоль бара (по итоговой раскладке — капсула летит к ней)
  function startOf(i) {
    var p = 0
    for (var j = 0; j < i; j++) p += (marks[j] === active ? cap : dot) + gap
    return p
  }
  readonly property int ai: marks.indexOf(active)
  readonly property real total: startOf(marks.length) + (fresh ? dot + 4 * k : 0)
  readonly property real pad: 10 * k

  implicitWidth: vertical ? across : total + 2 * pad
  implicitHeight: vertical ? total + 2 * pad : across

  // капсула: голова и хвост вдоль бара, у каждого своя скорость
  property real target: ai >= 0 ? startOf(ai) : 0
  property bool forward: true
  // сначала направление, потом новая цель: длительности голове и хвосту выбираются до начала анимации
  property real goal: 0
  onTargetChanged: { forward = target >= goal; goal = target }
  Component.onCompleted: goal = target
  property real lo: goal
  property real hi: goal + cap
  Behavior on lo { NumberAnimation { duration: root.forward ? 340 : 128; easing.type: Easing.OutCubic } }
  Behavior on hi { NumberAnimation { duration: root.forward ? 128 : 340; easing.type: Easing.OutCubic } }

  Item {
    id: track
    x: root.vertical ? (root.width - root.thick) / 2 : root.pad
    y: root.vertical ? root.pad : (root.height - root.thick) / 2
    width: root.vertical ? root.thick : root.total
    height: root.vertical ? root.total : root.thick

    Repeater {
      model: root.marks
      Item {
        id: slot
        required property int index
        required property var modelData
        readonly property int n: modelData
        readonly property bool on: n === root.active
        readonly property bool urg: !on && root.urgentOf(n)
        property real len: on ? root.cap : root.dot
        Behavior on len { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        property real pos: root.startOf(index)
        Behavior on pos { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        x: root.vertical ? 0 : pos
        y: root.vertical ? pos : 0
        width: root.vertical ? root.thick : len
        height: root.vertical ? len : root.thick
        // точка занятого стола (под капсулой её не видно)
        Rectangle {
          anchors.centerIn: parent
          width: root.dot * (hov.hovered ? 1.25 : 1); height: width; radius: width / 2
          color: slot.urg ? root.warm : root.fg
          opacity: slot.on ? 0 : slot.urg ? 0.95 : hov.hovered ? 0.85 : 0.5
          Behavior on width { NumberAnimation { duration: 120 } }
          Behavior on opacity { NumberAnimation { duration: 160 } }
        }
        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.go(slot.n) }
      }
    }
    // капсула текущего: тянется от хвоста к голове
    Rectangle {
      visible: root.ai >= 0
      x: root.vertical ? 0 : root.lo
      y: root.vertical ? root.lo : 0
      width: root.vertical ? root.thick : Math.max(root.thick, root.hi - root.lo)
      height: root.vertical ? Math.max(root.thick, root.hi - root.lo) : root.thick
      radius: root.thick / 2
      gradient: Gradient {
        orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
        GradientStop { position: 0; color: root.accHi }
        GradientStop { position: 0.5; color: root.acc }
        GradientStop { position: 1; color: root.accLo }
      }
      // блик сверху
      Rectangle {
        x: root.vertical ? 1.5 * root.k : parent.radius
        y: root.vertical ? parent.radius : 1.5 * root.k
        width: root.vertical ? 1.6 * root.k : Math.max(0, parent.width - 2 * parent.radius)
        height: root.vertical ? Math.max(0, parent.height - 2 * parent.radius) : 1.6 * root.k
        radius: 1
        color: Qt.rgba(1, 1, 1, 0.45)
      }
    }
    // «+»: первый пустой стол
    Item {
      visible: root.fresh > 0
      readonly property real p: root.startOf(root.marks.length) + 4 * root.k
      x: root.vertical ? 0 : p
      y: root.vertical ? p : 0
      width: root.vertical ? root.thick : root.dot
      height: root.vertical ? root.dot : root.thick
      Rectangle { anchors.centerIn: parent; width: root.dot; height: 1.6 * root.k; radius: 1; color: root.fg; opacity: plusHov.hovered ? 0.9 : 0.45 }
      Rectangle { anchors.centerIn: parent; width: 1.6 * root.k; height: root.dot; radius: 1; color: root.fg; opacity: plusHov.hovered ? 0.9 : 0.45 }
      HoverHandler { id: plusHov; cursorShape: Qt.PointingHandCursor; margin: 6 }
      TapHandler { margin: 6; onTapped: root.go(root.fresh) }
    }
  }
  WheelHandler { onWheel: function(e) { root.go(e.angleDelta.y > 0 ? "e-1" : "e+1") } }
}
