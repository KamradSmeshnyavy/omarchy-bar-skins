import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import qs.Commons as Commons

// Модули бара Retro CRT (по мотивам стиля Retro из elifouts/Dotfiles, GPL-3.0 — его quickshell/Retro/bar: Module.qml,
// Workspaces.qml, Bar.qml) — kamradsmeshnyavy.bar. Показания текстом вместо значков: подпись тускло («CPU»), значение
// цветом текста («02%»), Terminess капсом вразрядку; при наведении — подложка акцентом 18 %, горячее значение
// (CPU / MEM > 90 %, батарея < 15 %, нет сети) мигает. Текст при смене «печатается» с курсором █ (его Type.qml).
// settings.kind:
//   user       — «> USER@HOST», на узком экране — «> USER» (клик — дашборд, его «home»);
//   workspaces — номера столов в клетках: текущий — залит акцентом, видимый на другом мониторе — в рамке, «3·2» — окон
//                больше одного, пустые — тускло; клик — стол, колесо — соседний;
//   sep        — тонкая черта «│»;
//   cpu / mem  — «CPU 02%» / «MEM 13%» (клик — дашборд);
//   media      — «ТРЕК - АРТИСТ» (до 36 знаков, на узком экране — 24; клик — плеер Super+Alt+M, правый — пауза);
//   net        — «NET LINK» / «NET OFFLINE» (клик — Wi-Fi в Super+M);
//   vol        — «VOL 94%» / «MUTE» (колесо — громкость, клик — звук, правый — без звука);
//   battery    — «BAT 80%» / «CHG 80%» (есть батарея);
//   tray       — «TRAY 1» (клик — трей);
//   msg        — «MSG 5» / «DND 5» — уведомлений в истории (клик — история, правый — не беспокоить);
//   clock      — «SUN 15 NOV 26  9:27 PM» (клик — календарь);
//   power      — «⏻» (клик — меню выключения).
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 24
  readonly property string kind: String(settings && settings.kind || "clock")
  readonly property color fg: Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property color bg: Commons.Color.background
  readonly property color warn: Commons.Color.urgent
  function aa(a) { return Qt.rgba(accent.r, accent.g, accent.b, a) }
  function fa(a) { return Qt.rgba(fg.r, fg.g, fg.b, a) }
  readonly property color dim: fa(0.5)
  readonly property color low: aa(0.18)
  readonly property string font: Qt.fontFamilies().indexOf("Terminess Nerd Font Mono") !== -1 ? "Terminess Nerd Font Mono" : "monospace"
  readonly property int size: 14
  // узкий экран (< 1700 логических px, у него — fit() с запасными модулями): без хоста у user, трек короче
  readonly property bool narrow: Screen.width > 0 && Screen.width < 1700

  implicitWidth: kind === "workspaces" ? wsRow.implicitWidth + 4 : kind === "sep" ? 10 : (shown ? row.implicitWidth + 10 : 0)
  implicitHeight: across
  visible: kind === "workspaces" || kind === "sep" || shown

  function run(a) { Quickshell.execDetached(a) }
  function widgets(fn, arg) { run(arg === undefined ? ["omarchy-shell", "widgets", fn] : ["omarchy-shell", "widgets", fn, arg]) }
  function pad(n) { return String(Math.round(n)).padStart(2, "0") }

  // ── данные ──
  property real cpu: 0
  property real mem: 0
  property var prev: null
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
  Timer { interval: 3000; repeat: true; running: root.kind === "cpu" || root.kind === "mem"; triggeredOnStart: true; onTriggered: if (!probe.running) probe.running = true }

  property string net: "LINK"
  Process {
    id: netProbe
    command: ["sh", "-c", "nmcli -t -f STATE general 2>/dev/null"]
    stdout: StdioCollector { onStreamFinished: { var t = text.trim(); root.net = t.indexOf("connected") === 0 ? "LINK" : t === "" ? "LINK" : "OFFLINE" } }
  }
  Timer { interval: 10000; repeat: true; running: root.kind === "net"; triggeredOnStart: true; onTriggered: if (!netProbe.running) netProbe.running = true }

  property int volume: 0
  property bool muted: false
  Process {
    id: volProbe
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
    stdout: StdioCollector {
      onStreamFinished: {
        var m = text.match(/([\d.]+)/)
        root.volume = m ? Math.round(Number(m[1]) * 100) : 0
        root.muted = text.indexOf("MUTED") !== -1
      }
    }
  }
  Timer { interval: 1500; repeat: true; running: root.kind === "vol"; triggeredOnStart: true; onTriggered: if (!volProbe.running) volProbe.running = true }

  property int msgs: 0
  property bool dnd: false
  Process {
    id: msgProbe
    command: ["sh", "-c", "ls ~/.local/state/omarchy/notifications/history 2>/dev/null | wc -l; " +
      "jq -r '.dnd // .doNotDisturb // false' ~/.local/state/omarchy/notifications.json 2>/dev/null || echo false"]
    stdout: StdioCollector {
      onStreamFinished: {
        var l = text.trim().split("\n")
        root.msgs = Number(l[0]) || 0
        root.dnd = l[1] === "true"
      }
    }
  }
  Timer { interval: 5000; repeat: true; running: root.kind === "msg"; triggeredOnStart: true; onTriggered: if (!msgProbe.running) msgProbe.running = true }

  readonly property var player: {
    var all = Mpris.players.values
    for (var i = 0; i < all.length; i++) if (all[i].isPlaying) return all[i]
    return all.length ? all[0] : null
  }
  readonly property string song: {
    if (!player) return ""
    var s = [player.trackTitle, player.trackArtist].filter(function(x) { return !!x }).join(" - ")
    var max = narrow ? 24 : 36
    return s.length > max ? s.slice(0, max - 1) + "…" : s
  }
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: !!battery && battery.isLaptopBattery
  readonly property real charge: hasBattery ? battery.percentage : 1
  readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging

  property date now: new Date()
  Timer {
    interval: 1000; repeat: true; running: root.kind === "clock"; triggeredOnStart: true
    onTriggered: { var d = new Date(); if (d.getMinutes() !== root.now.getMinutes() || d.getHours() !== root.now.getHours()) root.now = d }
  }
  readonly property string host: hostFile.text().trim() || "sys"
  FileView { id: hostFile; path: root.kind === "user" ? "/etc/hostname" : ""; printErrors: false }

  // ── что показать: значок, подпись, значение, «горячее» ──
  readonly property string glyph: kind === "user" ? ">" : kind === "power" ? "⏻" : ""
  readonly property string label: kind === "cpu" ? "cpu" : kind === "mem" ? "mem" : kind === "net" ? "net"
    : kind === "vol" ? (muted ? "mute" : "vol") : kind === "battery" ? (charging ? "chg" : "bat")
    : kind === "tray" ? "tray" : kind === "msg" ? (dnd ? "dnd" : "msg") : ""
  readonly property string value: kind === "user" ? Quickshell.env("USER") + (narrow ? "" : "@" + host)
    : kind === "cpu" ? pad(cpu * 100) + "%" : kind === "mem" ? pad(mem * 100) + "%"
    : kind === "media" ? song : kind === "net" ? net
    : kind === "vol" ? pad(volume) + "%" : kind === "battery" ? Math.round(charge * 100) + "%"
    : kind === "tray" ? String(SystemTray.items.values.length) : kind === "msg" ? String(msgs)
    : kind === "clock" ? Qt.formatDate(now, "ddd dd MMM yy") + "  " + Qt.formatTime(now, "h:mm AP")
    : ""
  readonly property bool shown: kind === "media" ? song !== "" : kind === "battery" ? hasBattery
    : kind === "tray" ? SystemTray.items.values.length > 0 : true
  readonly property bool typed: kind === "user" || kind === "media" || kind === "net" || kind === "tray" || kind === "msg"
  readonly property bool hot: kind === "cpu" ? cpu > 0.9 : kind === "mem" ? mem > 0.9 : kind === "net" ? net === "OFFLINE"
    : kind === "battery" ? !charging && charge < 0.15 : false

  // мигание горячего значения (его Blink.qml: 530 мс)
  property bool blinkOn: true
  Timer { interval: 530; repeat: true; running: root.hot && root.visible; onRunningChanged: root.blinkOn = true; onTriggered: root.blinkOn = !root.blinkOn }

  // «печать» значения: его Type.qml — длительность min(320, 40 + 12·длина), курсор █ в конце
  property real n: 1e6
  NumberAnimation { id: tick; target: root; property: "n"; from: 0; onRunningChanged: if (!running) root.n = 1e6 }
  onValueChanged: if (typed && visible) { tick.to = value.length + 1; tick.duration = Math.min(320, 40 + value.length * 12); tick.restart() }
  readonly property string shownValue: n > value.length ? value : value.slice(0, Math.floor(n)) + "█"

  // ── вид ──
  Rectangle {
    visible: root.kind !== "workspaces" && root.kind !== "sep"
    anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: 3
    color: cellHov.hovered ? root.low : "transparent"
  }
  Text {
    visible: root.kind === "sep"
    anchors.centerIn: parent
    text: "│"
    color: root.low
    font.family: root.font; font.pixelSize: root.size
  }
  Row {
    id: row
    visible: root.kind !== "workspaces" && root.kind !== "sep"
    x: 5
    height: parent.height
    spacing: 6
    Text {
      visible: root.glyph !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph
      color: root.accent
      font.family: root.font; font.pixelSize: root.size
    }
    Text {
      visible: root.label !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      color: root.dim
      font { family: root.font; pixelSize: root.size; capitalization: Font.AllUppercase; letterSpacing: 1 }
    }
    Text {
      visible: root.value !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.shownValue
      color: root.hot ? (root.blinkOn ? root.warn : root.dim) : root.fg
      font { family: root.font; pixelSize: root.size; capitalization: Font.AllUppercase; letterSpacing: 1 }
    }
  }

  // столы
  Row {
    id: wsRow
    visible: root.kind === "workspaces"
    x: 2
    height: parent.height
    spacing: 2
    readonly property int focused: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property var onScreen: Hyprland.monitors.values.map(function(m) { return m.activeWorkspace ? m.activeWorkspace.id : -1 })
    // столы 1..5 всегда (как его HyprShared.workspaceIds), дальше — занятые
    readonly property var ids: {
      if (root.kind !== "workspaces") return []
      var s = {}
      for (var i = 1; i <= 5; i++) s[i] = true
      Hyprland.workspaces.values.forEach(function(w) { if (w.id > 0) s[w.id] = true })
      s[focused] = true
      return Object.keys(s).map(Number).sort(function(a, b) { return a - b })
    }
    function count(id) {
      var w = Hyprland.workspaces.values.find(function(x) { return x.id === id })
      return w && w.toplevels ? w.toplevels.values.length : 0
    }
    Repeater {
      model: wsRow.ids
      Item {
        id: cell
        required property int modelData
        readonly property bool lit: modelData === wsRow.focused
        readonly property bool seen: wsRow.onScreen.indexOf(modelData) !== -1
        readonly property int cnt: wsRow.count(modelData)
        width: wsT.implicitWidth + 10
        height: wsRow.height
        Rectangle {
          anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: 3
          color: cell.lit ? root.accent : wsHov.hovered ? root.low : "transparent"
          border.width: cell.seen && !cell.lit ? 1 : 0
          border.color: root.aa(0.55)
        }
        Text {
          id: wsT
          anchors.centerIn: parent
          text: cell.modelData + (cell.cnt > 1 ? "·" + cell.cnt : "")
          color: cell.lit ? root.bg : cell.cnt ? root.fg : root.dim
          font.family: root.font; font.pixelSize: root.size
        }
        HoverHandler { id: wsHov; cursorShape: Qt.PointingHandCursor }
        function triggerPress(button) { root.run(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = '" + cell.modelData + "' }))"]) }
        property BarClick click: BarClick { bar: root.bar; target: cell }
      }
    }
    WheelHandler {
      onWheel: function(e) { root.run(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = '" + (e.angleDelta.y > 0 ? "e-1" : "e+1") + "' }))"]) }
    }
  }

  Item {
    id: hit
    visible: root.kind !== "workspaces" && root.kind !== "sep"
    anchors.fill: parent
    HoverHandler { id: cellHov; cursorShape: Qt.PointingHandCursor }
    WheelHandler {
      enabled: root.kind === "vol"
      onWheel: function(e) { root.run(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", e.angleDelta.y > 0 ? "5%+" : "5%-"]); volProbe.running = true }
    }
    function triggerPress(button) {
      var right = button === Qt.RightButton
      if (root.kind === "user" || root.kind === "cpu" || root.kind === "mem") root.widgets("toggleDashboard")
      else if (root.kind === "media") { if (right && root.player) root.player.togglePlaying(); else root.widgets("togglePlayer") }
      else if (root.kind === "net") root.widgets("openSettingsSection", "wifi")
      else if (root.kind === "vol") {
        if (right) { root.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]); volProbe.running = true }
        else root.widgets("openSettingsSection", "audio")
      }
      else if (root.kind === "battery") root.widgets("openSettingsSection", "power")
      else if (root.kind === "tray") root.widgets("openSettingsSection", "tray")
      else if (root.kind === "msg") root.run(right ? ["omarchy-shell", "notifications", "toggleDnd"] : ["omarchy-shell", "notifications", "showHistory"])
      else if (root.kind === "clock") root.widgets("openSettingsSection", "calendar")
      else if (root.kind === "power") root.widgets("togglePower")
    }
    property BarClick click: BarClick { bar: root.bar; target: hit }
  }
}
