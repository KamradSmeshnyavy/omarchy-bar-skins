import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import qs.Commons as Commons

// Пилюля бара Modern (по мотивам стиля Modern из elifouts/Dotfiles, GPL-3.0 — его quickshell/Modern/bar: Pill.qml,
// Module.qml, Workspaces.qml Dots) — kamradsmeshnyavy.bar. Одна пилюля — несколько модулей (settings.modules) в
// скруглённой капсуле: фон темы на 60 % (его Theme.surface(0.6)) с тонкой окантовкой — текст 20 % сверху, 7 % снизу.
// Модули: user, workspaces (точки: текущий — капсула 22 px акцентом, занятые — текстом, пустые — 25 %), media (трек и
// волна, пока играет; иначе — date), date, constdate, timer, clock (жирно), tray, updates, notifications, network,
// audio, power, «|» — черта. Наведение на столы / музыку / часы и клик по сети / звуку / питанию / трею / уведомлениям —
// пилюля вырастает в карточку: её рисует «остров» виджетов (widgets/ModernIsland.qml) поверх пилюли, сюда приходит
// только место пилюли (IPC widgets modernIsland). settings.align — left / center / right (куда растёт карточка).
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 30
  readonly property var mods: (settings && settings.modules) || ["clock"]
  readonly property string align: String(settings && settings.align || "center")
  readonly property color fg: Commons.Color.foreground
  readonly property color bg: Commons.Color.background
  readonly property color accent: Commons.Color.accent
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property color bright: Qt.lighter(fg, 1.25)
  readonly property string font: Qt.fontFamilies().indexOf("CodeNewRoman Nerd Font Propo") !== -1 ? "CodeNewRoman Nerd Font Propo"
    : Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
  readonly property real radius: Math.min(10, pillH / 2)
  readonly property real pillH: Math.min(across, 30)

  implicitWidth: row.implicitWidth + 8
  implicitHeight: across

  function run(c) { Quickshell.execDetached(c) }
  function widgets(fn, args) { run(["omarchy-shell", "widgets", fn].concat(args || [])) }

  // ── данные ──
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: { var d = new Date(); if (d.getMinutes() !== root.now.getMinutes()) root.now = d } }
  readonly property var player: {
    var all = Mpris.players.values
    for (var i = 0; i < all.length; i++) if (all[i].isPlaying) return all[i]
    return null
  }
  readonly property bool playing: !!player
  property int volume: 0
  property bool muted: false
  Process {
    id: volProbe
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
    stdout: StdioCollector { onStreamFinished: { var m = text.match(/([\d.]+)/); root.volume = m ? Math.round(Number(m[1]) * 100) : 0; root.muted = text.indexOf("MUTED") !== -1 } }
  }
  Timer { interval: 2000; repeat: true; running: root.mods.indexOf("audio") !== -1; triggeredOnStart: true; onTriggered: if (!volProbe.running) volProbe.running = true }
  property string net: ""
  property bool online: true
  Process {
    id: netProbe
    command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null | awk -F: '$2==\"connected\"{print $1\":\"$3; exit}'"]
    stdout: StdioCollector { onStreamFinished: { var s = text.trim(), i = s.indexOf(":"); root.online = s !== ""; root.net = i >= 0 ? (s.indexOf("ethernet") === 0 ? "ethernet" : s.slice(i + 1)) : "" } }
  }
  Timer { interval: 10000; repeat: true; running: root.mods.indexOf("network") !== -1; triggeredOnStart: true; onTriggered: if (!netProbe.running) netProbe.running = true }
  property int updates: 0
  Process {
    id: updProbe
    command: ["sh", "-c", "(checkupdates 2>/dev/null; yay -Qua 2>/dev/null) | wc -l"]
    stdout: StdioCollector { onStreamFinished: root.updates = Number(text.trim()) || 0 }
  }
  Timer { interval: 30 * 60 * 1000; repeat: true; running: root.mods.indexOf("updates") !== -1; triggeredOnStart: true; onTriggered: if (!updProbe.running) updProbe.running = true }
  property int msgs: 0
  Process {
    id: msgProbe
    command: ["sh", "-c", "ls ~/.local/state/omarchy/notifications/history 2>/dev/null | wc -l"]
    stdout: StdioCollector { onStreamFinished: root.msgs = Number(text.trim()) || 0 }
  }
  Timer { interval: 5000; repeat: true; running: root.mods.indexOf("notifications") !== -1; triggeredOnStart: true; onTriggered: if (!msgProbe.running) msgProbe.running = true }

  // ── карточка-остров: место пилюли — виджетам (они рисуют растущую карточку поверх) ──
  property string openPage: ""
  function spot() {
    var p = root.mapToItem(null, 0, 0)
    return [Math.round(p.x), Math.round(p.y + (root.height - root.pillH) / 2), Math.round(root.width), Math.round(root.pillH)]
  }
  function island(page, mode) {
    root.widgets("modernIsland", [page, spot().join(" "), root.align, mode || "click"])
  }
  Timer { id: restOpen; interval: 140; property string page: ""; onTriggered: root.island(page, "hover") }
  function rest(page) { restOpen.page = page; restOpen.restart() }
  function unrest() { restOpen.stop() }

  // ── вид ──
  readonly property bool bare: settings && settings.bare === true  // full / zen: без своего стекла
  // пока остров виджетов накрывает эту пилюлю — свой фон прячем (его стекло — одно на пилюлю и карточку)
  property string covered: ""
  FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-modern-island"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.covered = text().trim()
    onLoadFailed: root.covered = ""
  }
  readonly property bool hidden: covered !== "" && covered === [spot()[0], spot()[1], spot()[2]].join(" ")
  Rectangle {
    visible: !root.bare && !root.hidden
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width; height: root.pillH
    radius: root.radius
    gradient: Gradient {
      GradientStop { position: 0; color: Qt.tint(root.a(root.bg, 0.6), root.a(root.fg, 0.2)) }
      GradientStop { position: 1; color: Qt.tint(root.a(root.bg, 0.6), root.a(root.fg, 0.07)) }
    }
    Rectangle { anchors.fill: parent; anchors.margins: 1; radius: Math.max(0, root.radius - 1); color: root.a(root.bg, 0.6) }
  }

  component ChipText: Text {
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    font.family: root.font
    font.pixelSize: 12
    color: root.fg
  }
  component Chip: Item {
    id: chip
    property string glyph: ""
    property color glyphColor: root.fg
    property string text: ""
    property string page: ""
    property bool hoverOpens: false
    signal clicked(int button)
    implicitWidth: cr.implicitWidth + 20
    implicitHeight: root.pillH
    Rectangle { anchors.fill: parent; anchors.margins: 4; radius: Math.min(8, height / 2); color: ca.containsMouse ? root.a(root.fg, 0.08) : "transparent" }
    Row {
      id: cr
      x: 10
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6
      ChipText { visible: chip.glyph !== ""; text: chip.glyph; color: chip.glyphColor; font.pixelSize: 13 }
      ChipText { visible: chip.text !== ""; text: chip.text }
    }
    MouseArea {
      id: ca
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      onEntered: if (chip.hoverOpens && chip.page) root.rest(chip.page)
      onExited: root.unrest()
      onClicked: function(m) { if (chip.page && m.button === Qt.LeftButton) root.island(chip.page); else chip.clicked(m.button) }
    }
  }

  Row {
    id: row
    x: 4
    height: parent.height
    Repeater {
      model: root.mods
      Loader {
        required property string modelData
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        sourceComponent: ({ user: userC, workspaces: wsC, media: mediaC, date: dateC, constdate: constC, timer: timerC, clock: clockC,
          tray: trayC, updates: updC, notifications: notifC, network: netC, audio: audioC, power: powerC, "|": divC })[modelData] ?? null
      }
    }
  }

  Component { id: userC; Chip { text: Quickshell.env("USER"); onClicked: b => root.widgets(b === Qt.RightButton ? "togglePrefs" : "toggleDashboard") } }
  Component {
    id: wsC
    Item {
      implicitWidth: dots.implicitWidth + 20
      implicitHeight: root.pillH
      HoverHandler { onHoveredChanged: hovered ? root.rest("workspaces") : root.unrest() }
      Row {
        id: dots
        anchors.centerIn: parent
        spacing: 6
        readonly property int activeId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
        readonly property var ids: {
          var s = {}
          for (var i = 1; i <= 5; i++) s[i] = true
          Hyprland.workspaces.values.forEach(function(w) { if (w.id > 0) s[w.id] = true })
          return Object.keys(s).map(Number).sort(function(a, b) { return a - b })
        }
        function occupied(id) { var w = Hyprland.workspaces.values.find(function(x) { return x.id === id }); return !!w && w.toplevels && w.toplevels.values.length > 0 }
        function go(id) { root.run(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = " + id + " }))"]) }
        Repeater {
          model: dots.ids
          Rectangle {
            required property int modelData
            readonly property bool active: modelData === dots.activeId
            readonly property bool full: dots.occupied(modelData)
            anchors.verticalCenter: parent.verticalCenter
            width: active ? 22 : 8
            height: 8
            radius: 4
            color: active ? root.accent : full ? (da.containsMouse ? root.bright : root.fg) : root.a(root.fg, da.containsMouse ? 0.5 : 0.25)
            Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 160 } }
            MouseArea { id: da; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dots.go(parent.modelData) }
          }
        }
        WheelHandler {
          onWheel: function(e) { var i = dots.ids.indexOf(dots.activeId); dots.go(dots.ids[Math.max(0, Math.min(dots.ids.length - 1, (i < 0 ? 0 : i) + (e.angleDelta.y > 0 ? -1 : 1)))]) }
        }
      }
    }
  }
  Component {
    id: mediaC
    Item {
      visible: root.playing
      implicitWidth: visible ? mr.implicitWidth + 20 : 0
      implicitHeight: root.pillH
      HoverHandler { onHoveredChanged: hovered ? root.rest("island") : root.unrest() }
      MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.MiddleButton; cursorShape: Qt.PointingHandCursor
        onClicked: function(m) { if (m.button === Qt.MiddleButton && root.player) root.player.togglePlaying(); else root.island("island") } }
      Row {
        id: mr
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        ChipText {
          width: Math.min(implicitWidth, 170)
          elide: Text.ElideRight
          text: root.player ? [root.player.trackTitle, root.player.trackArtist].filter(function(s) { return !!s }).join("  ·  ") : ""
        }
        // его MiniWave: пять столбиков, пока играет
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Repeater {
            model: 5
            Rectangle {
              required property int index
              width: 2; radius: 1
              anchors.verticalCenter: parent.verticalCenter
              color: root.accent
              property real k: 0.4
              height: 4 + 8 * k
              SequentialAnimation on k {
                running: root.playing; loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 300 + index * 70; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.2; duration: 300 + index * 70; easing.type: Easing.InOutSine }
              }
            }
          }
        }
      }
    }
  }
  Component {
    id: dateC
    Item {
      visible: !root.playing || root.mods.indexOf("media") === -1
      implicitWidth: visible ? dt.implicitWidth + 20 : 0
      implicitHeight: root.pillH
      HoverHandler { onHoveredChanged: hovered ? root.rest("island") : root.unrest() }
      ChipText { id: dt; x: 10; text: Qt.formatDate(root.now, "ddd, MMM d") }
    }
  }
  Component { id: constC; Item { implicitWidth: ct.implicitWidth + 20; implicitHeight: root.pillH; HoverHandler { onHoveredChanged: hovered ? root.rest("island") : root.unrest() } ChipText { id: ct; x: 10; text: Qt.formatDate(root.now, "ddd, MMM d") } } }
  Component { id: timerC; Item { implicitWidth: 0; implicitHeight: root.pillH } }
  Component {
    id: clockC
    Item {
      implicitWidth: cl.implicitWidth + 20
      implicitHeight: root.pillH
      HoverHandler { onHoveredChanged: hovered ? root.rest("calendar") : root.unrest() }
      Text { id: cl; anchors.centerIn: parent; text: Qt.formatTime(root.now, "h:mm AP"); font.family: root.font; font.pixelSize: 13; font.bold: true; color: root.bright }
    }
  }
  Component {
    id: trayC
    Row {
      visible: SystemTray.items.values.length > 0
      height: root.pillH
      Repeater {
        model: SystemTray.items.values
        Item {
          required property var modelData
          width: 26; height: root.pillH
          Image { anchors.centerIn: parent; width: 15; height: 15; source: parent.modelData.icon; sourceSize.width: 30; sourceSize.height: 30 }
          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: function(m) { if (m.button === Qt.LeftButton) parent.modelData.activate(); else if (m.button === Qt.MiddleButton) parent.modelData.secondaryActivate(); else root.island("tray") }
          }
        }
      }
    }
  }
  Component { id: updC; Chip { visible: root.updates > 0; glyph: "󰅢"; glyphColor: Commons.Color.urgent; text: root.updates > 0 ? String(root.updates) : ""; page: "updates" } }
  Component { id: notifC; Chip { glyph: "󰂚"; text: root.msgs > 0 ? String(root.msgs) : ""; page: "notifications" } }
  Component { id: netC; Chip { glyph: !root.online ? "󰤮" : root.net === "ethernet" ? "󰈀" : "󰤨"; page: "network" } }
  Component {
    id: audioC
    Chip {
      page: "audio"
      glyph: root.muted ? "󰝟" : root.volume > 66 ? "󰕾" : root.volume > 33 ? "󰖀" : "󰕿"
      glyphColor: root.muted ? root.a(root.fg, 0.5) : root.accent
      text: root.volume + "%"
      WheelHandler { onWheel: function(e) { root.run(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", e.angleDelta.y > 0 ? "5%+" : "5%-"]); volProbe.running = true } }
    }
  }
  Component { id: powerC; Chip { glyph: "⏻"; page: "power" } }
  Component { id: divC; Item { implicitWidth: 9; implicitHeight: root.pillH; Rectangle { anchors.centerIn: parent; width: 1; height: root.pillH - 14; color: root.a(root.fg, 0.14) } } }
}
