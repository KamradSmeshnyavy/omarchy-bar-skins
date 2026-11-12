import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

// Таймер фокуса (помодоро; по мотивам glyph-rice): клик — старт / пауза, ПКМ — сброс, колесо — ±5 мин.
// Работа (25 мин) → перерыв (5 мин) → снова работа; конец отрезка — уведомление. Кольцо — сколько прошло.
// Состояние живёт в ~/.local/state/omarchy/focus-timer.json — переживает перезапуск оболочки.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property bool tooltipHovered: hover.hovered
  readonly property color ink: bar && bar.barForeground ? bar.barForeground : "#ffffff"
  readonly property color accent: bar && bar.urgent ? bar.urgent : "#e06c75"

  property int workMin: 25
  property int breakMin: 5
  property string phase: "work"          // work | break
  property bool running: false
  property double endsAt: 0              // мс, пока идёт
  property int leftSec: workMin * 60     // на паузе
  property double now: Date.now()

  readonly property int total: (phase === "work" ? workMin : breakMin) * 60
  readonly property int remain: running ? Math.max(0, Math.round((endsAt - now) / 1000)) : leftSec
  readonly property real done: total > 0 ? 1 - remain / total : 0
  function mmss(s) { var m = Math.floor(s / 60), x = s % 60; return m + ":" + (x < 10 ? "0" : "") + x }

  implicitWidth: vertical ? 30 : label.implicitWidth + 30
  implicitHeight: vertical ? 40 : 24

  FileView {
    id: store
    path: Quickshell.env("HOME") + "/.local/state/omarchy/focus-timer.json"
    printErrors: false
    onLoaded: {
      try {
        var d = JSON.parse(text())
        root.workMin = d.workMin || 25; root.breakMin = d.breakMin || 5
        root.phase = d.phase || "work"; root.running = d.running === true
        root.endsAt = d.endsAt || 0; root.leftSec = d.leftSec || root.workMin * 60
      } catch (e) {}
    }
  }
  function save() {
    store.setText(JSON.stringify({ workMin: workMin, breakMin: breakMin, phase: phase, running: running, endsAt: endsAt, leftSec: leftSec }) + "\n")
  }
  function toggle() {
    if (running) { leftSec = remain; running = false }
    else { endsAt = Date.now() + leftSec * 1000; running = true }
    save()
  }
  function reset() { running = false; phase = "work"; leftSec = workMin * 60; save() }
  function adjust(dir) {
    if (phase === "work") workMin = Math.max(5, Math.min(120, workMin + dir * 5))
    else breakMin = Math.max(1, Math.min(60, breakMin + dir))
    if (!running) leftSec = total
    save()
  }
  function finish() {
    var wasWork = phase === "work"
    phase = wasWork ? "break" : "work"
    leftSec = total
    endsAt = Date.now() + leftSec * 1000
    running = true
    save()
    Quickshell.execDetached(["omarchy", "notification", "send", "-t", "6000", "-g", wasWork ? "󰔟" : "󰂜", "--app-name", "Focus",
      wasWork ? "Перерыв " + breakMin + " мин" : "Снова фокус: " + workMin + " мин", wasWork ? "Отрезок фокуса закончен" : "Перерыв закончен"])
  }

  Timer {
    interval: 1000; repeat: true; running: root.running
    onTriggered: { root.now = Date.now(); if (root.remain <= 0) root.finish() }
  }

  onTooltipHoveredChanged: {
    if (!bar) return
    if (tooltipHovered) bar.showTooltip(root, (phase === "work" ? "Фокус" : "Перерыв") + " · " + mmss(remain) +
      "\nклик — старт/пауза · ПКМ — сброс · колесо — ±")
    else bar.hideTooltip(root)
  }
  HoverHandler { id: hover }
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: e => e.button === Qt.RightButton ? root.reset() : root.toggle()
    onWheel: w => root.adjust(w.angleDelta.y > 0 ? 1 : -1)
  }

  Item {
    id: ringBox
    width: 18; height: 18
    x: root.vertical ? (root.width - width) / 2 : 4
    y: root.vertical ? 2 : (root.height - height) / 2
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.2); strokeWidth: 2; fillColor: "transparent"
        PathAngleArc { centerX: 9; centerY: 9; radiusX: 7.5; radiusY: 7.5; startAngle: 0; sweepAngle: 360 }
      }
      ShapePath {
        strokeColor: root.phase === "work" ? root.accent : root.ink; strokeWidth: 2; capStyle: ShapePath.RoundCap; fillColor: "transparent"
        PathAngleArc { centerX: 9; centerY: 9; radiusX: 7.5; radiusY: 7.5; startAngle: -90; sweepAngle: 360 * Math.max(0.001, root.done) }
      }
    }
    Text {
      anchors.centerIn: parent
      text: root.running ? "" : "▶"
      font.pixelSize: 7
      color: root.ink
    }
  }
  Text {
    id: label
    x: root.vertical ? (root.width - width) / 2 : ringBox.x + ringBox.width + 5
    y: root.vertical ? ringBox.y + ringBox.height + 2 : (root.height - height) / 2
    text: root.vertical ? Math.ceil(root.remain / 60) + "" : root.mmss(root.remain)
    font.pixelSize: root.vertical ? 10 : 12
    font.family: "monospace"
    color: root.ink
    opacity: root.running ? 1 : 0.7
  }
}
