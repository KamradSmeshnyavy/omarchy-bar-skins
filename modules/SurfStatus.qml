import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Пилюли справа на баре surface (по мотивам surface-dots, snes19xx — bars/TopBar.qml, TopBarItem.qml; README разрешает
// брать со ссылкой) — модуль бара kamradsmeshnyavy.bar. settings.kind:
//   updates — зелёная пилюля со значком pacman и числом обновлений (checkupdates раз в 30 мин; нет обновлений —
//             пилюли нет); клик — omarchy-update в плавающем терминале;
//   battery — значок и процент; цвет: заряжается — акцент, ≤ 30 % — охра, ≤ 20 % — оранжевый, ≤ 10 % — красный и
//             мигание; при подключении зарядки — расходящееся кольцо;
//   clock   — «Mon, Jan 26 • 6:11 PM»: дата акцентом, время жирным; клик — дашборд (Hub).
// settings.hour12 — 12-часовой формат (по умолчанию как у surface-dots — да), settings.command — своя команда клика.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 40
  readonly property string kind: String(settings && settings.kind || "clock")
  readonly property SurfPal pal: SurfPal {}

  visible: kind !== "updates" || updates > 0 || upd.running
  implicitWidth: visible ? pill.implicitWidth : 0
  implicitHeight: across

  // обновления
  property int updates: 0
  Process {
    id: chk
    command: ["bash", "-c", "[ -e /var/lib/pacman/db.lck ] && exit 1; checkupdates 2>/dev/null | wc -l"]
    stdout: StdioCollector { onStreamFinished: { var n = parseInt(text.trim()); if (!isNaN(n)) root.updates = n } }
  }
  Timer { running: root.kind === "updates"; repeat: true; triggeredOnStart: true; interval: 1800000; onTriggered: if (!chk.running) chk.running = true }
  Process {
    id: upd
    command: ["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"]
    onRunningChanged: if (!running && !chk.running) chk.running = true
  }

  // батарея
  readonly property var dev: UPower.displayDevice
  readonly property int cap: dev && dev.ready ? Math.round(dev.percentage * (dev.percentage <= 1 ? 100 : 1)) : 0
  readonly property bool charging: !!dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge)
  readonly property color batColor: charging ? pal.accent : cap <= 10 ? (pal.dark ? "#ff0004" : "#ff001e")
    : cap <= 20 ? (pal.dark ? "#e69875" : "#a55524") : cap <= 30 ? (pal.dark ? "#dbbc7f" : "#7a5b00") : pal.text
  readonly property string batIcon: {
    if (charging) return "󰂄"
    var g = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    return cap >= 98 ? g[9] : g[Math.max(0, Math.min(8, Math.floor(cap / 10) - 1))]
  }
  onChargingChanged: if (charging && kind === "battery") surge.restart()
  SequentialAnimation on opacity {
    running: root.kind === "battery" && root.cap <= 10 && !root.charging && root.cap > 0
    loops: Animation.Infinite
    NumberAnimation { to: 0.3; duration: 500 }
    NumberAnimation { to: 1; duration: 500 }
    onRunningChanged: if (!running) root.opacity = 1
  }

  // часы
  property date now: new Date()
  Timer { running: root.kind === "clock"; repeat: true; interval: 1000; onTriggered: root.now = new Date() }
  readonly property bool h12: !(settings && settings.hour12 === false)

  SurfPill {
    id: pill
    anchors.verticalCenter: parent.verticalCenter
    pad: root.kind === "clock" ? 15 : 12
    fill: root.kind === "updates" ? (root.pal.dark ? Qt.rgba(0.51, 0.58, 0.41, 0.81) : Qt.rgba(0.5, 0.61, 0.35, 0.75)) : root.pal.card
    Row {
      spacing: root.kind === "clock" ? 8 : 6
      Text {
        visible: root.kind !== "clock"
        anchors.verticalCenter: parent.verticalCenter
        text: root.kind === "updates" ? "󰮯" : root.batIcon
        color: root.kind === "updates" ? root.pal.onAccent : root.batColor
        font.family: root.pal.icons
        font.pixelSize: 14
      }
      Text {
        visible: root.kind !== "clock"
        anchors.verticalCenter: parent.verticalCenter
        text: root.kind === "updates" ? (upd.running ? "…" : String(root.updates)) : root.cap + "%"
        color: root.kind === "updates" ? root.pal.onAccent : root.batColor
        font.family: root.pal.font
        font.pixelSize: 12
        font.weight: 800
      }
      Text {
        visible: root.kind === "clock"
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(root.now, "ddd, MMM d")
        color: root.pal.accent
        font.family: root.pal.font
        font.pixelSize: 12
        font.weight: 600
      }
      Text { visible: root.kind === "clock"; anchors.verticalCenter: parent.verticalCenter; text: "•"; color: root.pal.text2; font.pixelSize: 10 }
      Text {
        visible: root.kind === "clock"
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(root.now, root.h12 ? "h:mm AP" : "HH:mm")
        color: root.pal.text
        font.family: root.pal.font
        font.pixelSize: 13
        font.weight: 800
      }
    }
  }
  // кольцо при подключении зарядки
  Rectangle {
    id: ring
    anchors.centerIn: pill
    width: pill.width; height: pill.height; radius: height / 2
    color: "transparent"
    border.width: 2
    border.color: root.pal.accent
    opacity: 0
  }
  ParallelAnimation {
    id: surge
    NumberAnimation { target: ring; property: "scale"; from: 1; to: 1.45; duration: 520; easing.type: Easing.OutCubic }
    NumberAnimation { target: ring; property: "opacity"; from: 1; to: 0; duration: 520; easing.type: Easing.OutCubic }
  }

  function triggerPress(button) {
    if (settings && settings.command) { Quickshell.execDetached(["bash", "-c", String(settings.command)]); return }
    if (kind === "updates") { if (!upd.running) upd.running = true }
    else if (kind === "clock") Quickshell.execDetached(["omarchy-shell", "widgets", "toggleDashboard"])
    else if (kind === "battery") Quickshell.execDetached(["omarchy-shell", "omarchy.power", "toggle"])
  }
}
