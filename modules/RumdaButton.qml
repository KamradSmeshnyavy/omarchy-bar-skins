import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

// Кнопка Rumda (по мотивам hexonide/rumda; код свой): карточка со значком цветом акцента.
// settings.kind: theme — луна / солнце, переключает тёмную и светлую тему rumda (rumda-dark ↔ rumda-light, и -color);
// net — «кошачья мордочка», клик — панель сети (тусклая без сети); weather — значок и температура (open-meteo по
// городу из widgets.json weatherCity, раз в 30 мин); power — меню выключения; иначе settings.icon и settings.command.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 48
  readonly property string kind: String(settings && settings.kind || "power")
  readonly property string px: Qt.fontFamilies().indexOf("Dogica Pixel") !== -1 ? "Dogica Pixel" : (bar && bar.fontFamily ? bar.fontFamily : "monospace")
  readonly property color acc: Commons.Color.accent

  // тема: тёмная или светлая сейчас
  property string themeName: ""
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: root.themeName = text().trim()
  }
  readonly property bool lightTheme: /light/.test(themeName)
  // сеть: есть ли соединение
  property bool online: true
  Process {
    id: netProbe
    command: ["bash", "-c", "nmcli -t -f STATE general 2>/dev/null"]
    stdout: StdioCollector { onStreamFinished: root.online = text.trim().indexOf("connected") === 0 }
  }
  Timer { interval: 10000; running: root.kind === "net"; repeat: true; triggeredOnStart: true; onTriggered: if (!netProbe.running) netProbe.running = true }
  // погода
  property string temp: ""
  property int wcode: -1
  Process {
    id: wx
    command: ["bash", "-c", "c=$(jq -r '.weatherCity // empty' \"$HOME/.config/omarchy/widgets.json\" 2>/dev/null); [ -z \"$c\" ] && exit 0; " +
      "g=$(python3 -I -c 'import sys,json,urllib.request,urllib.parse; r=json.load(urllib.request.urlopen(\"https://geocoding-api.open-meteo.com/v1/search?count=1&name=\"+urllib.parse.quote(sys.argv[1]),timeout=10)); p=r[\"results\"][0]; print(p[\"latitude\"],p[\"longitude\"])' \"$c\") || exit 0; set -- $g; " +
      "python3 -I -c 'import sys,json,urllib.request; r=json.load(urllib.request.urlopen(\"https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&current=temperature_2m,weather_code\"%(sys.argv[1],sys.argv[2]),timeout=10)); c=r[\"current\"]; print(round(c[\"temperature_2m\"]), c[\"weather_code\"])' \"$1\" \"$2\""]
    stdout: StdioCollector { onStreamFinished: { var f = text.trim().split(/\s+/); if (f.length >= 2) { root.temp = f[0] + "°"; root.wcode = Number(f[1]) } } }
  }
  Timer { interval: 1800000; running: root.kind === "weather"; repeat: true; triggeredOnStart: true; onTriggered: if (!wx.running) wx.running = true }
  function wxGlyph(c) {
    if (c === 0) return root.lightTheme ? "󰖙" : "󰖔"
    if (c <= 3) return "󰖕"
    if (c <= 48) return "󰖑"
    if (c <= 67 || (c >= 80 && c <= 82)) return "󰖗"
    if (c <= 86) return "󰖘"
    return "󰖓"
  }

  implicitWidth: across
  implicitHeight: card.height + 8
  RumdaCard {
    id: card
    bar: root.bar
    hot: hov.hovered
    anchors.centerIn: parent
    width: root.across - 14; height: root.kind === "weather" ? 44 : 30
    opacity: root.kind === "net" && !root.online ? 0.5 : 1
    Text {
      visible: root.kind !== "net"
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.kind === "weather" ? 5 : (parent.height - height) / 2
      text: root.kind === "theme" ? (root.lightTheme ? "󰖨" : "󰽥") : root.kind === "weather" ? root.wxGlyph(root.wcode)
        : root.kind === "power" ? "󰐥" : String(root.settings && root.settings.icon || "")
      color: root.acc
      font.family: Commons.Style.font.family; font.pixelSize: 15
    }
    Text {
      visible: root.kind === "weather"
      anchors.horizontalCenter: parent.horizontalCenter; y: 26
      text: root.temp || "—"
      color: root.acc; font.family: root.px; font.pixelSize: 8
    }
    // сеть: кошачья мордочка
    Text {
      visible: root.kind === "net"
      anchors.centerIn: parent
      text: "=^.^="
      color: root.acc; font.family: root.px; font.pixelSize: 6
    }
  }
  HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
  function triggerPress(button) {
    if (kind === "theme") {
      var t = themeName.indexOf("rumda-") === 0 ? themeName : "rumda-dark"
      var next = /light/.test(t) ? t.replace("light", "dark") : t.replace("dark", "light")
      Quickshell.execDetached(["omarchy", "theme", "set", next])
    } else if (kind === "net") Quickshell.execDetached(["omarchy-shell", "omarchy.network", "toggle"])
    else if (kind === "weather") Quickshell.execDetached(["omarchy-shell", "widgets", "toggleDashboard"])
    else if (kind === "power") Quickshell.execDetached(["omarchy-shell", "widgets", "togglePower"])
    else if (settings && settings.command) Quickshell.execDetached(["bash", "-c", String(settings.command)])
  }
}
