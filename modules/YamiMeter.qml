import QtQuick
import Quickshell.Io
import qs.Commons as Commons

// Шкала yami (по мотивам Trendorin/yami, MIT; код свой) — модуль бара kamradsmeshnyavy.bar: «cpu ▮▮▮▮▮▮ 2%».
// settings.kind: cpu (загрузка) · ram (занятая память) · temp (температура процессора, °C из 100). Подпись тусклая,
// шесть ячеек — заполненные акцентом, пустые в полтона, значение справа; выше 85 % — ярче. Данные — /proc и
// /sys/class/thermal раз в 2 с.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: !!bar && bar.vertical === true
  readonly property int across: bar && bar.barSize ? bar.barSize : 30
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : Commons.Color.foreground
  readonly property color warn: Commons.Color.urgent
  readonly property color acc: Commons.Color.accent
  readonly property string font: bar && bar.fontFamily ? bar.fontFamily : "Tiny5"
  readonly property string kind: String(settings && settings.kind || "cpu")
  readonly property int px: Math.max(9, Math.round(across * 0.42))

  property real value: 0           // 0…1
  property real temp: 0
  property var prev: null
  readonly property int cells: 6
  readonly property bool hot: value > 0.85

  Process {
    id: probe
    command: ["bash", "-c",
      "read -r _ u n s i w q sq st _ < /proc/stat; echo cpu $((u+n+s+i+w+q+sq+st)) $((i+w));" +
      "awk '/^MemTotal|^MemAvailable/{printf \"%s \", $2} END{print \"\"}' /proc/meminfo | sed 's/^/mem /';" +
      "t=; for z in /sys/class/thermal/thermal_zone*; do case $(<$z/type) in x86_pkg_temp|TCPU|cpu*|k10temp) t=$(<$z/temp); break;; esac; done;" +
      "echo \"temp ${t:-$(</sys/class/thermal/thermal_zone0/temp)}\""]
    stdout: StdioCollector {
      onStreamFinished: {
        text.split("\n").forEach(function(l) {
          var f = l.trim().split(/\s+/)
          if (f[0] === "cpu" && root.kind === "cpu") {
            var tot = Number(f[1]), idle = Number(f[2])
            if (root.prev) { var dt = tot - root.prev.tot; root.value = dt > 0 ? Math.max(0, Math.min(1, 1 - (idle - root.prev.idle) / dt)) : root.value }
            root.prev = { tot: tot, idle: idle }
          } else if (f[0] === "mem" && root.kind === "ram" && Number(f[1]) > 0) {
            root.value = 1 - Number(f[2]) / Number(f[1])
          } else if (f[0] === "temp" && root.kind === "temp") {
            root.temp = Number(f[1]) / 1000
            root.value = Math.max(0, Math.min(1, root.temp / 100))
          }
        })
      }
    }
  }
  Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!probe.running) probe.running = true }

  implicitWidth: vertical ? across : row.implicitWidth + 8
  implicitHeight: vertical ? col.implicitHeight + 8 : across

  component Cells: Row {
    spacing: 1
    Repeater {
      model: root.cells
      Rectangle {
        required property int index
        readonly property bool full: index < Math.round(root.value * root.cells)
        width: Math.max(3, Math.round(root.px * 0.36)); height: Math.round(root.px * 0.95)
        color: full ? (root.hot ? Qt.lighter(root.acc, 1.35) : root.acc) : Qt.rgba(root.acc.r, root.acc.g, root.acc.b, 0.22)
      }
    }
  }
  readonly property string label: kind === "temp" ? "" : kind
  readonly property string valueText: kind === "temp" ? Math.round(temp) + "°" : Math.round(value * 100) + "%"

  Row {
    id: row
    visible: !root.vertical
    anchors.centerIn: parent
    spacing: 5
    Text { visible: root.label !== ""; anchors.verticalCenter: parent.verticalCenter; text: root.label; color: root.fg; opacity: 0.45; font.family: root.font; font.pixelSize: root.px }
    Text { visible: root.kind === "temp"; anchors.verticalCenter: parent.verticalCenter; text: "󰔏"; color: root.fg; opacity: 0.55; font.family: Commons.Style.font.family; font.pixelSize: root.px }
    Cells { visible: root.kind !== "temp"; anchors.verticalCenter: parent.verticalCenter }
    Text { anchors.verticalCenter: parent.verticalCenter; text: root.valueText; color: root.hot ? root.warn : root.fg; opacity: 0.7; font.family: root.font; font.pixelSize: root.px }
  }
  Column {
    id: col
    visible: root.vertical
    anchors.centerIn: parent
    spacing: 3
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.kind === "temp" ? "°C" : root.label; color: root.fg; opacity: 0.45; font.family: root.font; font.pixelSize: root.px - 1 }
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.valueText; color: root.hot ? root.warn : root.fg; opacity: 0.75; font.family: root.font; font.pixelSize: root.px }
  }
}
