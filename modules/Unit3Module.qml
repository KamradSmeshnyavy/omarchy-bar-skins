import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons as Commons

// Модули бара Unit-3 (по мотивам Unit-3, samyns — MIT; его waybar: config.jsonc и style.css) — kamradsmeshnyavy.bar.
// Тонкая полоса во всю ширину, Share Tech Mono 11 px, всё строчными подписями в духе NieR, модули справа разделены
// тонкой чертой (текст 8 %). settings.kind:
//   workspaces — номера столов: текущий — цветом текста с чертой 2 px снизу, остальные — 30 %, наведённый — 70 % с
//                лёгкой подложкой; клик — стол, колесо — соседний;
//   title      — «// заголовок окна» (40 знаков, 40 %);
//   ticker     — бегущая строка «接続中 // SCANNING // データ処理 // …» мелко и бледно (settings.text — своя);
//   pomodoro   — «POMO 25:00»: клик — старт / пауза, правый — сброс, в конце — уведомление;
//   cpu / mem / net / vol — «CPU 12%» (красный), «MEM 40%» (синий), «NET имя сети» (зелёный), «VOL 50%» (золото);
//              клик: cpu / mem — btop, net — Wi-Fi в Super+M, vol — звук (колесо — громкость, правый — без звука);
//   clock      — «HH:MM» (клик — дата «YYYY/MM/DD» и обратно);
//   power      — «⏻» бледно-красным (клик — меню выключения; у него — выход из Hyprland).
// Цвета подписей — его (#c87060 / #6090c8 / #60a880 / #c8a860); на светлой теме они темнее.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 28
  readonly property string kind: String(settings && settings.kind || "clock")
  readonly property color fg: Commons.Color.foreground
  readonly property bool dark: 0.299 * Commons.Color.background.r + 0.587 * Commons.Color.background.g + 0.114 * Commons.Color.background.b < 0.5
  function tone(hex) { return dark ? Qt.color(hex) : Qt.darker(Qt.color(hex), 1.9) }
  function fa(a) { return Qt.rgba(fg.r, fg.g, fg.b, a) }
  readonly property string font: Qt.fontFamilies().indexOf("Share Tech Mono") !== -1 ? "Share Tech Mono" : "monospace"
  readonly property bool sep: ["pomodoro", "cpu", "mem", "net", "vol", "clock", "power"].indexOf(kind) !== -1

  implicitWidth: content.implicitWidth + (sep ? 1 : 0)
  implicitHeight: across

  function run(a) { Quickshell.execDetached(a) }

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

  property string essid: ""
  property bool wired: false
  Process {
    id: netProbe
    command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null | awk -F: '$2==\"connected\"{print $1\":\"$3; exit}'"]
    stdout: StdioCollector {
      onStreamFinished: {
        var s = text.trim(), i = s.indexOf(":")
        root.wired = s.indexOf("ethernet") === 0
        root.essid = i >= 0 ? s.slice(i + 1) : ""
      }
    }
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

  property date now: new Date()
  property bool altDate: false
  Timer { interval: 1000; repeat: true; running: root.kind === "clock" || root.kind === "pomodoro"; triggeredOnStart: true; onTriggered: root.now = new Date() }

  // помодоро: 25 минут, как его pomodoro_toggle.sh
  property bool pomoRun: false
  property double pomoEnd: 0
  property int pomoLeft: 0
  readonly property int pomoRemain: pomoRun ? Math.max(0, Math.round((pomoEnd - now.getTime()) / 1000)) : pomoLeft
  onPomoRemainChanged: if (pomoRun && pomoRemain === 0) { pomoRun = false; pomoLeft = 0; run(["notify-send", "POMO", "25:00 — " + "YoRHa: break time"]) }
  function mmss(x) { return ("0" + Math.floor(x / 60)).slice(-2) + ":" + ("0" + (x % 60)).slice(-2) }

  readonly property string title: {
    var t = Hyprland.activeToplevel ? String(Hyprland.activeToplevel.title || "") : ""
    return t.length > 40 ? t.slice(0, 39) + "…" : t
  }

  // черта слева у модулей справа (border-left 1px текст 8 %)
  Rectangle { visible: root.sep; width: 1; height: parent.height; color: root.fa(0.08) }

  Item {
    id: content
    x: root.sep ? 1 : 0
    height: parent.height
    implicitWidth: root.kind === "workspaces" ? wsRow.implicitWidth
      : root.kind === "title" ? (root.title !== "" ? titleT.implicitWidth + 24 : 0)
      : root.kind === "ticker" ? tickT.implicitWidth
      : label.implicitWidth + (root.kind === "power" ? 28 : 20)

    // столы
    Row {
      id: wsRow
      visible: root.kind === "workspaces"
      height: parent.height
      Repeater {
        model: root.kind === "workspaces" ? Hyprland.workspaces.values.filter(function(w) { return w.id > 0 }).sort(function(a, b) { return a.id - b.id }) : []
        Item {
          id: ws
          required property var modelData
          readonly property bool on: !!Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
          width: wsT.implicitWidth + 16
          height: wsRow.height
          Rectangle { anchors.fill: parent; color: wsHov.hovered && !ws.on ? root.fa(0.05) : "transparent" }
          Text {
            id: wsT
            anchors.centerIn: parent
            text: ws.modelData.id
            color: ws.on ? root.fg : root.fa(wsHov.hovered ? 0.7 : 0.3)
            font.family: root.font; font.pixelSize: 11
            Behavior on color { ColorAnimation { duration: 150 } }
          }
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: ws.on ? root.fg : "transparent"; Behavior on color { ColorAnimation { duration: 150 } } }
          HoverHandler { id: wsHov; cursorShape: Qt.PointingHandCursor }
          function triggerPress(button) { root.run(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = '" + ws.modelData.id + "' }))"]) }
          property BarClick click: BarClick { bar: root.bar; target: ws }
        }
      }
      WheelHandler {
        onWheel: function(e) { root.run(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = '" + (e.angleDelta.y > 0 ? "e-1" : "e+1") + "' }))"]) }
      }
    }

    Text {
      id: titleT
      visible: root.kind === "title" && root.title !== ""
      x: 12; anchors.verticalCenter: parent.verticalCenter
      text: "// " + root.title
      color: root.fa(0.4)
      font.family: root.font; font.pixelSize: 11; font.letterSpacing: 1
    }

    Text {
      id: tickT
      visible: root.kind === "ticker"
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.settings && root.settings.text || "接続中 // SCANNING // データ処理 // SYS:ACTIVE // NR-2B@ARCH // 全システム正常 // 起動完了 //")
      color: root.fa(0.2)
      font.family: root.font; font.pixelSize: 9; font.letterSpacing: 2
    }

    // подписи справа
    Item {
      id: cell
      visible: ["workspaces", "title", "ticker"].indexOf(root.kind) === -1
      anchors.fill: parent
      Rectangle { anchors.fill: parent; color: root.kind === "power" && cellHov.hovered ? Qt.rgba(200 / 255, 96 / 255, 96 / 255, 0.08) : "transparent" }
      Text {
        id: label
        anchors.centerIn: parent
        font.family: root.font
        font.pixelSize: 11
        font.letterSpacing: root.kind === "clock" || root.kind === "pomodoro" ? 2 : 1
        text: root.kind === "cpu" ? "CPU " + Math.round(root.cpu * 100) + "%"
          : root.kind === "mem" ? "MEM " + Math.round(root.mem * 100) + "%"
          : root.kind === "net" ? (root.essid === "" ? "NET --" : (root.wired ? "ETH " : "NET ") + root.essid)
          : root.kind === "vol" ? (root.muted ? "VOL --" : "VOL " + root.volume + "%")
          : root.kind === "clock" ? (root.altDate ? Qt.formatDate(root.now, "yyyy/MM/dd") : Qt.formatTime(root.now, "HH:mm"))
          : root.kind === "pomodoro" ? "POMO " + (root.pomoRun || root.pomoLeft > 0 ? root.mmss(root.pomoRemain) : "--:--")
          : "⏻"
        color: root.kind === "cpu" ? root.tone("#c87060")
          : root.kind === "mem" ? root.tone("#6090c8")
          : root.kind === "net" ? root.tone("#60a880")
          : root.kind === "vol" ? root.tone("#c8a860")
          : root.kind === "clock" ? root.fg
          : root.kind === "pomodoro" ? root.fa(0.6)
          : cellHov.hovered ? root.tone("#c87060") : Qt.rgba(200 / 255, 96 / 255, 96 / 255, 0.5)
      }
      HoverHandler { id: cellHov; cursorShape: Qt.PointingHandCursor }
      WheelHandler {
        enabled: root.kind === "vol"
        onWheel: function(e) { root.run(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", e.angleDelta.y > 0 ? "5%+" : "5%-"]); volProbe.running = true }
      }
      function triggerPress(button) {
        var right = button === Qt.RightButton
        if (root.kind === "cpu" || root.kind === "mem") root.run(["omarchy-launch-or-focus-tui", "btop"])
        else if (root.kind === "net") root.run(["omarchy-shell", "widgets", "openSettingsSection", "wifi"])
        else if (root.kind === "vol") {
          if (right) { root.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]); volProbe.running = true }
          else root.run(["omarchy-shell", "widgets", "openSettingsSection", "audio"])
        }
        else if (root.kind === "clock") root.altDate = !root.altDate
        else if (root.kind === "pomodoro") {
          if (right) { root.pomoRun = false; root.pomoLeft = 0 }
          else if (root.pomoRun) { root.pomoLeft = root.pomoRemain; root.pomoRun = false }
          else { root.pomoEnd = Date.now() + 1000 * (root.pomoLeft > 0 ? root.pomoLeft : 1500); root.pomoRun = true }
        }
        else if (root.kind === "power") root.run(["omarchy-shell", "widgets", "togglePower"])
      }
      property BarClick click: BarClick { bar: root.bar; target: cell }
    }
  }
}
