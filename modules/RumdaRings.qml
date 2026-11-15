import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import qs.Commons as Commons

// Кольца Rumda (по мотивам hexonide/rumda; код свой): карточка с двумя кольцами одно под другим — загрузка CPU и
// занятая память, дуга цветом акцента. Данные — /proc раз в 2 с.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 48
  property real cpu: 0
  property real mem: 0
  property var prev: null
  Process {
    id: probe
    command: ["bash", "-c", "read -r _ u n s i w q sq st _ < /proc/stat; echo cpu $((u+n+s+i+w+q+sq+st)) $((i+w)); awk '/^MemTotal|^MemAvailable/{printf \"%s \", $2} END{print \"\"}' /proc/meminfo | sed 's/^/mem /'"]
    stdout: StdioCollector {
      onStreamFinished: text.split("\n").forEach(function(l) {
        var f = l.trim().split(/\s+/)
        if (f[0] === "cpu") { var t = Number(f[1]), i = Number(f[2]); if (root.prev) { var d = t - root.prev.t; root.cpu = d > 0 ? 1 - (i - root.prev.i) / d : root.cpu } root.prev = { t: t, i: i } }
        else if (f[0] === "mem" && Number(f[1]) > 0) root.mem = 1 - Number(f[2]) / Number(f[1])
      })
    }
  }
  Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!probe.running) probe.running = true }
  implicitWidth: across
  implicitHeight: card.height + 8
  component Ring: Shape {
    id: ring
    property real value: 0
    width: 18; height: 18
    preferredRendererType: Shape.CurveRenderer
    ShapePath { strokeColor: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25); strokeWidth: 3; fillColor: "transparent"
      PathAngleArc { centerX: 9; centerY: 9; radiusX: 7; radiusY: 7; startAngle: 0; sweepAngle: 360 } }
    ShapePath { strokeColor: Commons.Color.accent; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.FlatCap
      PathAngleArc { centerX: 9; centerY: 9; radiusX: 7; radiusY: 7; startAngle: -90; sweepAngle: 360 * Math.max(0.02, Math.min(1, ring.value)) } }
  }
  RumdaCard {
    id: card
    bar: root.bar
    anchors.centerIn: parent
    width: root.across - 14; height: 58
    Column {
      anchors.centerIn: parent
      spacing: 6
      Ring { value: root.cpu }
      Ring { value: root.mem }
    }
  }
}
