import QtQuick
import Quickshell
import Quickshell.Io
import "glyphrice"

// Из glyph-rice (bar/Bar.qml, GPL-3.0) — модуль бара kamradsmeshnyavy.bar. k — масштаб от пилюли glyph-rice (64 px) к толщине бара.
// Знак: кольцо из 16 точек — лаунчер (клик — меню Omarchy), центр краснеет, пока идёт запись экрана или кто-то слушает микрофон.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property int across: bar && bar.barSize ? bar.barSize : 32
  readonly property real k: Math.max(0.5, across / 64)
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : GTheme.fg

  property bool live: false
  Process {
    id: probe
    command: ["sh", "-c", "pgrep -f '^gpu-screen-recorder' >/dev/null && echo rec; pactl list short source-outputs 2>/dev/null | head -1"]
    stdout: StdioCollector { onStreamFinished: root.live = String(text || "").trim() !== "" }
  }
  Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!probe.running) probe.running = true }

  implicitWidth: vertical ? across : 34 * k + 8
  implicitHeight: vertical ? 34 * k + 8 : across
  Item {
    anchors.centerIn: parent
    width: 34 * root.k
    height: width
    Ring { anchors.fill: parent; n: 16; dot: Math.max(2, 3 * root.k); on: root.fg }
    Rectangle {
      anchors.centerIn: parent
      width: 9 * root.k
      height: width
      radius: width / 2
      color: root.live ? GTheme.accent : root.fg
      Behavior on color { ColorAnimation { duration: GTheme.t } }
    }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["omarchy-menu", "toggle"])
  }
}
