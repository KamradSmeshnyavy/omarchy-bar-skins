import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

// Палитра бара Cozytile — роли его qtile/config.py из colors.toml текущей темы: tab — тёмные язычки (background),
// body — заливка бара (dark_background), ink — текст и значки (accent), cur — текущий стол (blue), empty — пустой
// стол (background). На темах cozytile-* совпадает с его цветами; на других темах — те же роли из их палитры.
QtObject {
  id: pal
  property var toml: ({})
  property FileView file: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var out = {}
      String(text()).split("\n").forEach(function(l) {
        var m = l.match(/^\s*([a-z_0-9]+)\s*=\s*"(#[0-9a-fA-F]{6,8})"/)
        if (m) out[m[1]] = m[2]
      })
      pal.toml = out
    }
  }
  // смена темы подменяет папку current/theme целиком — слежение за старым colors.toml обрывается; перечитываем по
  // theme.name (он переписывается при каждой смене)
  property FileView themeName: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onFileChanged: { reload(); pal.file.reload(); pal.again.restart() }
  }
  // и ещё раз чуть позже — если theme.name записан раньше, чем скопирована папка темы
  property Timer again: Timer { interval: 900; onTriggered: pal.file.reload() }
  function pick(k, fallback) { return toml[k] ? Qt.color(toml[k]) : fallback }
  readonly property color tab: pick("background", Commons.Color.background)
  readonly property color body: pick("dark_background", Qt.lighter(Commons.Color.background, 1.25))
  readonly property color ink: pick("accent", Commons.Color.accent)
  readonly property color cur: pick("blue", Commons.Color.foreground)
  readonly property color empty: tab
  readonly property color slash: Qt.rgba(tab.r, tab.g, tab.b, 0.9)
  readonly property string font: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
}
