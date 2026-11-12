import QtQuick
import QtQuick.Shapes
import Quickshell.Io

// Радиальные CPU и RAM (по мотивам rumda): два кольца-дуги с числом внутри; у вертикального бара — столбиком.
// /proc/stat и /proc/meminfo раз в 2 с. Выше 90 % — цвет тревоги темы.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property bool tooltipHovered: hover.hovered
  readonly property color ink: bar && bar.barForeground ? bar.barForeground : "#ffffff"
  readonly property color urgent: bar && bar.urgent ? bar.urgent : "#e06c75"
  property real cpu: 0
  property real mem: 0
  property var prev: null
  readonly property int size: 22

  // Толщина слота — как у бара, кольца по центру.
  readonly property int across: bar && bar.barSize ? bar.barSize : size + 4
  implicitWidth: vertical ? across : size * 2 + 10
  implicitHeight: vertical ? size * 2 + 10 : across

  onTooltipHoveredChanged: {
    if (!bar) return
    if (tooltipHovered) bar.showTooltip(root, "CPU " + Math.round(cpu * 100) + "% · RAM " + Math.round(mem * 100) + "%")
    else bar.hideTooltip(root)
  }
  HoverHandler { id: hover }

  Process {
    id: probe
    command: ["bash", "-c", "read -r _ u n s i w q sq st _ < /proc/stat; echo cpu $((u+n+s+i+w+q+sq+st)) $((i+w));" +
      "awk '/^MemTotal|^MemAvailable/{printf \"%s \", $2} END{print \"\"}' /proc/meminfo | sed 's/^/mem /'"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var f = lines[i].trim().split(/\s+/)
          if (f[0] === "cpu") {
            var total = Number(f[1]), idle = Number(f[2])
            if (root.prev && total > root.prev.total)
              root.cpu = Math.max(0, Math.min(1, 1 - (idle - root.prev.idle) / (total - root.prev.total)))
            root.prev = { total: total, idle: idle }
          } else if (f[0] === "mem" && Number(f[1]) > 0) {
            root.mem = 1 - Number(f[2]) / Number(f[1])
          }
        }
      }
    }
  }
  Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!probe.running) probe.running = true }

  Grid {
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 2
    spacing: 6
    Repeater {
      model: [{ v: root.cpu, l: "C" }, { v: root.mem, l: "M" }]
      Item {
        id: ring
        required property var modelData
        width: root.size; height: root.size
        readonly property color c: modelData.v > 0.9 ? root.urgent : root.ink
        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeColor: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
            strokeWidth: 2.5
            fillColor: "transparent"
            PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.size / 2 - 2; radiusY: root.size / 2 - 2; startAngle: 0; sweepAngle: 360 }
          }
          ShapePath {
            strokeColor: ring.c
            strokeWidth: 2.5
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.size / 2 - 2; radiusY: root.size / 2 - 2; startAngle: -90; sweepAngle: 360 * Math.max(0.01, ring.modelData.v) }
          }
        }
        Text {
          anchors.centerIn: parent
          text: Math.round(ring.modelData.v * 100)
          font.pixelSize: 8
          font.bold: true
          color: ring.c
        }
      }
    }
  }
}
