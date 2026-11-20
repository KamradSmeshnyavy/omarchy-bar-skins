import QtQuick
import Quickshell
import Quickshell.Io
import "modules" as Mods

// Активный райс для «одёжки» модулей (RiceDress.qml): id райса — "rice" в ~/.config/omarchy/style.json (пишет вкладка
// «Райсы» Customizer), без него — id стиля, если это стиль райса (liquid — Vitreus). Модуль, нарисованный для этого
// райса (свой QML из modules/ с его префиксом), — «свой» и остаётся как есть; любой другой — стоковый, чужой плагин,
// свой общий (RunCat, FocusTimer…) — надевает облик райса: на Bruteon становится плиткой, на Rumda — карточкой и т. д.
// Выключить у одного модуля — settings.riceStyle: false в shell.json; у всех — "riceModules": false в bar-skin.json.
QtObject {
  id: look

  readonly property string path: Quickshell.env("HOME") + "/.config/omarchy/style.json"
  property var raw: ({})
  readonly property var rices: ["vitreus", "glyph", "yami", "rumda", "surface", "cozytile", "bruteon", "unit3", "space", "crt", "modern", "dotmatrix"]
  readonly property string rice: {
    var r = String(raw.rice || "")
    if (rices.indexOf(r) !== -1) return r
    var id = String(raw.id || "")
    if (id === "liquid") return "vitreus"
    return rices.indexOf(id) !== -1 ? id : ""
  }

  // Свои модули райса: префиксы имён файлов в modules/ и id плагинов, которые райс рисует сам.
  readonly property var ownFiles: ({
    bruteon: ["Brute"], unit3: ["Unit3"], space: ["Space"], crt: ["Crt"], modern: ["Modern"], cozytile: ["Cozy"], rumda: ["Rumda"], surface: ["Surf", "Taskbar"],
    yami: ["Yami"], vitreus: ["Vit"], glyph: ["Glyph"],
    dotmatrix: ["DotMatrix", "DotClock", "ActiveAppIcon", "BatteryGauge", "PrivacyLed", "CavaDots", "CpuRamRings"]
  })
  readonly property var ownIds: ({
    dotmatrix: ["kamradsmeshnyavy.tray", "kamradsmeshnyavy.network", "kamradsmeshnyavy.bluetooth",
      "kamradsmeshnyavy.audio", "kamradsmeshnyavy.monitor", "kamradsmeshnyavy.agents"]
  })

  // name — id модуля (BarModel.entryId), source — путь QML своего модуля ("" у стоковых и плагинов).
  function isOwn(name, source) {
    // столы и распорку рисует сам скин (SkinWorkspaces, пустое место)
    if (name === "omarchy.workspaces" || name === "omarchy.spacer") return true
    var ids = ownIds[rice] || []
    if (ids.indexOf(name) !== -1) return true
    var file = String(source || "").split("/").pop()
    if (file === "") return false
    var pre = ownFiles[rice] || []
    for (var i = 0; i < pre.length; i++) if (file.indexOf(pre[i]) === 0) return true
    return false
  }
  // Модуль, нарисованный для какого-нибудь райса (его modules/<Префикс>*.qml), — у него свои подложки и цвета:
  // на чужом райсе он получает только подложку, без перекраски (иначе ricetint заливает плитки целиком).
  function riceFile(source) {
    var file = String(source || "").split("/").pop()
    if (file === "") return false
    for (var r in ownFiles) {
      var pre = ownFiles[r]
      for (var i = 0; i < pre.length; i++) if (file.indexOf(pre[i]) === 0) return true
    }
    return false
  }
  function dresses(name, source, settings) {
    if (rice === "") return false
    if (settings && settings.riceStyle === false) return false
    return !isOwn(name, source)
  }

  // Материал панелей (как BarStyle в kamradsmeshnyavy.widgets): liquid — стекло Vitreus, base — основа темы (пластик:
  // retro, doodle, proxy, milk, paper). Карточки стоковых панелей модулей одевает PopDress.qml.
  readonly property string material: String(raw.material || "")
  readonly property bool liquid: material === "liquid"
  readonly property string base: liquid && raw.base ? String(raw.base) : "glass"
  readonly property bool plastic: liquid && ["retro", "doodle", "proxy", "milk", "paper", "uwu"].indexOf(base) !== -1
  readonly property bool glass: liquid && !plastic
  readonly property real squareness: ({ retro: 1, doodle: 1, proxy: 1, cyber: 1, paper: 0.6 })[base] || 0
  readonly property real motion: { var m = Number(raw.motion); return isFinite(m) ? Math.max(0, m) : 1 }
  // «капля» (panel-shadow.json panelAppear — выбор пользователя, auto — style.json appear, у liquid — drip)
  property var shade: ({})
  readonly property string appear: ["drip", "classic"].indexOf(String(shade.panelAppear)) !== -1 ? String(shade.panelAppear)
    : ["drip", "classic"].indexOf(String(raw.appear)) !== -1 ? String(raw.appear) : (liquid ? "drip" : "classic")
  readonly property bool drip: appear === "drip" && motion > 0
  property FileView shadeFile: FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/panel-shadow.json"
    watchChanges: true
    printErrors: false
    onLoaded: { try { look.shade = JSON.parse(text() || "{}") || {} } catch (e) { look.shade = {} } }
    onLoadFailed: look.shade = {}
    onFileChanged: reload()
  }

  // палитра Cozytile (роли из colors.toml темы) — одна на бар, её берут все одетые модули
  readonly property var cozy: cozyPal
  property Mods.CozyPal cozyPal: Mods.CozyPal {}

  property FileView file: FileView {
    path: look.path
    watchChanges: true
    printErrors: false
    onLoaded: { try { look.raw = JSON.parse(text() || "{}") || {} } catch (e) { look.raw = {} } }
    onLoadFailed: look.raw = {}
    // style.json пишется на месте — text() в сигнале ещё старый
    onFileChanged: reload()
  }
}
