import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs.Commons as Commons

// Модули бара Space (по мотивам стиля Space из elifouts/Dotfiles, GPL-3.0 — его quickshell/Space/bar: Module.qml,
// Workspaces.qml, Bar.qml) — kamradsmeshnyavy.bar. Коробки с уголками рисует скин space (islands + brackets), здесь —
// содержимое: значок акцентом 75 % (наведение — больше, открыто — акцент и черта 2 px снизу), подпись капсом
// вразрядку цветом текста 70 %, при появлении и смене текст «расшифровывается» (его DecodeText). settings.kind:
//   user     — значок и имя пользователя (клик — дашборд, его «home»);
//   stars    — столы звёздами: текущий — светящаяся звезда акцентом, видимый на другом мониторе — тусклее, стол с
//              окнами — точка крупнее, лишние окна кружат вокруг лунами (до 4); переход — комета по бару;
//              клик — стол, колесо — соседний;
//   media    — ноты (клик — плеер Super+Alt+M), при игре — название трека;
//   net      — Wi-Fi / провод / нет сети (клик — Wi-Fi в Super+M);
//   audio    — динамик и шкала из 12 клеток (колесо — громкость, клик — звук в Super+M, правый — без звука);
//   battery  — заряд (есть батарея), мигает ниже 15 %;
//   notifs   — колокол (клик — история уведомлений);
//   clock    — часы «hh:mm AP» как у него (клик — 24 ч и обратно);
//   power    — ⏻ (клик — меню выключения).
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 28
  readonly property string kind: String(settings && settings.kind || "clock")
  readonly property color fg: Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property color warn: Commons.Color.urgent
  function fa(a) { return Qt.rgba(fg.r, fg.g, fg.b, a) }
  function aa(a) { return Qt.rgba(accent.r, accent.g, accent.b, a) }
  readonly property string font: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"

  implicitWidth: kind === "stars" ? stars.width + 4 : row.implicitWidth + room + 10
  implicitHeight: across
  property real room: kind === "audio" ? 66 : 0

  function run(a) { Quickshell.execDetached(a) }
  function widgets(fn, arg) { run(arg === undefined ? ["omarchy-shell", "widgets", fn] : ["omarchy-shell", "widgets", fn, arg]) }

  // ── данные ──
  readonly property var player: {
    var all = Mpris.players.values
    for (var i = 0; i < all.length; i++) if (all[i].isPlaying) return all[i]
    return all.length ? all[0] : null
  }
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
  Timer { interval: 1500; repeat: true; running: root.kind === "audio"; triggeredOnStart: true; onTriggered: if (!volProbe.running) volProbe.running = true }
  property string net: "WLAN"
  Process {
    id: netProbe
    command: ["sh", "-c", "nmcli -t -f TYPE,STATE device 2>/dev/null | awk -F: '$2==\"connected\"{print $1; exit}'"]
    stdout: StdioCollector { onStreamFinished: { var t = text.trim(); root.net = t === "" ? "OFFLINE" : t.indexOf("ethernet") === 0 ? "ETH" : "WLAN" } }
  }
  Timer { interval: 10000; repeat: true; running: root.kind === "net"; triggeredOnStart: true; onTriggered: if (!netProbe.running) netProbe.running = true }
  property date now: new Date()
  property bool h24: false
  Timer { interval: 1000; repeat: true; running: root.kind === "clock"; triggeredOnStart: true; onTriggered: root.now = new Date() }
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: !!battery && battery.isLaptopBattery
  readonly property real charge: hasBattery ? battery.percentage : 1
  readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging

  readonly property string glyph: kind === "user" ? "󰀄"
    : kind === "media" ? "󰝚"
    : kind === "net" ? (net === "OFFLINE" ? "󰤭" : net === "WLAN" ? "󰤨" : "󰈀")
    : kind === "audio" ? (muted ? "󰝟" : "󰕾")
    : kind === "battery" ? (charging ? "󰂄" : "󰁹")
    : kind === "notifs" ? "󰂚"
    : kind === "power" ? "󰐥"
    : kind === "clock" ? "󰥔" : ""
  readonly property string label: kind === "user" ? String(Quickshell.env("USER") || "")
    : kind === "media" ? (player && player.isPlaying ? String(player.trackTitle || "").slice(0, 28) : "")
    : kind === "battery" ? String(Math.round(charge * 100))
    : kind === "clock" ? (h24 ? Qt.formatTime(now, "HH:mm") : Qt.formatTime(now, "hh:mm AP"))
    : ""
  readonly property bool hot: (kind === "net" && net === "OFFLINE") || (kind === "battery" && hasBattery && !charging && charge < 0.15)
  visible: kind !== "battery" || hasBattery

  // ── значок + подпись (его Module.qml) ──
  Row {
    id: row
    visible: root.kind !== "stars"
    x: 5
    height: parent.height
    spacing: 6
    Text {
      id: g
      visible: root.glyph !== ""
      text: root.glyph
      font.family: root.font
      font.pixelSize: 13
      color: root.hot ? root.warn : hov.hovered ? root.accent : root.aa(0.75)
      anchors.verticalCenter: parent.verticalCenter
      scale: hov.hovered ? 1.15 : 1
      Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
      Behavior on color { ColorAnimation { duration: 160 } }
      SequentialAnimation on opacity {
        running: root.hot && root.visible
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
        onRunningChanged: if (!running) g.opacity = 1
      }
    }
    SpaceDecode {
      visible: root.label !== ""
      text: root.label
      decode: root.kind !== "clock" && root.kind !== "battery"
      family: root.font
      height: parent.height
      color: hov.hovered ? root.fg : root.fa(0.7)
    }
  }
  // громкость — шкала из 12 клеток (его Slider с cells: 12)
  Row {
    visible: root.kind === "audio"
    anchors.right: parent.right
    anchors.rightMargin: 5
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1
    Repeater {
      model: 12
      Rectangle {
        required property int index
        width: 4; height: 8
        color: index < Math.round(Math.min(1, root.volume / 100) * 12) ? (root.muted ? root.fa(0.3) : root.accent) : root.fa(0.12)
      }
    }
  }
  Rectangle {
    visible: root.kind !== "stars"
    anchors.bottom: parent.bottom
    height: 2
    width: hov.hovered ? parent.width - 6 : 0
    x: (parent.width - width) / 2
    color: root.accent
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
  }

  // ── звёзды-столы (его Workspaces.qml) ──
  Item {
    id: stars
    visible: root.kind === "stars"
    x: 2
    readonly property int gap: 16
    readonly property int focused: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property var list: root.kind === "stars" ? Hyprland.workspaces.values.filter(function(w) { return w.id > 0 }).sort(function(a, b) { return a.id - b.id }) : []
    readonly property var ids: {
      var a = list.map(function(w) { return w.id })
      if (a.indexOf(focused) === -1 && focused > 0) a.push(focused)
      return a.sort(function(x, y) { return x - y })
    }
    readonly property var onScreen: Hyprland.monitors.values.map(function(m) { return m.activeWorkspace ? m.activeWorkspace.id : -1 })
    function count(id) { var w = list.find(function(x) { return x.id === id }); return w && w.toplevels ? w.toplevels.values.length : 0 }
    function go(id) { if (id !== focused) root.run(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = '" + id + "' }))"]) }
    function cx(id) { return Math.max(0, ids.indexOf(id)) * gap + gap / 2 }
    width: ids.length * gap
    height: parent.height

    Repeater {
      model: stars.ids
      Item {
        id: star
        required property int modelData
        required property int index
        readonly property bool lit: modelData === stars.focused
        readonly property bool shown: stars.onScreen.indexOf(modelData) !== -1
        readonly property int windows: stars.count(modelData)
        x: index * stars.gap
        width: stars.gap
        height: stars.height
        // звезда: свечение (радиальный градиент) + ядро
        Item {
          visible: star.lit || star.shown
          anchors.centerIn: parent
          width: 18; height: 18
          opacity: star.lit ? 1 : 0.75
          Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0; color: "transparent" }
              GradientStop { position: 0.5; color: root.aa(star.lit ? 0.35 : 0.18) }
              GradientStop { position: 1; color: "transparent" }
            }
          }
          Rectangle {
            anchors.centerIn: parent
            width: parent.height; height: 1
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0; color: "transparent" }
              GradientStop { position: 0.5; color: root.aa(star.lit ? 0.9 : 0.5) }
              GradientStop { position: 1; color: "transparent" }
            }
          }
          Rectangle {
            anchors.centerIn: parent
            width: 1; height: parent.height * 0.7
            gradient: Gradient {
              GradientStop { position: 0; color: "transparent" }
              GradientStop { position: 0.5; color: root.aa(star.lit ? 0.9 : 0.5) }
              GradientStop { position: 1; color: "transparent" }
            }
          }
          Rectangle {
            anchors.centerIn: parent
            width: star.lit ? 6 : 4; height: width; radius: width / 2
            color: Qt.lighter(root.accent, 1.35)
            Behavior on width { NumberAnimation { duration: 200 } }
          }
        }
        Rectangle {
          visible: !star.lit && !star.shown
          anchors.centerIn: parent
          width: star.windows ? 6 : 4
          height: width
          radius: width / 2
          color: root.fa((star.windows ? 0.6 : 0.22) + (area.containsMouse ? 0.3 : 0))
        }
        Item {
          id: orbit
          readonly property int moons: star.lit || star.shown ? 0 : Math.min(4, star.windows - 1)
          visible: moons > 0
          anchors.centerIn: parent
          width: 14; height: 14
          // луны кружат, только пока на звезду навели: вечная анимация перерисовывала бы бар (и его размытие) 120 раз в
          // секунду всё время, пока на соседнем столе больше одного окна
          RotationAnimation on rotation { running: orbit.visible && area.containsMouse; from: 0; to: 360; duration: 6000; loops: Animation.Infinite }
          Repeater {
            model: Math.max(0, orbit.moons)
            Rectangle {
              required property int index
              readonly property real a: index * 2 * Math.PI / orbit.moons
              x: 6 + 6 * Math.cos(a)
              y: 6 + 6 * Math.sin(a)
              width: 2; height: 2; radius: 1
              color: root.fa(0.55)
            }
          }
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: stars.go(star.modelData) }
      }
    }
    WheelHandler {
      onWheel: function(e) {
        var i = stars.ids.indexOf(stars.focused)
        stars.go(stars.ids[Math.max(0, Math.min(stars.ids.length - 1, i + (e.angleDelta.y > 0 ? -1 : 1)))])
      }
    }
    // комета: голова догоняет хвост при смене стола
    property int last: focused
    property real head: cx(focused)
    property real tail: cx(focused)
    onFocusedChanged: {
      var from = cx(last), to = cx(focused)
      last = focused
      if (from === to) return
      headAnim.from = tailAnim.from = from
      headAnim.to = tailAnim.to = to
      shoot.restart()
    }
    ParallelAnimation {
      id: shoot
      NumberAnimation { id: headAnim; target: stars; property: "head"; duration: 360; easing.type: Easing.OutCubic }
      NumberAnimation { id: tailAnim; target: stars; property: "tail"; duration: 360; easing.type: Easing.InQuad }
    }
    Rectangle {
      visible: shoot.running
      x: Math.min(stars.head, stars.tail)
      width: Math.abs(stars.head - stars.tail)
      height: 1.5
      anchors.verticalCenter: parent.verticalCenter
      rotation: stars.head < stars.tail ? 180 : 0
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "transparent" }
        GradientStop { position: 1; color: root.accent }
      }
    }
  }

  // ── клики ──
  Item {
    id: cell
    visible: root.kind !== "stars"
    anchors.fill: parent
    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    WheelHandler {
      enabled: root.kind === "audio"
      onWheel: function(e) { root.run(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", e.angleDelta.y > 0 ? "5%+" : "5%-"]); volProbe.running = true }
    }
    function triggerPress(button) {
      var right = button === Qt.RightButton
      if (root.kind === "user") root.widgets("toggleDashboard")
      else if (root.kind === "media") root.widgets("togglePlayer")
      else if (root.kind === "net") root.widgets("openSettingsSection", "wifi")
      else if (root.kind === "audio") {
        if (right) { root.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]); volProbe.running = true }
        else root.widgets("openSettingsSection", "audio")
      }
      else if (root.kind === "battery") root.widgets("openSettingsSection", "power")
      else if (root.kind === "notifs") root.run(["omarchy-shell", "notifications", "showHistory"])
      else if (root.kind === "clock") root.h24 = !root.h24
      else if (root.kind === "power") root.widgets("togglePower")
    }
    property BarClick click: BarClick { bar: root.bar; target: cell }
  }
}
