import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.Commons as Commons
import "SurfIcons.js" as Icons

// Модули бара Bruteon (по мотивам Bruteon, Darkkal44 — облик с его скриншотов, код свой) — kamradsmeshnyavy.bar.
// Необрутализм: плитки с контуром и жёсткой тенью (BruteTile), пастельные заливки, жирный JetBrains Mono.
// settings.kind:
//   power  — персиковая плитка с кнопкой питания (клик — меню выключения);
//   apps   — закреплённые приложения дока Omarchy (`omarchy dock pin`) значками-глифами: запущенное — с чертой снизу,
//            в фокусе — на персиковой плитке, не запущенное — бледное; между значками — тонкие черты; клик — запустить /
//            перейти к окну;
//   tasks  — зелёная кнопка «☑ Tasks» (клик — панель задач и помодоро поверх окон, toggleTasks);
//   media  — плитка дашборда (сетка; клик — дашборд), черта и название песни с назад / пауза / вперёд;
//   workspaces — столы 1–6 (settings.count) своими значками (settings.icons: терминал, браузер, чат, файлы, музыка,
//            настройки, как у него): занятый — с чертой снизу, пустой — бледный, текущий — на персиковой плитке; между
//            значками — тонкие черты; клик — стол, колесо — соседний;
//   status — белая плашка со звуком, Bluetooth и Wi-Fi (клик — их разделы в меню Super+M);
//   clock  — лавандовая пилюля «🕒 7:47 [PM]» (клик — дашборд; settings.hour12 false — 24 ч);
//   bell   — розовая плитка с колокольчиком (клик — история уведомлений, правый — не беспокоить).
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 44
  readonly property string kind: String(settings && settings.kind || "power")
  readonly property color ink: Commons.Color.foreground
  readonly property color paper: Commons.Color.background
  // текст и значки на пастельных плитках — всегда тёмные (и на тёмной теме, где чернила светлые)
  readonly property color pastelInk: "#161110"
  readonly property string font: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
  // его пастель
  readonly property color peach: "#ffb77a"
  readonly property color green: "#c5e1a5"
  readonly property color lavender: "#dcc4ec"
  readonly property color pink: "#ffcbd5"
  readonly property color salmon: "#ffb3a1"
  readonly property color white: "#fbf5f1"

  implicitWidth: row.implicitWidth + 8
  implicitHeight: across

  // ── данные ──
  property var pinned: []
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: root.kind === "apps"
    printErrors: false
    onLoaded: { try { var d = JSON.parse(text() || "{}"); root.pinned = d.dock && Array.isArray(d.dock.pinned) ? d.dock.pinned : [] } catch (e) { root.pinned = [] } }
    onFileChanged: reload()
  }
  function clsOf(t) { var o = t && t.lastIpcObject; return String(o && (o["class"] || o.initialClass) || (t && t.wayland && t.wayland.appId) || "").toLowerCase() }
  function matches(cls, id, entry) {
    var a = String(id).toLowerCase().replace(/\.desktop$/, ""), e = entry ? String(entry.startupClass || entry.id || "").toLowerCase() : ""
    return cls !== "" && (cls === a || cls === e || a.indexOf(cls) !== -1 || cls.indexOf(a.split(".").pop()) !== -1)
  }
  readonly property var apps: pinned.map(function(id) {
    var e = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
    var wins = Hyprland.toplevels.values.filter(function(t) { return root.matches(root.clsOf(t), id, e) })
    var act = Hyprland.activeToplevel && wins.indexOf(Hyprland.activeToplevel) !== -1
    var g = Icons.iconFor(id + " " + (e ? e.name : ""))
    return { id: id, name: e ? e.name : id, glyph: g === Icons.FALLBACK ? "" : g, icon: e ? String(e.icon || "") : "", run: wins.length > 0, active: act,
             addr: wins.length ? String(wins[0].lastIpcObject && wins[0].lastIpcObject.address || "") : "" }
  })

  readonly property var player: {
    var l = Mpris.players.values
    for (var i = 0; i < l.length; i++) if (l[i].isPlaying && l[i].trackTitle) return l[i]
    for (var j = 0; j < l.length; j++) if (l[j].trackTitle) return l[j]
    return null
  }
  property date now: new Date()
  Timer { running: root.kind === "clock"; repeat: true; interval: 1000; triggeredOnStart: true; onTriggered: root.now = new Date() }
  readonly property bool h12: !(settings && settings.hour12 === false)

  property bool dashOpen: false
  Process {
    id: dashProbe
    command: ["sh", "-c", "hyprctl layers -j | grep -c '\"omarchy-dashboard\"'"]
    stdout: StdioCollector { onStreamFinished: root.dashOpen = parseInt(text) > 0 }
  }
  Timer { running: root.kind === "media"; repeat: true; interval: 700; onTriggered: if (!dashProbe.running) dashProbe.running = true }

  function run(a) { Quickshell.execDetached(a) }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 10

    // питание
    BruteTile {
      id: pw
      visible: root.kind === "power"
      width: 28; height: 28
      anchors.verticalCenter: parent.verticalCenter
      fill: root.peach; ink: root.ink
      hovered: ph.hovered
      Text { anchors.centerIn: parent; text: ""; color: root.pastelInk; font.family: root.font; font.pixelSize: 13 }
      HoverHandler { id: ph; cursorShape: Qt.PointingHandCursor }
      function triggerPress(button) { root.run(["omarchy-shell", "widgets", "togglePower"]) }
      property BarClick click: BarClick { bar: root.bar; target: pw }
    }

    // столы
    Row {
      visible: root.kind === "workspaces"
      spacing: 6
      anchors.verticalCenter: parent.verticalCenter
      Repeater {
        model: root.kind === "workspaces" ? (Number(root.settings && root.settings.count) || 6) : 0
        Row {
          id: wsSlot
          required property int index
          readonly property int wid: index + 1
          readonly property var icons: root.settings && root.settings.icons || ["\uf120", "\uf268", "\uf232", "\uf07b", "\uf1bc", "\uf013"]
          readonly property bool on: !!Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wid
          readonly property bool busy: { var w = Hyprland.workspaces.values.find(function(x) { return x.id === wsSlot.wid }); return !!w && w.toplevels.values.length > 0 }
          spacing: 6
          Rectangle { visible: wsSlot.index > 0; width: 1.5; height: 14; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.25) }
          Item {
            id: ws
            width: 30; height: 32
            BruteTile {
              anchors.centerIn: parent
              width: 28; height: 28
              flat: !wsSlot.on
              fill: wsSlot.on ? root.peach : "transparent"
              ink: root.ink
              hovered: wh.hovered
              Text {
                anchors.centerIn: parent
                text: wsSlot.icons[wsSlot.index % wsSlot.icons.length]
                color: wsSlot.on ? root.pastelInk : root.ink
                opacity: wsSlot.on || wsSlot.busy ? 1 : wh.hovered ? 0.6 : 0.3
                font.family: root.font
                font.pixelSize: 14
              }
            }
            Rectangle {
              visible: wsSlot.busy && !wsSlot.on
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              width: 9; height: 3; radius: 1.5
              color: root.ink
            }
            HoverHandler { id: wh; cursorShape: Qt.PointingHandCursor }
            function triggerPress(button) { root.run(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = '" + wsSlot.wid + "' }))"]) }
            property BarClick click: BarClick { bar: root.bar; target: ws }
          }
        }
      }
    }

    // приложения
    Row {
      visible: root.kind === "apps"
      spacing: 6
      anchors.verticalCenter: parent.verticalCenter
      Repeater {
        model: root.kind === "apps" ? root.apps : []
        Row {
          id: appSlot
          required property var modelData
          required property int index
          spacing: 6
          Rectangle { visible: appSlot.index > 0; width: 1.5; height: 14; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.25) }
          Item {
            id: app
            width: 30; height: 32
            BruteTile {
              anchors.centerIn: parent
              width: 28; height: 28
              flat: !appSlot.modelData.active
              fill: appSlot.modelData.active ? root.peach : "transparent"
              ink: root.ink
              hovered: ah.hovered
              Text {
                visible: appSlot.modelData.glyph !== ""
                anchors.centerIn: parent
                text: appSlot.modelData.glyph
                color: appSlot.modelData.active ? root.pastelInk : root.ink
                opacity: appSlot.modelData.run ? 1 : 0.3
                font.family: root.font
                font.pixelSize: 15
              }
              // нет глифа (веб-приложения) — свой значок приложения, перекрашенный в цвет чернил
              IconImage {
                id: appIcon
                visible: false
                anchors.centerIn: parent
                implicitSize: 16
                asynchronous: false
                source: appSlot.modelData.glyph === "" ? Quickshell.iconPath(appSlot.modelData.icon, "application-x-executable") : ""
              }
              MultiEffect {
                visible: appSlot.modelData.glyph === ""
                anchors.fill: appIcon
                source: appIcon
                colorization: 1
                colorizationColor: root.ink
                brightness: -0.2
                opacity: appSlot.modelData.run ? 1 : 0.3
              }
            }
            Rectangle {
              visible: appSlot.modelData.run && !appSlot.modelData.active
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              width: 9; height: 3; radius: 1.5
              color: root.ink
            }
            HoverHandler {
              id: ah
              cursorShape: Qt.PointingHandCursor
              onHoveredChanged: if (root.bar) { if (hovered) root.bar.showTooltip(app, appSlot.modelData.name); else root.bar.hideTooltip(app) }
            }
            function triggerPress(button) {
              var m = appSlot.modelData
              if (m.run && m.addr) root.run(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ window = 'address:" + m.addr + "' }))"])
              else root.run(["bash", "-c", "uwsm-app -- gtk-launch \"$1\"", "brute", m.id])
            }
            property BarClick click: BarClick { bar: root.bar; target: app }
          }
        }
      }
    }

    // задачи
    BruteTile {
      id: tk
      visible: root.kind === "tasks"
      width: tkRow.implicitWidth + 20; height: 28
      anchors.verticalCenter: parent.verticalCenter
      fill: root.green; ink: root.ink
      hovered: th.hovered
      Row {
        id: tkRow
        anchors.centerIn: parent
        spacing: 6
        Text { anchors.verticalCenter: parent.verticalCenter; text: ""; color: root.pastelInk; font.family: root.font; font.pixelSize: 13 }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "Tasks"; color: root.pastelInk; font.family: root.font; font.pixelSize: 13; font.bold: true }
      }
      HoverHandler { id: th; cursorShape: Qt.PointingHandCursor }
      // панель задач и помодоро поверх окон (TasksBrute.qml в kamradsmeshnyavy.widgets), как у него
      function triggerPress(button) { root.run(["omarchy-shell", "widgets", "toggleTasks"]) }
      property BarClick click: BarClick { bar: root.bar; target: tk }
    }

    // дашборд и плеер
    BruteTile {
      id: db
      visible: root.kind === "media"
      width: 28; height: 28
      anchors.verticalCenter: parent.verticalCenter
      fill: root.dashOpen ? root.salmon : root.paper; ink: root.ink
      flat: !root.dashOpen
      hovered: dh.hovered
      Text { anchors.centerIn: parent; text: root.dashOpen ? "" : "\u{F0570}"; color: root.dashOpen ? root.pastelInk : root.ink; font.family: root.font; font.pixelSize: 14 }
      HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
      function triggerPress(button) { root.dashOpen = !root.dashOpen; root.run(["omarchy-shell", "widgets", "toggleDashboard"]) }
      property BarClick click: BarClick { bar: root.bar; target: db }
    }
    Rectangle { visible: root.kind === "media"; width: 1.5; height: 20; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3) }
    Text {
      visible: root.kind === "media"
      anchors.verticalCenter: parent.verticalCenter
      text: root.player ? root.player.trackTitle : "Nothing playing"
      width: Math.min(implicitWidth, Number(root.settings && root.settings.width) || 220)
      elide: Text.ElideRight
      color: root.ink
      font.family: root.font; font.pixelSize: 13; font.bold: true
    }
    Repeater {
      model: root.kind === "media" ? [["", "previous"], [root.player && root.player.isPlaying ? "" : "", "togglePlaying"], ["", "next"]] : []
      Item {
        id: mb
        required property var modelData
        width: 16; height: 28
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Text { anchors.centerIn: parent; text: mb.modelData[0]; color: root.ink; opacity: mh.hovered ? 0.9 : 0.4; font.family: root.font; font.pixelSize: 11 }
        HoverHandler { id: mh; cursorShape: Qt.PointingHandCursor }
        function triggerPress(button) { if (root.player) root.player[mb.modelData[1]]() }
        property BarClick click: BarClick { bar: root.bar; target: mb }
      }
    }

    // звук, Bluetooth, Wi-Fi
    BruteTile {
      visible: root.kind === "status"
      width: stRow.implicitWidth + 24; height: 28
      anchors.verticalCenter: parent.verticalCenter
      fill: root.white; ink: root.ink
      Row {
        id: stRow
        anchors.centerIn: parent
        spacing: 16
        Repeater {
          // панели звука / Bluetooth / сети — разделы меню Super+M (стоковых IPC без их модулей на баре нет)
          model: root.kind === "status" ? [["\uf028", "audio"], ["\uf293", "bt"], ["\uf1eb", "wifi"]] : []
          Item {
            id: sb
            required property var modelData
            width: 16; height: 22
            Text { anchors.centerIn: parent; text: sb.modelData[0]; color: root.pastelInk; font.family: root.font; font.pixelSize: 13; scale: sh2.hovered ? 1.15 : 1 }
            HoverHandler { id: sh2; cursorShape: Qt.PointingHandCursor }
            function triggerPress(button) { root.run(["omarchy-shell", "widgets", "openSettingsSection", sb.modelData[1]]) }
            property BarClick click: BarClick { bar: root.bar; target: sb }
          }
        }
      }
    }

    // часы
    BruteTile {
      id: ck
      visible: root.kind === "clock"
      width: ckRow.implicitWidth + 20; height: 28
      anchors.verticalCenter: parent.verticalCenter
      fill: root.lavender; ink: root.ink
      hovered: kh.hovered
      Row {
        id: ckRow
        anchors.centerIn: parent
        spacing: 6
        Text { anchors.verticalCenter: parent.verticalCenter; text: ""; color: root.pastelInk; font.family: root.font; font.pixelSize: 12 }
        Text { anchors.verticalCenter: parent.verticalCenter; text: root.h12 ? Qt.formatTime(root.now, "h:mm AP").split(" ")[0] : Qt.formatTime(root.now, "HH:mm"); color: root.pastelInk; font.family: root.font; font.pixelSize: 14; font.bold: true }
        Rectangle {
          visible: root.h12
          anchors.verticalCenter: parent.verticalCenter
          width: ap.implicitWidth + 4; height: 12; radius: 2
          color: "transparent"; border.width: 1.2; border.color: root.pastelInk
          Text { id: ap; anchors.centerIn: parent; text: Qt.formatTime(root.now, "AP"); color: root.pastelInk; font.family: root.font; font.pixelSize: 7; font.bold: true }
        }
      }
      HoverHandler { id: kh; cursorShape: Qt.PointingHandCursor }
      function triggerPress(button) { root.run(["omarchy-shell", "widgets", "toggleDashboard"]) }
      property BarClick click: BarClick { bar: root.bar; target: ck }
    }

    // уведомления
    BruteTile {
      id: bl
      visible: root.kind === "bell"
      width: 28; height: 28
      anchors.verticalCenter: parent.verticalCenter
      fill: root.pink; ink: root.ink
      hovered: bh.hovered
      Text { anchors.centerIn: parent; text: ""; color: root.pastelInk; font.family: root.font; font.pixelSize: 13 }
      HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor }
      function triggerPress(button) {
        if (button === Qt.RightButton) root.run(["omarchy-shell", "notifications", "toggleDnd"])
        else root.run(["omarchy-shell", "notifications", "showHistory"])
      }
      property BarClick click: BarClick { bar: root.bar; target: bl }
    }
  }
}
