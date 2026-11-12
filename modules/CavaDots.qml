import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris

// Cava точками: 8 столбиков по 5 точек, растут снизу (у вертикального бара — 5 × 8 слева направо).
// cava запускается только пока что-то играет; тишина — модуль скрыт.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property color ink: bar && bar.barForeground ? bar.barForeground : "#ffffff"
  readonly property bool playing: Mpris.players.values.some(function(p) { return p.isPlaying })
  readonly property int cols: 8
  readonly property int rows: 5
  readonly property int dot: 3
  property var levels: []

  visible: playing
  implicitWidth: !playing ? 0 : vertical ? rows * (dot + 2) : cols * (dot + 2)
  implicitHeight: !playing ? 0 : vertical ? cols * (dot + 2) : rows * (dot + 2)

  Process {
    id: cava
    running: root.playing
    command: ["bash", "-c", "exec cava -p <(printf '%s' \"$1\")", "omarchy-bar-cava",
      ["[general]", "bars = " + root.cols, "framerate = 24", "[input]", "method = pipewire", "source = auto",
       "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = " + root.rows,
       "bar_delimiter = 59", "frame_delimiter = 10", ""].join("\n")]
    onRunningChanged: if (!running) root.levels = []
    stdout: SplitParser {
      onRead: data => root.levels = data.split(";").filter(function(x) { return x !== "" }).map(Number)
    }
  }

  Grid {
    anchors.centerIn: parent
    columns: root.vertical ? root.rows : root.cols
    spacing: 2
    Repeater {
      model: root.cols * root.rows
      Rectangle {
        required property int index
        // Горизонтально: столбец = index % cols, высота снизу; вертикально: строка = столбец cava, рост вправо.
        readonly property int bar_: root.vertical ? Math.floor(index / root.rows) : index % root.cols
        readonly property int step: root.vertical ? index % root.rows : root.rows - 1 - Math.floor(index / root.cols)
        width: root.dot; height: root.dot; radius: root.dot / 2
        color: (root.levels[bar_] || 0) > step ? root.ink : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.15)
      }
    }
  }
}
