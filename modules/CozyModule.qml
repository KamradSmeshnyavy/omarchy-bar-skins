import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Модули бара Cozytile (по мотивам qtile-бара Cozytile, Darkkal44 — только облик, код свой) — kamradsmeshnyavy.bar.
// Бар — светлая заливка; на ней тёмные «язычки» с S-образными косыми боками и тонкие косые черты между значками.
// settings.kind:
//   launcher — значок из четырёх ромбов (клик — меню выключения);
//   groups   — точки столов 1–8 (settings.count): занятые — акцентом, текущий — своим цветом, пустые — тёмные; клик — стол;
//   layout   — значок колонок и раскладка стола (dwindle / master / scrolling…); клик — следующая раскладка стола;
//   search   — лупа и «Search» (клик — список приложений, omarchy-apps);
//   title    — заголовок активного окна, на пустом столе — «Desktop»;
//   memory   — занято памяти «2186M» (клик — btop); battery — «Full» / «85%»; volume — «50%» (колесо, клик — без звука);
//   clock    — часы «01:15 PM» (settings.hour12 false — 24 ч; клик — дашборд).
// settings.tab: start (тёмный язычок у левого конца бара) · end (у правого) · mid (с косыми боками) · "" (без язычка);
// settings.slash: true — косая черта справа. settings.command — своя команда клика.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 30
  readonly property string kind: String(settings && settings.kind || "title")
  readonly property string tab: String(settings && settings.tab || "")
  readonly property bool slash: !!(settings && settings.slash)
  readonly property CozyPal pal: CozyPal {}
  readonly property int curve: 16                 // ширина косого бока язычка
  readonly property int padL: tab === "start" ? 16 : tab ? curve + 6 : 8
  readonly property int padR: tab === "end" ? 18 : tab ? curve + 6 : 8
  readonly property int slashW: slash ? 22 : 0

  implicitWidth: content.implicitWidth + padL + padR + slashW
  implicitHeight: across

  // ── язычок: S-образные косые бока «/», у конца бара — скруглённые углы ──
  readonly property string tabPath: {
    var w = root.width - root.slashW, h = root.height, c = root.curve, r = 8
    var rs = " C " + (w - c / 2) + " 0 " + (w - c / 2) + " " + h + " " + (w - c) + " " + h      // правый бок сверху вниз
    var ls = " C " + (c / 2) + " " + h + " " + (c / 2) + " 0 " + c + " 0"                     // левый бок снизу вверх
    if (root.tab === "start")
      return "M " + r + " 0 L " + w + " 0" + rs + " L " + r + " " + h + " A " + r + " " + r + " 0 0 1 0 " + (h - r) +
        " L 0 " + r + " A " + r + " " + r + " 0 0 1 " + r + " 0 Z"
    if (root.tab === "end")
      return "M " + c + " 0 L " + (w - r) + " 0 A " + r + " " + r + " 0 0 1 " + w + " " + r + " L " + w + " " + (h - r) +
        " A " + r + " " + r + " 0 0 1 " + (w - r) + " " + h + " L 0 " + h + ls + " Z"
    return "M " + c + " 0 L " + w + " 0" + rs + " L 0 " + h + ls + " Z"
  }
  Shape {
    visible: root.tab !== ""
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: root.pal.tab
      strokeWidth: -1
      PathSvg { path: root.tabPath }
    }
  }
  // косая черта справа
  Rectangle {
    visible: root.slash
    x: root.width - root.slashW / 2 - 1
    y: 3
    width: 2; height: root.height - 6
    radius: 1
    rotation: 22
    color: root.pal.slash
  }

  Item {
    id: content
    x: root.padL
    width: implicitWidth
    height: root.height
    implicitWidth: kindRow.implicitWidth

    Row {
      id: kindRow
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8

      // лаунчер: четыре ромба
      Item {
        visible: root.kind === "launcher"
        width: 18; height: 18
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
          model: [[9, 3], [3, 9], [15, 9], [9, 15]]
          Rectangle {
            required property var modelData
            x: modelData[0] - 3.2; y: modelData[1] - 3.2
            width: 6.4; height: 6.4
            rotation: 45
            color: "transparent"
            border.width: 1.4
            border.color: root.pal.ink
          }
        }
      }

      // точки столов
      Row {
        visible: root.kind === "groups"
        spacing: 9
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
          model: Number(root.settings && root.settings.count) || 8
          Rectangle {
            id: dot
            required property int index
            readonly property int wid: index + 1
            readonly property bool on: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wid
            readonly property bool busy: { var w = Hyprland.workspaces.values.find(function(x) { return x.id === dot.wid }); return !!w && w.toplevels.values.length > 0 }
            width: 13; height: 13; radius: 6.5
            anchors.verticalCenter: parent.verticalCenter
            color: on ? root.pal.cur : busy ? root.pal.ink : root.pal.empty
            scale: dh.hovered && !on ? 1.15 : 1
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on scale { NumberAnimation { duration: 140 } }
            HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
            function triggerPress(button) { Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = '" + dot.wid + "' }))"]) }
            property BarClick click: BarClick { bar: root.bar; target: dot }
          }
        }
      }

      // раскладка: значок колонок
      Item {
        visible: root.kind === "layout"
        width: 16; height: 14
        anchors.verticalCenter: parent.verticalCenter
        Rectangle { anchors.fill: parent; radius: 2; color: "transparent"; border.width: 1.6; border.color: root.pal.ink }
        Rectangle { x: 7; y: 1; width: 1.6; height: 12; color: root.pal.ink }
        Rectangle { x: 8; y: 6.2; width: 7; height: 1.6; color: root.pal.ink }
      }
      // лупа
      Item {
        visible: root.kind === "search"
        width: 15; height: 15
        anchors.verticalCenter: parent.verticalCenter
        Rectangle { x: 0; y: 0; width: 11; height: 11; radius: 5.5; color: "transparent"; border.width: 1.8; border.color: root.pal.ink }
        Rectangle { x: 9.5; y: 11; width: 6; height: 1.8; radius: 0.9; rotation: 45; color: root.pal.ink }
      }
      // значки статуса (Font Awesome в Nerd Font)
      Text {
        visible: ["memory", "battery", "volume", "clock"].indexOf(root.kind) !== -1
        anchors.verticalCenter: parent.verticalCenter
        text: root.kind === "memory" ? "" : root.kind === "battery" ? root.batIcon : root.kind === "volume" ? (root.muted ? "" : "") : ""
        color: root.pal.ink
        font.family: root.pal.font
        font.pixelSize: 14
      }
      Text {
        visible: root.kind !== "launcher" && root.kind !== "groups"
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        width: root.kind === "title" ? Math.min(implicitWidth, Number(root.settings && root.settings.width) || 700) : implicitWidth
        elide: Text.ElideRight
        color: root.pal.ink
        font.family: root.pal.font
        font.pixelSize: 13
        font.bold: true
      }
    }
  }

  // ── данные ──
  readonly property string layoutName: String(Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.lastIpcObject
    && Hyprland.focusedWorkspace.lastIpcObject.tiledLayout || "dwindle")
  readonly property bool emptyWs: !Hyprland.focusedWorkspace || Hyprland.focusedWorkspace.toplevels.values.length === 0
  readonly property string title: emptyWs || !Hyprland.activeToplevel ? "Desktop" : String(Hyprland.activeToplevel.title || "Desktop")

  property int memMb: 0
  Process {
    id: memRead
    command: ["sh", "-c", "awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print int((t-a)/1024)}' /proc/meminfo"]
    stdout: StdioCollector { onStreamFinished: root.memMb = parseInt(text) || 0 }
  }
  Timer { running: root.kind === "memory"; repeat: true; interval: 5000; triggeredOnStart: true; onTriggered: if (!memRead.running) memRead.running = true }

  readonly property var dev: UPower.displayDevice
  readonly property int cap: dev && dev.ready ? Math.round(dev.percentage * (dev.percentage <= 1 ? 100 : 1)) : 0
  readonly property bool full: !!dev && (dev.state === UPowerDeviceState.FullyCharged || cap >= 100)
  readonly property string batIcon: cap >= 90 ? "" : cap >= 65 ? "" : cap >= 40 ? "" : cap >= 15 ? "" : ""

  PwObjectTracker { objects: root.kind === "volume" ? [Pipewire.defaultAudioSink] : [] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)
  readonly property int vol: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0

  property date now: new Date()
  Timer { running: root.kind === "clock"; repeat: true; interval: 1000; triggeredOnStart: true; onTriggered: root.now = new Date() }

  readonly property string label: kind === "layout" ? layoutName
    : kind === "search" ? "Search"
    : kind === "title" ? title
    : kind === "memory" ? memMb + "M"
    : kind === "battery" ? (full ? "Full" : cap + "%")
    : kind === "volume" ? (muted ? "M" : vol + "%")
    : kind === "clock" ? Qt.formatDateTime(now, settings && settings.hour12 === false ? "HH:mm" : "hh:mm AP")
    : ""

  WheelHandler {
    enabled: root.kind === "volume" || root.kind === "groups"
    onWheel: function(e) {
      if (root.kind === "volume" && root.sink && root.sink.audio) root.sink.audio.volume = Math.max(0, Math.min(1.5, root.sink.audio.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05)))
      else if (root.kind === "groups") Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = '" + (e.angleDelta.y > 0 ? "e-1" : "e+1") + "' }))"])
    }
  }
  HoverHandler { cursorShape: root.kind === "title" ? Qt.ArrowCursor : Qt.PointingHandCursor }
  function triggerPress(button) {
    if (settings && settings.command) { Quickshell.execDetached(["bash", "-c", String(settings.command)]); return }
    if (kind === "launcher") Quickshell.execDetached(["omarchy-shell", "widgets", "togglePower"])
    else if (kind === "search") Quickshell.execDetached(["omarchy-apps"])
    else if (kind === "layout") Quickshell.execDetached(["omarchy-hyprland-workspace-layout-toggle"])
    else if (kind === "memory") Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"])
    else if (kind === "volume" && sink && sink.audio) sink.audio.muted = !sink.audio.muted
    else if (kind === "clock") Quickshell.execDetached(["omarchy-shell", "widgets", "toggleDashboard"])
  }
}
