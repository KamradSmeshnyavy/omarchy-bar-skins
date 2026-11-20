import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "BarModel.js" as BarModel

Item {
  id: root

  // The omarchy-shell host injects omarchyPath from OMARCHY_PATH.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  // Injected by the host shell so bar slots can resolve enabled widgets.
  property var barWidgetRegistry: fallbackBarWidgetRegistry
  // Read-only registry view for third-party full bars; the built-in bar does
  // not otherwise need it, but declaring it keeps clone construction atomic.
  property var pluginRegistry: null
  // Injected by the host shell every time shell.json is reloaded. Holds the
  // `bar:` subtree: position, centerAnchor, layout. The host owns file IO;
  // the bar just renders whatever it's handed. The bar font follows the
  // OS-level fontconfig monospace binding — it is not stored in shell.json.
  property var barConfig: ({})
  // Injected by the host shell. Used for shell-wide actions such as opening
  // settings and persisting inline widget state.
  property var shell: null
  // Manifest for the active bar option. Present for custom bars and useful for
  // diagnostics; the built-in bar does not otherwise need it.
  property var manifest: null
  QtObject {
    id: fallbackBarWidgetRegistry
    property var widgets: ({})
    property int revision: 0
    function metadataFor(id) { return null }
  }
  // Mirrors the on-disk `bar-off` flag so the user can hide the bar without
  // killing the entire shell. Hidden panels stay mapped but park off-screen
  // without an exclusion zone; updated by the FileView watcher further down.
  property bool barHidden: false
  property string home: Quickshell.env("HOME")
  property string stateHome: home + "/.local/state"
  property string omarchyConfigDir: home + "/.config/omarchy"
  property var fallbackBarConfig: ({
    position: "top",
    transparent: false,
    centerAnchor: "omarchy.clock",
    layout: { left: [], center: [], right: [] }
  })
  property var layoutConfig: fallbackBarConfig.layout
  property string centerAnchor: ""
  property bool requestedTransparent: false
  property bool useTransparentForeground: false
  property bool transparent: false
  property bool centerSectionHovered: false
  // One bar surface exists per monitor and each reports into this count, so a
  // pointer crossing from one monitor's bar to another's stays counted however
  // the enter and leave interleave. A single shared bool would be left false by
  // whichever event landed last.
  property int barHoverCount: 0
  // True while the pointer is over any bar, widgets included.
  readonly property bool barHovered: barHoverCount > 0
  property bool centerSectionRevealHeld: false
  property bool centerHoverRevealSuppressed: false
  property int barConfigSerial: 0
  property string position: "top"
  // Resolves through fontconfig at paint time (Style.font.family defaults
  // to "monospace"), so changing the system font (via `omarchy-font-set`)
  // updates the bar without a reload.
  // skin: шрифт, цвета и размер берутся из BarSkin (bar-skin.json), фолбэк — сток.
  property string fontFamily: skin.font !== "" ? skin.font : Style.font.family
  // Bound to the central Color singleton so the bar tracks shell.toml's
  // [bar] section. Property names kept for the rest of this file's bindings.
  property color themeForeground: skin.textColor
  property color themeContrastForeground: Commons.Color.background
  property color transparentForeground: skin.textColor
  property color foreground: themeForeground
  // skin: явный цвет текста скина сильнее подобранного под обои (стоковый transparent).
  property color barForeground: useTransparentForeground && !skin.hasCustomText ? transparentForeground : themeForeground
  property bool foregroundAnimationEnabled: true
  property color background: skin.backgroundColor
  property color urgent: skin.activeColor

  // skin: внешний вид бара, см. BarSkin.qml / SkinFrame.qml.
  BarSkin {
    id: barSkin
    vertical: root.vertical
    position: root.position
  }
  readonly property var skin: barSkin
  // skin: активный райс — чужие модули надевают его облик (RiceLook.qml, RiceDress.qml в ModuleSlot).
  RiceLook { id: riceLookObj }
  readonly property var riceLook: riceLookObj

  // skin: compact — бар сжимается, когда на workspace одно окно / полноэкранное /
  // всегда (skin.compactMode). Решается на каждый монитор в BarPanel.
  property int skinCompactRevision: 0
  // skin: предпросмотр из Customizer (IPC barskin preview): "expanded" — держать бар
  // развёрнутым, чтобы правки формы были видны; "compact" — показать compact; "" — как обычно.
  property string skinPreview: ""
  IpcHandler {
    target: "barskin"
    function preview(mode: string): string {
      root.skinPreview = mode === "expanded" || mode === "compact" ? mode : ""
      return "ok"
    }
  }
  function skinCompactFor(workspace, revision) {
    var mode = root.skin.compactMode
    if (mode === "off") return false
    if (mode === "always") return true
    if (!workspace) return false
    if (mode === "empty") return workspace.toplevels.values.length === 0
    if (workspace.hasFullscreen) return true
    if (mode === "fullscreen") return false
    var list = workspace.toplevels.values
    var tiled = 0
    for (var i = 0; i < list.length; i++) {
      var ipc = list[i].lastIpcObject
      if (!(ipc && ipc.floating === true)) tiled++
    }
    return tiled === 1
  }
  // Ближайший предок-«хозяин» секций (Loader в BarPanel): знает compact и форму своего окна.
  function skinHostOf(item) {
    var p = item
    while (p && p.skinHost !== true) p = p.parent
    return p || null
  }
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var events = ["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode",
        "fullscreen", "workspace", "workspacev2", "focusedmon", "focusedmonv2", "activewindowv2"]
      if (root.skin.compactMode === "off" || events.indexOf(event.name) === -1) return
      skinCompactRefresh.restart()
    }
  }
  Timer {
    id: skinCompactRefresh
    interval: 60
    // floating живёт в lastIpcObject, который сам не обновляется.
    onTriggered: { Hyprland.refreshToplevels(); root.skinCompactRevision++ }
  }

  Behavior on barForeground { enabled: root.foregroundAnimationEnabled; ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on background { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on urgent { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  property var tooltipTarget: null
  property var pendingTooltipTarget: null
  property string tooltipText: ""
  property string pendingTooltipText: ""
  property bool tooltipShown: false
  property int tooltipRequest: 0
  property var activePopout: null
  property var barDragSource: null
  property var barDragTarget: null
  property var barDragTargetGeometry: null
  property bool barDragAfter: false
  property var barDragWindow: null
  property var barDragScreen: null
  property url barDragImageUrl: ""
  property real barDragSceneX: 0
  property real barDragSceneY: 0
  property real barDragScreenX: 0
  property real barDragScreenY: 0
  property real barDragOffsetX: 0
  property real barDragOffsetY: 0
  property bool barMoveActive: false
  property string barMoveCandidate: ""
  property var barMoveWindow: null
  property var barMoveScreen: null
  property var clickTargets: []
  property var moduleSlots: []
  property var pluginBarApis: ({})
  // target -> { target, pluginId, clickTarget, popout }. Keyed by object so a
  // registration edits one entry in place instead of copying and rescanning an
  // array in QML; Qt's Map still finds a key by a native linear scan.
  readonly property var pluginObjectOwners: new Map()
  property bool pluginBarApiSyncQueued: false

  Component {
    id: pluginBarApiComponent
    PluginBarApi { }
  }

  function publicLayoutConfig() {
    return JSON.parse(JSON.stringify(root.layoutConfig || {}))
  }

  function bindPluginBarApi(api) {
    if (!api) return
    api.foreground = Qt.binding(function() { return root.foreground })
    api.barForeground = Qt.binding(function() { return root.barForeground })
    api.background = Qt.binding(function() { return root.background })
    api.urgent = Qt.binding(function() { return root.urgent })
    api.fontFamily = Qt.binding(function() { return root.fontFamily })
    api.position = Qt.binding(function() { return root.position })
    api.vertical = Qt.binding(function() { return root.vertical })
    api.barSize = Qt.binding(function() { return root.barSize })
    api.transparent = Qt.binding(function() { return root.transparent })
    api.foregroundAnimationEnabled = Qt.binding(function() { return root.foregroundAnimationEnabled })
    api.centerSectionRevealHeld = Qt.binding(function() { return root.centerSectionRevealHeld })
    api._centerHoverRevealSuppressed = Qt.binding(function() { return root.centerHoverRevealSuppressed })
    root.syncPluginBarApiObjects(api)
  }

  // Each api keeps its own detached copy of the layout. A flush serialises
  // the layout once and passes the string in so it is not re-serialised for
  // every plugin.
  function syncPluginBarApiObjects(api, layoutSnapshot) {
    if (!api) return
    api.activePopout = root.pluginOwnsBarObject(api.pluginId, root.activePopout)
      ? root.activePopout : (root.activePopout ? api.foreignPopoutMarker : null)
    api.clickTargets = root.pluginClickTargets(api.pluginId)
    api.layoutConfig = layoutSnapshot !== undefined
      ? JSON.parse(layoutSnapshot) : root.publicLayoutConfig()
  }

  function pluginObjectRecord(target) {
    return target ? (pluginObjectOwners.get(target) || null) : null
  }

  function markPluginObject(pluginId, target, role) {
    var key = String(pluginId || "")
    if (!key || !target) return false
    var record = root.pluginObjectRecord(target)
    if (record && record.pluginId !== key) return false
    if (!record) {
      record = { target: target, pluginId: key, clickTarget: false, popout: false }
      pluginObjectOwners.set(target, record)
    }
    record[role] = true
    return true
  }

  function unmarkPluginObject(pluginId, target, role) {
    var key = String(pluginId || "")
    var record = root.pluginObjectRecord(target)
    if (!record || record.pluginId !== key) return
    record[role] = false
    if (!record.clickTarget && !record.popout) pluginObjectOwners.delete(target)
  }

  function pluginOwnsBarObject(pluginId, target) {
    var record = target ? root.pluginObjectRecord(target) : null
    return !!record && record.pluginId === String(pluginId || "")
  }

  function pluginClickTargets(pluginId) {
    var out = []
    for (var i = 0; i < root.clickTargets.length; i++) {
      var target = root.clickTargets[i]
      if (root.pluginOwnsBarObject(pluginId, target)) out.push(target)
    }
    return out
  }

  // Every click target registration, popout change and layout change used to
  // resync every plugin api synchronously. Startup alone is hundreds of
  // registrations, each walking every api and every target, so coalesce them
  // into one resync per event-loop turn (as onModuleSlotsChanged already does
  // for prunePluginBarApis). bindPluginBarApi still syncs a brand-new api
  // directly so a widget never sees an empty api on its first read.
  function schedulePluginBarApiSync() {
    if (pluginBarApiSyncQueued) return
    pluginBarApiSyncQueued = true
    Qt.callLater(root.syncAllPluginBarApiObjects)
  }

  function syncAllPluginBarApiObjects() {
    pluginBarApiSyncQueued = false
    var layoutSnapshot = JSON.stringify(root.layoutConfig || {})
    for (var id in pluginBarApis) {
      var api = pluginBarApis[id]
      if (api) root.syncPluginBarApiObjects(api, layoutSnapshot)
    }
  }

  function registerPluginClickTarget(pluginId, target) {
    if (!root.markPluginObject(pluginId, target, "clickTarget")) return
    root.registerClickTarget(target)
  }

  function unregisterPluginClickTarget(pluginId, target) {
    if (!root.pluginOwnsBarObject(pluginId, target)) return
    root.unregisterClickTarget(target)
    root.unmarkPluginObject(pluginId, target, "clickTarget")
  }

  // A plugin may read api.activePopout right after asking for its popout, so
  // its own api is brought up to date inline; everyone else waits for the
  // coalesced resync.
  function requestPluginPopout(pluginId, owner) {
    if (!root.markPluginObject(pluginId, owner, "popout")) return
    root.popKeyNext = String(pluginId || "")
    root.requestPopout(owner)
    root.popKeyNext = ""
    root.syncPluginBarApiObjects(pluginBarApis[String(pluginId || "")])
  }

  function releasePluginPopout(pluginId, owner) {
    if (!root.pluginOwnsBarObject(pluginId, owner)) return
    root.releasePopout(owner)
    root.unmarkPluginObject(pluginId, owner, "popout")
    root.syncPluginBarApiObjects(pluginBarApis[String(pluginId || "")])
  }

  function pluginBarApiFor(pluginId, moduleName, registered) {
    var key = String(pluginId || "")
    if (!key) return null

    var pluginShell = null
    if (registered && root.shell && typeof root.shell.pluginShellForId === "function") {
      // Only the trusted built-in bar receives ShellRoot and can request a
      // service-capable facade for the widget it is instantiating.
      pluginShell = root.shell.pluginShellForId(moduleName)
    } else if (root.shell && typeof root.shell.pluginShellForBarEntry === "function") {
      // Replacement bars receive a service-less entry facade. Giving an
      // untrusted bar a generic facade factory would let it retrieve another
      // third-party plugin's live service object.
      pluginShell = root.shell.pluginShellForBarEntry(key, moduleName)
    }

    if (pluginBarApis[key]) {
      pluginBarApis[key].shell = pluginShell
      return pluginBarApis[key]
    }

    var api = pluginBarApiComponent.createObject(null, {
      pluginId: key,
      moduleName: String(moduleName || ""),
      shell: pluginShell,
      _showTooltip: function(target, text) { root.showTooltip(target, text) },
      _hideTooltip: function(target) { root.hideTooltip(target) },
      _registerClickTarget: function(target) { root.registerPluginClickTarget(key, target) },
      _unregisterClickTarget: function(target) { root.unregisterPluginClickTarget(key, target) },
      _requestPopout: function(owner) { root.requestPluginPopout(key, owner) },
      _releasePopout: function(owner) { root.releasePluginPopout(key, owner) },
      _notePopoutCard: function(card) { root.notePopoutCard(card) },
      _switchPanelFrom: function(owner, direction) { return root.switchPanelFrom(owner, direction) },
      _targetBelongsToWindow: function(target, window) { return root.targetBelongsToWindow(target, window) },
      _moduleWidgets: function(requestedId) {
        return String(requestedId || "") === String(moduleName || "")
          ? root.moduleWidgets(moduleName) : []
      },
      _run: function(command) { root.run(command) },
      _setCenterHoverRevealSuppressed: function(value) {
        root.centerHoverRevealSuppressed = !!value
      }
    })
    if (!api) return null
    root.bindPluginBarApi(api)

    var next = ({})
    for (var id in pluginBarApis) next[id] = pluginBarApis[id]
    next[key] = api
    pluginBarApis = next
    return api
  }

  function pluginBarApiUsed(pluginId) {
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (slot && slot.pluginApiId === pluginId) return true
    }
    return false
  }

  function releasePluginObjects(pluginId) {
    var owned = Array.from(pluginObjectOwners.values())
    for (var i = 0; i < owned.length; i++) {
      var record = owned[i]
      if (!record || record.pluginId !== pluginId) continue
      if (record.clickTarget) root.unregisterClickTarget(record.target)
      if (record.popout && root.activePopout === record.target) root.releasePopout(record.target)
      pluginObjectOwners.delete(record.target)
    }
  }

  function prunePluginBarApis() {
    var next = ({})
    for (var id in pluginBarApis) {
      var api = pluginBarApis[id]
      if (root.pluginBarApiUsed(id)) {
        next[id] = api
        continue
      }
      root.releasePluginObjects(id)
      if (api && typeof api.destroy === "function") api.destroy()
    }
    pluginBarApis = next
  }

  onActivePopoutChanged: schedulePluginBarApiSync()
  onClickTargetsChanged: schedulePluginBarApiSync()
  onLayoutConfigChanged: schedulePluginBarApiSync()
  onModuleSlotsChanged: Qt.callLater(prunePluginBarApis)

  Component.onDestruction: {
    for (var id in pluginBarApis) {
      root.releasePluginObjects(id)
      if (pluginBarApis[id] && typeof pluginBarApis[id].destroy === "function")
        pluginBarApis[id].destroy()
    }
    pluginBarApis = ({})
  }

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    var next = clickTargets.slice()
    next.push(target)
    clickTargets = next
  }

  function unregisterClickTarget(target) {
    var next = clickTargets.filter(function(item) { return item !== target })
    clickTargets = next
  }

  function registerModuleSlot(slot) {
    if (!slot || moduleSlots.indexOf(slot) !== -1) return
    var next = moduleSlots.slice()
    next.push(slot)
    moduleSlots = next
    requestFlexRefit(slot.skinHostItem)
  }

  function unregisterModuleSlot(slot) {
    var next = moduleSlots.filter(function(item) { return item !== slot })
    moduleSlots = next
    if (slot) requestFlexRefit(slot.skinHostItem)
  }

  // skin: гибкие модули ("flex": true в записи раскладки — например, волны Rumda) сжимаются, когда модулям не хватает
  // длины бара: иначе центр налезает на соседние секции (centerOffset только сдвигает его). Доля flexScale — на
  // каждое окно бара (skinHost); считается не привязкой, а по изменению размеров (Qt.callLater), — без цикла привязок:
  // место под гибкие = длина бара − всё негибкое, и от их собственного размера оно не зависит.
  property var flexHosts: []
  function requestFlexRefit(host) {
    if (!host || flexHosts.indexOf(host) !== -1) return
    flexHosts = flexHosts.concat([host])
    Qt.callLater(root.refitFlex)
  }
  function refitFlex() {
    var hosts = flexHosts
    flexHosts = []
    for (var h = 0; h < hosts.length; h++) {
      var host = hosts[h]
      if (!host) continue
      var lens = { left: 0, center: 0, right: 0 }, counts = { left: 0, center: 0, right: 0 }
      var flexNow = 0, flexNom = 0
      for (var i = 0; i < moduleSlots.length; i++) {
        var s = moduleSlots[i]
        if (!s || s.skinHostItem !== host || !s.visible || lens[s.region] === undefined) continue
        var len = root.vertical ? s.height : s.width
        // гибкий слот, ужатый до нуля, всё равно в счёте — иначе доля прыгает обратно к 1
        if (s.flexible) { flexNow += len; flexNom += s.flexNominal }
        if (len <= 0) continue
        lens[s.region] += len
        counts[s.region] += 1
      }
      if (flexNom <= 0) { if (host.flexScale !== 1) host.flexScale = 1; continue }
      var used = 4 * root.sectionPadding
      for (var r in lens) if (counts[r] > 0) used += lens[r] + root.skin.spacing * (counts[r] - 1)
      var room = (root.vertical ? host.height : host.width) - (used - flexNow)
      var scale = Math.max(0, Math.min(1, room / flexNom))
      if (Math.abs(scale - host.flexScale) > 0.002) host.flexScale = scale
    }
  }

  function debugBarGeometry() {
    var out = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem) continue
      var point = { x: slot.x, y: slot.y }
      try {
        point = slot.mapToItem(null, 0, 0)
      } catch (e) {
      }
      out.push({
        id: slot.moduleName,
        section: slot.region,
        x: Math.round(point.x),
        y: Math.round(point.y),
        width: Math.round(slot.width),
        height: Math.round(slot.height),
        visible: slot.visible === true && slot.width > 0 && slot.height > 0,
        itemVisible: slot.activeItem.visible === true,
        itemWidth: Math.round(slot.activeItem.implicitWidth || 0),
        itemHeight: Math.round(slot.activeItem.implicitHeight || 0)
      })
    }
    return out
  }

  // Геометрия бара для панелей (widgets/BarGeom.qml — дашборд, Quick и др. растут из своей кнопки, как у Vitreus):
  // $XDG_RUNTIME_DIR/omarchy-bar-geom.json — край, толщина, рамка, где кнопки модулей по экранам (px окна бара; где окно
  // на экране, BarGeom знает от Hyprland). Пишется раз в 1.5 с, и только когда что-то сдвинулось.
  property string geomText: ""
  function exportGeometry() {
    var mods = {}
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem || !slot.visible || slot.width <= 0 || slot.height <= 0) continue
      var win = targetWindow(slot)
      var scr = win && win.screen ? win.screen.name : ""
      var p
      try { p = slot.mapToItem(null, 0, 0) } catch (e) { continue }
      if (!mods[scr]) mods[scr] = {}
      mods[scr][slot.moduleName] = [Math.round(p.x), Math.round(p.y), Math.round(slot.width), Math.round(slot.height)]
    }
    var t = JSON.stringify({
      position: root.position, barSize: root.barSize, hidden: root.barHidden === true,
      shape: String(skin.value("shape")), framed: skin.framed === true, frameWidth: skin.frameWidth, frameRadius: skin.frameRadius,
      vitreus: skin.vitreus, tabs: skin.value("tabs") === true, modules: mods
    })
    if (t === geomText) return
    geomText = t
    geomFile.setText(t + "\n")
  }
  FileView {
    id: geomFile
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-bar-geom.json"
    printErrors: false
  }
  Timer { interval: 1500; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.exportGeometry() }

  function targetWindow(target) {
    return target && target.QsWindow ? target.QsWindow.window : null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && targetWindow(target) === window
  }

  function slotWindow(slot) {
    if (!slot) return null
    return targetWindow(slot.activeItem) || targetWindow(slot)
  }

  function sameWindow(left, right) {
    if (!left || !right) return false
    if (left === right) return true
    return !!left.screen && !!right.screen && !!left.screen.name && !!right.screen.name && left.screen.name === right.screen.name
  }

  function targetTooltipHovered(target) {
    return !!target && target.visible !== false && target.opacity !== 0 && target.tooltipHovered === true
  }

  function clearTooltip() {
    tooltipTimer.stop()
    pendingTooltipTarget = null
    pendingTooltipText = ""
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
  }

  function clearBarDrag() {
    barDragSource = null
    barDragWindow = null
    barDragScreen = null
    barDragImageUrl = ""
    barDragTarget = null
    barDragTargetGeometry = null
    barDragAfter = false
    barDragSceneX = 0
    barDragSceneY = 0
    barDragScreenX = 0
    barDragScreenY = 0
    barDragOffsetX = 0
    barDragOffsetY = 0
  }

  function windowScreenPoint(scenePoint, window) {
    var x = scenePoint ? scenePoint.x : 0
    var y = scenePoint ? scenePoint.y : 0
    if (!window || !window.screen) return { x: x, y: y }

    if (root.position === "bottom")
      y += Math.max(0, window.screen.height - window.height)
    else if (root.position === "right")
      x += Math.max(0, window.screen.width - window.width)

    return { x: x, y: y }
  }

  function barDragScreenPoint(scenePoint) {
    return windowScreenPoint(scenePoint, barDragWindow)
  }

  function dropMarkerRect(slot, after) {
    if (!slot) return null

    try {
      var slotPoint = slot.mapToItem(null, 0, 0)
      var screenPoint = barDragScreenPoint(slotPoint)
      var thickness = Style.spacing.xs
      if (vertical) {
        return {
          x: screenPoint.x,
          y: screenPoint.y + (after ? slot.height : 0) - thickness / 2,
          width: slot.width,
          height: thickness
        }
      }

      return {
        x: screenPoint.x + (after ? slot.width : 0) - thickness / 2,
        y: screenPoint.y,
        width: thickness,
        height: slot.height
      }
    } catch (e) {
      return null
    }
  }

  // Split the screen along its diagonals (in normalized space, so widescreens
  // don't bias toward left/right): whichever triangle holds the cursor names
  // the candidate edge.
  function nearestScreenEdge(point, screen) {
    var nx = screen.width > 0 ? Util.clamp(point.x / screen.width, 0, 1) : 0.5
    var ny = screen.height > 0 ? Util.clamp(point.y / screen.height, 0, 1) : 0.5

    var edge = "top"
    var best = ny
    if (1 - ny < best) { edge = "bottom"; best = 1 - ny }
    if (nx < best) { edge = "left"; best = nx }
    if (1 - nx < best) { edge = "right"; best = 1 - nx }
    return edge
  }

  function beginBarMove(window) {
    barMoveWindow = window
    barMoveScreen = window ? window.screen : null
    barMoveCandidate = position
    barMoveActive = true
  }

  function updateBarMove(screenPoint) {
    if (!barMoveActive || !barMoveScreen) return
    barMoveCandidate = nearestScreenEdge(screenPoint, barMoveScreen)
  }

  function clearBarMove() {
    barMoveActive = false
    barMoveCandidate = ""
    barMoveWindow = null
    barMoveScreen = null
  }

  function finishBarMove() {
    var edge = barMoveCandidate
    if (!barMoveActive || !edge || edge === position) {
      clearBarMove()
      return
    }

    clearBarMove()
    setBarPosition(edge)
  }

  function setBarPosition(value) {
    var next = normalizePosition(value)
    if (root.shell && typeof root.shell.mutateShellConfig === "function") {
      root.shell.mutateShellConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.position = next
      })
    } else {
      root.position = next
    }
  }

  function captureBarDragGhost(slot) {
    var item = slot && slot.activeItem ? slot.activeItem : null
    barDragImageUrl = ""
    if (!item || typeof item.grabToImage !== "function") return

    var grabWidth = Math.max(1, Math.ceil(item.width || item.implicitWidth || slot.width || 1))
    var grabHeight = Math.max(1, Math.ceil(item.height || item.implicitHeight || slot.height || 1))
    item.grabToImage(function(result) {
      if (root.barDragSource !== slot || !result || !result.url) return
      root.barDragImageUrl = result.url
    }, Qt.size(grabWidth, grabHeight))
  }

  // ── Модули на рабочем столе (как у Vitreus: любой элемент бара можно вытащить на стол) ──
  // Модуль, отпущенный дальше 60 px от бара, уходит из раскладки (shell.json) на стол — карточкой в окне BarDeskPanel
  // (слой Bottom, под окнами). Карточку тянут куда угодно; у кромки рамки / бара она встаёт вплотную и сливается;
  // принесённая к бару — возвращается в раскладку (в ту треть бара, напротив которой отпущена).
  // ~/.config/omarchy/bar-desk.json: { items: [{ entry, screen, x, y }] } — x, y — левый верхний угол, px экрана.
  property var deskItems: []
  property var deskSpots: ({})          // экран → места стыков карточек с рамкой (их стирает ScreenBorder)
  FileView {
    id: deskFile
    path: Quickshell.env("HOME") + "/.config/omarchy/bar-desk.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { var d = JSON.parse(text()); root.deskItems = Array.isArray(d.items) ? d.items : [] } catch (e) { root.deskItems = [] }
    }
    onLoadFailed: root.deskItems = []
  }
  function saveDesk(items) {
    root.deskItems = items
    deskFile.setText(JSON.stringify({ items: items }, null, 2) + "\n")
  }
  function setDeskSpots(screenName, spots) {
    var o = Object.assign({}, root.deskSpots)
    o[screenName] = spots
    root.deskSpots = o
  }
  // внутренняя кромка бара на экране этой ширины / высоты
  function barInnerEdge(w, h) {
    return position === "left" || position === "top" ? barSize : position === "right" ? w - barSize : h - barSize
  }
  // модуль, который несут на стол: { slot, screen, x, y, image } (x, y — курсор, px экрана)
  property var carry: null
  property string carryImage: ""
  onBarDragImageUrlChanged: if (barDragImageUrl) carryImage = String(barDragImageUrl)
  function dropCarry(x, y) {
    var c = root.carry
    root.carry = null
    if (!c || !c.slot) return
    var scr = null, ss = Quickshell.screens
    for (var i = 0; i < ss.length; i++) if (String(ss[i].name) === c.screen) scr = ss[i]
    if (!scr) return
    var inner = root.barInnerEdge(scr.width, scr.height)
    var away = root.position === "left" ? x - inner : root.position === "right" ? inner - x
      : root.position === "top" ? y - inner : inner - y
    if (away > 60) root.detachModule(c.slot, x - c.slot.width / 2 - 8, y - c.slot.height / 2 - 8, c.screen)
  }
  property var pendingDrop: null
  function finishBarDrag(slot, targetSlot, afterTarget) {
    var scr = root.targetWindow(slot) ? root.targetWindow(slot).screen : null
    pendingDrop = { slot: slot, target: targetSlot, after: afterTarget, screen: scr }
    if (!cursorProbe.running) cursorProbe.running = true
  }
  // позиция курсора в px экрана монитора (hyprctl cursorpos — глобальная)
  function localCursor(o, scr) {
    var m = Hyprland.monitors.values, mx = 0, my = 0
    for (var i = 0; i < m.length; i++)
      if (scr && m[i].name === scr.name && m[i].lastIpcObject) { mx = m[i].lastIpcObject.x || 0; my = m[i].lastIpcObject.y || 0 }
    return { x: Number(o.x) - mx, y: Number(o.y) - my }
  }
  Process {
    id: cursorProbe
    command: ["hyprctl", "cursorpos", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        var d = root.pendingDrop
        root.pendingDrop = null
        if (!d || !d.slot) return
        var away = -1, p = null
        try {
          p = root.localCursor(JSON.parse(text), d.screen)
          if (d.screen) {
            var inner = root.barInnerEdge(d.screen.width, d.screen.height)
            away = root.position === "left" ? p.x - inner : root.position === "right" ? inner - p.x
              : root.position === "top" ? p.y - inner : inner - p.y
          }
        } catch (e) {}
        // курсор ещё в баре — перестановка; ушёл за край — «несём» модуль: дальше его ведёт окно стола (BarDeskPanel)
        if (away > 0 && d.screen) root.carry = { slot: d.slot, screen: String(d.screen.name), x: p.x, y: p.y, image: root.carryImage }
        else if (d.target) root.dropBarModuleAtTarget(d.slot, d.target, d.after)
      }
    }
  }

  function detachModule(slot, sx, sy, screenName) {
    if (!slot || !slot.region || slot.commandCustom || !root.shell || typeof root.shell.mutateShellConfig !== "function") return false
    // mutateShellConfig может выполнить правку позже — запись модуля берём из слота, а не из правки
    var taken = JSON.parse(JSON.stringify(slot.entry))
    var region = slot.region, name = slot.moduleName
    root.shell.mutateShellConfig(function(config) {
      var list = rawLayoutSection(config, region)
      var i = rawEntryIndex(list, name)
      if (i >= 0) list.splice(i, 1)
    })
    var items = root.deskItems.slice()
    items.push({ entry: taken, screen: screenName, x: Math.round(sx), y: Math.round(sy) })
    saveDesk(items)
    return true
  }
  function dockDeskItem(index, along, length) {
    var it = root.deskItems[index]
    if (!it || !root.shell || typeof root.shell.mutateShellConfig !== "function") return
    it = JSON.parse(JSON.stringify(it))
    var region = along < length / 3 ? "left" : along > 2 * length / 3 ? "right" : "center"
    root.shell.mutateShellConfig(function(config) {
      var list = rawLayoutSection(config, region)
      if (region === "left") list.push(it.entry)
      else list.splice(region === "right" ? 0 : list.length, 0, it.entry)
    })
    var items = root.deskItems.slice()
    items.splice(index, 1)
    saveDesk(items)
  }
  function moveDeskItem(index, x, y) {
    var items = root.deskItems.slice()
    if (!items[index]) return
    items[index] = Object.assign({}, items[index], { x: Math.round(x), y: Math.round(y) })
    saveDesk(items)
  }

  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
    popCard = null
    var key = popKeyNext || String(owner).replace(/(_QML(TYPE)?_\d+)?\(.*$/, "")
    Qt.callLater(function() { root.attachPopTab(owner, key) })
  }

  // ── Язычок на карточке панели модуля: за него карточку тянут по столу ──
  // Карточку рисует стоковый KeyboardPanel (qs.Ui); владелец панели (owner из requestPopout) держит его в data. Язычок
  // создаётся прямо в карточке (в окне панели: клик по нему не считается кликом мимо). Тянут — карточка уезжает
  // (её x / y отвязываются от места у бара), мост к бару прячется; панель закрылась — место снова у бара.
  property var popDetached: null
  property string popKeyNext: ""
  // где стоят утащенные панели: ~/.config/omarchy/pop-places.json { ключ модуля: { screen, x, y, edge } } —
  // следующее открытие панели сразу там; двойной клик по язычку возвращает её к бару (место забывается)
  property var popPlaces: ({})
  FileView {
    id: popPlacesFile
    path: Quickshell.env("HOME") + "/.config/omarchy/pop-places.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { var d = JSON.parse(text()); root.popPlaces = d && typeof d === "object" ? d : {} } catch (e) { root.popPlaces = {} } }
    onLoadFailed: root.popPlaces = {}
  }
  function savePopPlace(key, place) {
    if (!key) return
    var o = Object.assign({}, root.popPlaces)
    if (place) o[key] = place
    else delete o[key]
    root.popPlaces = o
    popPlacesFile.setText(JSON.stringify(o, null, 2) + "\n")
  }
  function findIn(obj, test, depth) {
    if (!obj || depth > 4) return null
    if (test(obj)) return obj
    var lists = [obj.data, obj.children, obj.contentItem ? [obj.contentItem] : []]
    for (var l = 0; l < lists.length; l++) {
      var list = lists[l]
      if (!list) continue
      for (var i = 0; i < list.length; i++) {
        var r = findIn(list[i], test, depth + 1)
        if (r) return r
      }
    }
    return null
  }
  function attachPopTab(owner, key) {
    if (!owner || root.activePopout !== owner) return
    var kp = findIn(owner, function(o) { return o !== owner && o.cardOrigin !== undefined && o.anchorItem !== undefined && o.contentItem !== undefined }, 0)
    if (!kp) { attachPopupTab(owner, key); return }
    var card = findIn(kp, function(o) { return o !== kp && o.borderSpec !== undefined && o.contentTopInset !== undefined && o.width > 0 }, 0)
    if (!card) return
    // стеклянные основы Vitreus: карточка — жидкое стекло одним куском с баром, «капля» из кнопки (PopDress.qml)
    // (contentItem у KeyboardPanel — его содержимое, а не корень окна: одёжку кладём рядом с карточкой)
    var host = card.parent
    if ((root.riceLook.glass || (root.riceLook.liquid && root.riceLook.base === "uwu")) && host && host.children) {
      var dressed = false
      for (var di = 0; di < host.children.length; di++) if (host.children[di].objectName === "omarchyPopDress") dressed = true
      if (!dressed) popDressComponent.createObject(host, { kp: kp, card: card, bar: root, owner: owner })
    }
    for (var i = 0; i < card.children.length; i++) if (card.children[i].objectName === "omarchyPopTab") return
    // ключ места — имя модуля бара, у которого открыта панель (слот над anchorItem), иначе плагин / тип владельца
    for (var a = kp.anchorItem, n = 0; a && n < 12; a = a.parent, n++)
      if (typeof a.moduleName === "string" && a.moduleName) { key = a.moduleName; break }
    var tab = popTabComponent.createObject(card, { kp: kp, card: card, owner: owner, key: key || "" })
    var p = key ? root.popPlaces[key] : null
    if (tab && p && kp.screen && p.screen === String(kp.screen.name)) tab.placeAt(p)
  }
  // Меню-всплывашки (PopupCard из qs.Ui: меню трея, календарь, погода…) — это xdg-popup бара, они сами не сообщают,
  // где карточка. Её место — прямоугольник якоря в окне бара (оно во весь экран, т. е. это px экрана) и размер окна.
  // Язычок тот же: тянут — окно меню переезжает (якорь переставляется после расчёта самого PopupCard), у кромки
  // рамки / бара прилипает и сливается мостом, место запоминается (pop-places.json).
  function attachPopupTab(owner, key) {
    function isPc(o) { return o.triggerMode !== undefined && o.anchorItem !== undefined && o.popupScreen !== undefined && o.anchor !== undefined }
    // у владельца может быть несколько меню (у трея — меню значка и управление значками): берём открытое
    var pc = isPc(owner) && owner.open ? owner : findIn(owner, function(o) { return o !== owner && isPc(o) && o.open === true }, 0)
    if (!pc) return
    // contentItem у PopupCard переопределён (список содержимого) — карточку ищем от самого окна
    var card = findIn(pc, function(o) { return o !== pc && o.borderSpec !== undefined && o.contentTopInset !== undefined }, 0)
    if (!card) return
    for (var i = 0; i < card.children.length; i++) if (card.children[i].objectName === "omarchyPopTab") return
    for (var a = pc.anchorItem, n = 0; a && n < 12; a = a.parent, n++)
      if (typeof a.moduleName === "string" && a.moduleName) { key = a.moduleName; break }
    var tab = popupTabComponent.createObject(card, { pc: pc, card: card, owner: owner, key: key || "" })
    var p = key ? root.popPlaces[key] : null
    if (tab && p && pc.popupScreen && p.screen === String(pc.popupScreen.name)) tab.placeAt(p)
    else if (tab) tab.publish()
  }
  Component {
    id: popupTabComponent
    Item {
      id: ptab
      objectName: "omarchyPopTab"
      property var pc
      property var card
      property var owner
      property string key: ""
      property bool placed: false          // стоит на своём месте (утащен), а не у кнопки
      property point at: Qt.point(0, 0)    // левый верхний угол окна меню, px экрана
      property string edge: ""
      readonly property real sw: pc && pc.popupScreen ? pc.popupScreen.width : 1440
      readonly property real sh: pc && pc.popupScreen ? pc.popupScreen.height : 900
      readonly property real pw: pc ? pc.implicitWidth : 0
      readonly property real ph: pc ? pc.implicitHeight : 0
      readonly property color accent: Commons.Color.accent
      readonly property color line: root.skin.borderWidth > 0 ? root.skin.borderColor : Commons.Color.popups.border
      x: grip ? ((card ? card.width : 0) - width) / 2 : 24; y: 2
      width: grip ? 64 : 78; height: 14
      z: 100
      function inset(e) { return e === root.position ? root.barSize : root.skin.framed ? root.skin.frameWidth : 0 }
      // сообщить мосту, где карточка (у кнопки — где её поставил PopupCard)
      function publish() {
        if (!pc || !pc.open) return
        var r = placed ? Qt.rect(at.x, at.y, pw, ph) : Qt.rect(pc.anchor.rect.x, pc.anchor.rect.y, pw, ph)
        root.popCard = { screen: pc.popupScreen ? String(pc.popupScreen.name) : "", x: r.x, y: r.y, width: r.width, height: r.height, edge: placed ? edge : "" }
        if (placed && !edge) root.popCard = null
      }
      function moveTo(p) {
        at = Qt.point(Math.max(0, Math.min(sw - pw, p.x)), Math.max(0, Math.min(sh - ph, p.y)))
        if (!pdrag.active) remap()
      }
      // показанный xdg-popup Hyprland не переставляет — окно меню показывается заново (якорь пересчитает PopupCard,
      // а Connections ниже поставит его на at)
      function remap() {
        if (!pc || !pc.open) return
        if (placed) { pc.anchor.rect.x = Math.round(at.x); pc.anchor.rect.y = Math.round(at.y) }
        var c = card
        pc.visible = false
        Qt.callLater(function() { if (pc) pc.visible = Qt.binding(function() { return pc.open || c.opacity > 0 }) })
      }
      function snapTo(best) {
        var p = at
        if (best === "left") p = Qt.point(inset("left") + 6, p.y)
        else if (best === "right") p = Qt.point(sw - inset("right") - pw - 6, p.y)
        else if (best === "top") p = Qt.point(p.x, inset("top") + 6)
        else if (best === "bottom") p = Qt.point(p.x, sh - inset("bottom") - ph - 6)
        edge = best
        moveTo(p)
      }
      function placeAt(p) {
        placed = true
        root.popDetached = owner
        at = Qt.point(Number(p.x) || 0, Number(p.y) || 0)
        snapTo(p.edge ? String(p.edge) : "")
        publish()
      }
      function finish() {
        var d = { left: at.x - inset("left"), right: sw - inset("right") - (at.x + pw),
                  top: at.y - inset("top"), bottom: sh - inset("bottom") - (at.y + ph) }
        function ok(e) { return root.mergePopups && (root.skin.framed || e === root.position) }
        var best = "", bd = 32
        for (var e in d) if (ok(e) && Math.abs(d[e]) < bd) { bd = Math.abs(d[e]); best = e }
        snapTo(best)
        publish()
        var sc = pc.popupScreen ? String(pc.popupScreen.name) : ""
        root.savePopPlace(key, { screen: sc, x: Math.round(at.x), y: Math.round(at.y), edge: best })
      }
      Timer { id: follow; interval: 16; repeat: true; onTriggered: if (!probe.running) probe.running = true }
      // пока тянут — по экрану едет контур меню (само окно меню переедет на отпускании)
      LazyLoader {
        active: pdrag.active
        PanelWindow {
          screen: ptab.pc ? ptab.pc.popupScreen : null
          anchors { top: true; bottom: true; left: true; right: true }
          exclusionMode: ExclusionMode.Ignore
          color: "transparent"
          surfaceFormat.opaque: false
          mask: Region {}
          WlrLayershell.layer: WlrLayer.Overlay
          WlrLayershell.namespace: "omarchy-pop-ghost"
          WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
          Rectangle {
            x: ptab.at.x; y: ptab.at.y; width: ptab.pw; height: ptab.ph
            radius: Style.cornerRadius
            color: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 0.55)
            border.width: 2
            border.color: ptab.accent
            Rectangle { x: 24; y: 2; width: 78; height: 11; radius: 5; color: ptab.accent }
          }
        }
      }
      Process {
        id: probe
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
          onStreamFinished: {
            if (!pdrag.active) return
            try {
              var c = JSON.parse(text), sc = ptab.pc.popupScreen
              ptab.moveTo(Qt.point(c.x - (sc ? sc.x : 0) - pdrag.grab.x, c.y - (sc ? sc.y : 0) - pdrag.grab.y))
            } catch (e) {}
          }
        }
      }
      function home() {
        placed = false
        edge = ""
        if (root.popDetached === owner) root.popDetached = null
        remap()
      }
      // PopupCard пересчитывает якорь при каждом показе / смене размера — утащенное меню возвращаем на его место
      Connections {
        target: ptab.pc ? ptab.pc.anchor : null
        function onAnchoring() {
          if (ptab.placed) { ptab.pc.anchor.rect.x = Math.round(ptab.at.x); ptab.pc.anchor.rect.y = Math.round(ptab.at.y) }
          Qt.callLater(ptab.publish)
        }
      }
      Connections {
        target: ptab.pc
        function onImplicitHeightChanged() { if (ptab.placed && ptab.edge) ptab.snapTo(ptab.edge); Qt.callLater(ptab.publish) }
        function onOpenChanged() {
          if (ptab.pc.open) return
          if (root.popDetached === ptab.owner) root.popDetached = null
          ptab.destroy()
        }
      }
      // язычок внутри карточки у верхней кромки (xdg-popup не рисует за своими краями); у Vitreus (кроме Retro) —
      // тонкая ручка по центру, как у его карточек
      readonly property bool grip: root.riceLook.liquid && root.riceLook.base !== "retro"
      Rectangle {
        visible: ptab.grip
        anchors.centerIn: parent
        width: 40; height: 4; radius: 2
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.45)
      }
      Item {
        visible: !ptab.grip
        anchors.fill: parent
        Rectangle { anchors.fill: parent; radius: 5; color: Qt.darker(ptab.accent, 1.35) }
        Rectangle { width: parent.width; height: parent.height - 3; radius: 5; color: ptab.accent }
        Rectangle { x: 6; y: 2; width: parent.width - 12; height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.55) }
        Rectangle { anchors.fill: parent; radius: 5; color: "transparent"; border.width: 1.2; border.color: ptab.line }
      }
      MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
      Item {
        anchors.fill: parent
        HoverHandler { cursorShape: pdrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
        TapHandler {
          onDoubleTapped: { ptab.home(); root.savePopPlace(ptab.key, null) }
        }
        DragHandler {
          id: pdrag
          target: null
          dragThreshold: 3
          // окно меню едет за курсором: смещение внутри окна ничего не говорит о курсоре на экране (окно уехало
          // вместе с ним), поэтому место берётся из глобального курсора (hyprctl cursorpos), пока держат язычок
          property point grab
          onActiveChanged: {
            if (active) {
              var r = ptab.pc.anchor.rect
              ptab.at = Qt.point(r.x, r.y)
              ptab.placed = true
              ptab.edge = ""
              root.popDetached = ptab.owner
              root.popCard = null
              grab = ptab.card.mapFromItem(null, centroid.scenePressPosition.x, centroid.scenePressPosition.y)
              grab = Qt.point(grab.x + ptab.card.x, grab.y + ptab.card.y)
              follow.start()
              return
            }
            follow.stop()
            ptab.finish()
          }
        }
      }
    }
  }
  Component {
    id: popDressComponent
    PopDress {}
  }
  Component {
    id: popTabComponent
    Item {
      id: tab
      objectName: "omarchyPopTab"
      property var kp
      property var card
      property var owner
      property string key: ""
      // поставить карточку на сохранённое место (сразу при открытии)
      function placeAt(p) {
        // окно панели при открытии ещё может быть не во весь экран — ограничивать по экрану
        var w = kp.screen ? kp.screen.width : kp.width, h = kp.screen ? kp.screen.height : kp.height
        root.popDetached = owner
        card.x = Math.max(0, Math.min(w - card.width, Number(p.x) || 0))
        card.y = Math.max(12, Math.min(h - card.height, Number(p.y) || 0))
        snap(p.edge ? String(p.edge) : "")
      }
      function inset(e) { return e === root.position ? root.barSize : root.skin.framed ? root.skin.frameWidth : 0 }
      // прижать к кромке e (или ни к какой) и сообщить мосту
      function snap(best) {
        var c = card, w = kp.screen ? kp.screen.width : kp.width, h = kp.screen ? kp.screen.height : kp.height
        // стекло Vitreus сливается с кромкой само (PopDress) — вплотную; иначе зазор под мост
        var g = root.riceLook.glass || root.riceLook.base === "uwu" ? 0 : 6
        if (best === "left") c.x = inset("left") + g
        else if (best === "right") c.x = w - inset("right") - c.width - g
        else if (best === "top") c.y = inset("top") + g
        else if (best === "bottom") c.y = h - inset("bottom") - c.height - g
        root.popCard = best ? { screen: kp.screen ? String(kp.screen.name) : "", x: c.x, y: c.y, width: c.width, height: c.height, edge: best } : null
      }
      // высота карточки меняется (список устройств растёт) — у нижней кромки она остаётся прижатой
      Connections {
        target: tab.card
        function onHeightChanged() {
          if (root.popDetached !== tab.owner || !root.popCard || !root.popCard.edge) return
          tab.snap(String(root.popCard.edge))
        }
      }
      readonly property color accent: Commons.Color.accent
      readonly property color line: root.skin.borderWidth > 0 ? root.skin.borderColor : Commons.Color.popups.border
      // у Vitreus (кроме Retro) — тонкая ручка по центру верхней кромки, как у его карточек; иначе литой язычок
      readonly property bool grip: root.riceLook.liquid && root.riceLook.base !== "retro"
      x: grip ? (card.width - width) / 2 : 24; y: grip ? 4 : -11
      width: grip ? 64 : 78; height: grip ? 14 : 24
      z: 100
      Rectangle {
        visible: tab.grip
        anchors.centerIn: parent
        width: 40; height: 4; radius: 2
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, tabHover.hovered ? 0.7 : 0.4)
      }
      // литой язычок: основание темнее, лицо цветом акцента, блик, контур
      Item {
        visible: !tab.grip
        anchors.fill: parent
        Rectangle { x: 2; y: 3; width: parent.width; height: parent.height; radius: 6; color: Qt.rgba(0, 0, 0, 0.28) }
        Rectangle { anchors.fill: parent; radius: 6; color: Qt.darker(tab.accent, 1.35) }
        Rectangle { width: parent.width; height: 19; radius: 6; color: tab.accent }
        Rectangle { x: 6; y: 2; width: parent.width - 12; height: 2.2; radius: 1.1; color: Qt.rgba(1, 1, 1, 0.55) }
        Rectangle { anchors.fill: parent; radius: 6; color: "transparent"; border.width: 1.4; border.color: tab.line }
      }
      // клик по язычку — не «мимо»: не пускать его к закрывающей области окна
      MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
      property point start
      function home() {
        var kp = tab.kp
        tab.card.x = Qt.binding(function() { return kp.morphed(kp.morphFrom.x, kp.cardOrigin.x) })
        tab.card.y = Qt.binding(function() { return kp.morphed(kp.morphFrom.y, kp.cardOrigin.y) })
        if (root.popDetached === tab.owner) root.popDetached = null
      }
      // поверх MouseArea: DragHandler в её родителе нажатия не видит
      Item {
        anchors.fill: parent
        HoverHandler { id: tabHover; cursorShape: tabDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
        // двойной клик — обратно к бару, место забыто
        TapHandler {
          onDoubleTapped: {
            tab.home()
            root.savePopPlace(tab.key, null)
            if (tab.kp && typeof tab.kp.publishCard === "function") Qt.callLater(tab.kp.publishCard)
          }
        }
        DragHandler {
          id: tabDrag
          target: null
          dragThreshold: 3
          onActiveChanged: {
            if (active) {
              tab.start = Qt.point(tab.card.x, tab.card.y)
              root.popDetached = tab.owner
              root.popCard = null
              return
            }
            // отпустили у кромки рамки / бара (ближе 32 px) — вплотную к ней, мост сольёт карточку с ней
            var kp = tab.kp, c = tab.card, w = kp.width, h = kp.height
            function ok(e) { return root.mergePopups && (root.skin.framed || e === root.position) }
            var d = { left: c.x - tab.inset("left"), right: w - tab.inset("right") - (c.x + c.width),
                      top: c.y - tab.inset("top"), bottom: h - tab.inset("bottom") - (c.y + c.height) }
            var best = "", bd = 32
            for (var e in d) if (ok(e) && Math.abs(d[e]) < bd) { bd = Math.abs(d[e]); best = e }
            tab.snap(best)
            root.savePopPlace(tab.key, { screen: kp.screen ? String(kp.screen.name) : "", x: Math.round(c.x), y: Math.round(c.y), edge: best })
          }
          onTranslationChanged: if (active) {
            var w = tab.kp.width, h = tab.kp.height
            tab.card.x = Math.max(0, Math.min(w - tab.card.width, tab.start.x + translation.x))
            tab.card.y = Math.max(12, Math.min(h - tab.card.height, tab.start.y + translation.y))
          }
        }
      }
      // панель закрылась — карточка снова у бара (вернуть привязки KeyboardPanel)
      Connections {
        target: tab.kp
        function onOpenChanged() {
          if (tab.kp.open) return
          tab.home()
          tab.destroy()
        }
      }
    }
  }

  function releasePopout(owner) {
    if (activePopout === owner) { activePopout = null; popCard = null }
  }

  // Карточка открытой панели модуля (KeyboardPanel из qs.Ui сообщает, где она: { screen, x, y, width, height } в px
  // экрана). По ней PopBridge сливает карточку с баром / рамкой (как у Vitreus): мост через зазор, вогнутые углы.
  property var popCard: null
  // карточку утащили за язычок — её место знает язычок, а не KeyboardPanel (тот публикует место у бара)
  function notePopoutCard(card) { if (popDetached === null) popCard = card && activePopout ? card : null }
  // слияние — только у бара во всю длину края (рамка, сплошной); у плавающих пилюль и островов зазор — часть вида
  readonly property bool mergePopups: !transparent && skin.value("mergePopups") !== false
    && ["floating", "pill", "islands", "notches", "notch", "hug"].indexOf(String(skin.value("shape"))) === -1

  readonly property bool vertical: position === "left" || position === "right"
  // skin: отступ секций от краёв подложки; -1 в скине = сток.
  readonly property int sectionPadding: skin.padding >= 0 ? skin.padding : Style.space(8)
  // skin: высота из скина; 0 = токены Style.bar.
  readonly property int barSize: skin.height > 0 ? skin.height : (vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal)

  function normalizePosition(value) {
    return BarModel.normalizePosition(value)
  }

  // Apply tray-pinning on top of the shared layout normalization so the
  // bar host and scriptable config helpers can't drift on entry shape.
  function normalizeLayout(layout) {
    var normalized = Util.normalizeLayout(Util.isPlainObject(layout) ? layout : fallbackBarConfig.layout)
    return {
      left:   pinTrayToInner(normalized.left,   "left"),
      center: pinTrayToInner(normalized.center, "center"),
      right:  pinTrayToInner(normalized.right,  "right")
    }
  }

  // The tray drawer reveals inward (away from the bar edge). Place it at the
  // section's inner edge: start of the right section, end of the left/center
  // sections. The drawer's reserved space then sits next to the bar center,
  // not stranded mid-section.
  function pinTrayToInner(entries, section) {
    return BarModel.pinTrayToInner(entries, section)
  }

  function applyBarConfig() {
    var config = Util.isPlainObject(barConfig) ? barConfig : fallbackBarConfig

    position = normalizePosition(config.position)
    setRequestedTransparency(config.transparent === true)
    centerAnchor = Util.canonicalWidgetId(config.centerAnchor || "")

    // layoutEntries feeds plain JS arrays to the module Repeaters, and QML
    // cannot diff those: reassigning layoutConfig rebuilds every widget on
    // every monitor. When a shell.json write only changed inline widget
    // settings, patch the live layout and running widgets in place instead.
    var next = normalizeLayout(config.layout)
    var delta = BarModel.inlineSettingsDelta(layoutConfig, next)
    if (delta) {
      applySettingsDelta(delta)
      return
    }
    layoutConfig = next
    barConfigSerial++
  }

  function applySettingsDelta(delta) {
    for (var i = 0; i < delta.length; i++) {
      var change = delta[i]
      layoutConfig[change.region][change.index] = change.entry
      var settings = entrySettings(change.entry)
      for (var s = 0; s < moduleSlots.length; s++) {
        var slot = moduleSlots[s]
        if (!slot || slot.region !== change.region || slot.moduleName !== entryId(change.entry)) continue
        var item = slot.activeItem
        if (item && "settings" in item) item.settings = settings
      }
    }
  }

  onBarConfigChanged: applyBarConfig()

  function layoutEntries(region) {
    var serial = barConfigSerial
    var entries = layoutConfig ? layoutConfig[region] : null
    return Array.isArray(entries) ? entries : []
  }

  // Tab order for the panels in one bar region. Scoped to a single bar surface
  // so tabbing walks the bar the open panel belongs to instead of hopping the
  // panel to another monitor's copy of the same widget.
  function panelNavigationSlots(region, window) {
    var entries = layoutEntries(region)
    var slots = []
    for (var i = 0; i < entries.length; i++) {
      var id = entryId(entries[i])
      for (var j = 0; j < moduleSlots.length; j++) {
        var slot = moduleSlots[j]
        if (!slot || slot.region !== region || slot.moduleName !== id) continue
        if (window && !sameWindow(slotWindow(slot), window)) continue
        var item = slot.activeItem
        if (!item || item.visible !== true || slot.visible !== true || slot.width <= 0 || slot.height <= 0) continue
        if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
        slots.push(slot)
        break
      }
    }
    return slots
  }

  // The Nth panel in a bar region, counted the way the bar reads: layout order,
  // and only the panels actually on screen. A widget with no panel (the tray)
  // and one that is hiding itself are passed over, so the number lands on the
  // Nth panel icon the user can see rather than the Nth layout entry.
  // One-based, because it exists for hotkeys; anything else lands on no slot.
  //
  // Counting any bar surface is enough: every monitor lays its bar out from the
  // one layout, and summoning the id routes through pickPanelSlot, which opens
  // the focused monitor's copy whichever surface was counted.
  function panelWidgetIdAt(region, index) {
    var slots = panelNavigationSlots(String(region || ""), null)
    var slot = slots[Math.round(Number(index)) - 1]
    return slot ? String(slot.moduleName || "") : ""
  }

  function switchPanelFrom(owner, direction) {
    if (!owner) return false

    var currentSlot = null
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (slot && slot.activeItem === owner) {
        currentSlot = slot
        break
      }
    }
    if (!currentSlot) return false

    var slots = panelNavigationSlots(currentSlot.region, slotWindow(currentSlot))
    if (slots.length < 2) return false

    var currentIndex = -1
    for (var j = 0; j < slots.length; j++) {
      if (slots[j] === currentSlot) {
        currentIndex = j
        break
      }
    }
    if (currentIndex < 0) return false

    var step = direction < 0 ? -1 : 1
    var nextSlot = slots[(currentIndex + step + slots.length) % slots.length]
    if (!nextSlot || !nextSlot.activeItem || nextSlot.activeItem === owner) return false

    nextSlot.activeItem.open()
    return true
  }

  // Every live instance of a widget id. A bar surface is built per monitor, so
  // a widget that appears once in the layout is still live once per screen.
  function moduleWidgets(pluginId) {
    var id = String(pluginId || "")
    var items = []
    if (!id) return items
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem || slot.moduleName !== id) continue
      items.push(slot.activeItem)
    }
    return items
  }

  function slotScreenName(slot) {
    var window = slotWindow(slot)
    return window && window.screen ? String(window.screen.name || "") : ""
  }

  // The output Hyprland has focused, which is where a keyboard-summoned panel
  // belongs. Empty until Hyprland reports one, which leaves panel routing on
  // its per-monitor fallback rather than guessing at an output.
  function focusedScreenName() {
    var monitor = Hyprland.focusedMonitor
    return monitor ? String(monitor.name || "") : ""
  }

  // Resolve the live bar-widget instance for a plugin id (e.g. "omarchy.bluetooth").
  // Only widgets that expose popup open/close methods count; plain indicators
  // (clock, workspaces, tray) return null. Used by shell.summon/toggle so
  // panel hotkeys route through the bar instead of a per-target IPC handler
  // that only reaches whichever per-monitor instance claimed the target.
  function findPanelWidget(pluginId) {
    var id = String(pluginId || "")
    if (!id) return null
    var candidates = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem) continue
      if (slot.moduleName !== id) continue
      var item = slot.activeItem
      if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
      candidates.push({ slot: slot, screenName: slotScreenName(slot), opened: item.opened === true })
    }
    // One copy per monitor, plus a zero-size placeholder for anchored center
    // modules. See BarModel.pickPanelSlot for which one a hotkey acts on.
    var chosen = BarModel.pickPanelSlot(candidates, focusedScreenName())
    return chosen ? chosen.activeItem : null
  }

  function summonBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.open !== "function") return false
    item.open()
    return true
  }

  function hideBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.close !== "function") return false
    item.close()
    return true
  }

  function isBarWidgetOpen(pluginId) {
    var item = findPanelWidget(pluginId)
    return !!item && item.opened === true
  }

  function entrySettings(entry) {
    return BarModel.entrySettings(entry)
  }

  function entryId(entry) {
    return BarModel.entryId(entry)
  }

  function moduleString(entry, key, fallback) {
    return BarModel.moduleString(entry, key, fallback)
  }

  function entryIndex(entries, name) {
    return BarModel.entryIndex(entries, name)
  }

  function entriesBefore(entries, name) {
    return BarModel.entriesBefore(entries, name)
  }

  function entriesAfter(entries, name) {
    return BarModel.entriesAfter(entries, name)
  }

  function canonicalWidgetId(name) {
    return Util.canonicalWidgetId(name)
  }

  function expandPath(path) {
    return BarModel.expandPath(path, home)
  }

  function customModuleSafeName(name) {
    return BarModel.customModuleSafeName(name)
  }

  function customModuleType(entry) {
    return BarModel.customModuleType(entry)
  }

  function customModuleSource(entry) {
    var source = BarModel.customModulePath(entry, home, omarchyConfigDir)
    return source ? Util.fileUrl(source) : ""
  }

  Component.onCompleted: applyBarConfig()

  // Revealing the indicators widens their section, which can slide a neighbour
  // under a stationary pointer. Collapsing on that un-hover would move it back
  // out and re-open the peek, so hold until the pointer leaves the bar.
  function setCenterSectionHovered(hovered) {
    centerSectionHovered = hovered
    if (hovered) {
      centerSectionRevealTimer.stop()
      centerSectionRevealHeld = true
    } else {
      centerSectionRevealTimer.restart()
    }
  }

  function setBarHovered(hovered) {
    barHoverCount = Math.max(0, barHoverCount + (hovered ? 1 : -1))
    if (barHoverCount === 0) centerSectionRevealTimer.restart()
  }

  function setCenterHoverRevealSuppressed(value) {
    centerHoverRevealSuppressed = !!value
  }

  Timer {
    id: centerSectionRevealTimer
    interval: 120
    // Collapse only. Opening the peek is the center section's own gesture, done
    // in setCenterSectionHovered, so a timer left pending by a pointer that dipped
    // off the bar and came back cannot reveal indicators it never pointed at.
    onTriggered: if (!root.centerSectionHovered && !root.barHovered) root.centerSectionRevealHeld = false
  }

  function run(command) {
    if (!command) return

    Util.execDetached(command)
  }

  function toggleTransparency() {
    var nextTransparent = !(root.requestedTransparent === true)
    if (root.shell && typeof root.shell.mutateShellConfig === "function") {
      root.shell.mutateShellConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.transparent = nextTransparent
      })
    } else {
      root.setRequestedTransparency(nextTransparent)
    }
  }

  function rawLayoutSection(config, region) {
    if (!Util.isPlainObject(config.bar)) config.bar = {}
    if (!Util.isPlainObject(config.bar.layout)) config.bar.layout = {}
    if (!Array.isArray(config.bar.layout[region])) config.bar.layout[region] = []

    return config.bar.layout[region]
  }

  function rawEntryIndex(entries, name) {
    for (var i = 0; i < entries.length; i++) {
      if (root.entryId(entries[i]) === name) return i
    }

    return -1
  }

  function moveModuleInConfig(config, fromRegion, fromName, toRegion, beforeName) {
    var fromEntries = rawLayoutSection(config, fromRegion)
    var toEntries = rawLayoutSection(config, toRegion)
    var fromIndex = rawEntryIndex(fromEntries, fromName)
    if (fromIndex < 0) return false

    var toIndex = beforeName ? rawEntryIndex(toEntries, beforeName) : toEntries.length
    if (toIndex < 0) toIndex = toEntries.length

    if (fromRegion === toRegion && fromIndex === toIndex) return false

    var movedEntry = fromEntries[fromIndex]
    fromEntries.splice(fromIndex, 1)

    if (fromRegion === toRegion && fromIndex < toIndex) toIndex -= 1
    if (toIndex < 0) toIndex = 0
    if (toIndex > toEntries.length) toIndex = toEntries.length
    if (fromRegion === toRegion && fromIndex === toIndex) {
      fromEntries.splice(fromIndex, 0, movedEntry)
      return false
    }

    toEntries.splice(toIndex, 0, movedEntry)
    return true
  }

  function dropBarModule(source, toRegion, beforeName) {
    if (!source || !source.region || !source.moduleName || !toRegion) return false
    if (source.region === toRegion && source.moduleName === beforeName) return false
    if (!root.shell || typeof root.shell.mutateShellConfig !== "function") return false

    var changed = false
    root.shell.mutateShellConfig(function(config) {
      changed = moveModuleInConfig(config, source.region, source.moduleName, toRegion, beforeName)
    })
    return changed
  }

  function moduleDropAtScene(scenePoint, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    if (sourceWindow && sourceWindow.contentItem) {
      var barPoint = sourceWindow.contentItem.mapFromItem(null, scenePoint.x, scenePoint.y)
      if (barPoint.x < 0 || barPoint.x > sourceWindow.contentItem.width ||
          barPoint.y < 0 || barPoint.y > sourceWindow.contentItem.height)
        return null
    }

    var candidates = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || slot === sourceSlot || !slot.visible || slot.width <= 0 || slot.height <= 0) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue

      var slotPoint = { x: slot.x, y: slot.y }
      try {
        slotPoint = slot.mapToItem(null, 0, 0)
      } catch (e) {
      }

      candidates.push({
        slot: slot,
        x: slotPoint.x,
        y: slotPoint.y,
        width: slot.width,
        height: slot.height
      })
    }

    return BarModel.nearestDropTarget(candidates, scenePoint, root.vertical)
  }

  function visibleModuleSlot(region, name, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || slot === sourceSlot || slot.region !== region || slot.moduleName !== name ||
          !slot.visible || slot.width <= 0 || slot.height <= 0) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue
      return slot
    }

    return null
  }

  function nextVisibleModuleName(region, afterName, sourceSlot) {
    var entries = layoutEntries(region)
    var found = false
    for (var i = 0; i < entries.length; i++) {
      var name = entryId(entries[i])
      if (!found) {
        found = name === afterName
        continue
      }

      if (visibleModuleSlot(region, name, sourceSlot)) return name
    }

    return ""
  }

  function dropBarModuleAtTarget(sourceSlot, targetSlot, afterTarget) {
    if (!sourceSlot || !targetSlot) return false

    var beforeName = afterTarget ? nextVisibleModuleName(targetSlot.region, targetSlot.moduleName, sourceSlot) : targetSlot.moduleName
    return dropBarModule(sourceSlot, targetSlot.region, beforeName)
  }

  function moduleTargetClickable(target) {
    return target
      && target.visible !== false
      && target.opacity !== 0
      && target.interactive !== false
      && target.pressable !== false
      && target.concealed !== true
      && typeof target.triggerPress === "function"
  }

  function moduleClickTargetAt(slot, localX, localY) {
    for (var i = clickTargets.length - 1; i >= 0; i--) {
      var target = clickTargets[i]
      if (!moduleTargetClickable(target)) continue

      var targetPoint = { x: localX, y: localY }
      try {
        targetPoint = slot.mapToItem(target, localX, localY)
      } catch (e) {
        continue
      }

      if (targetPoint.x >= 0 && targetPoint.x <= target.width &&
          targetPoint.y >= 0 && targetPoint.y <= target.height) {
        return target
      }
    }

    if (moduleTargetClickable(slot.activeItem)) return slot.activeItem
    return null
  }

  function pressModuleClickTarget(slot, button, localX, localY) {
    var target = moduleClickTargetAt(slot, localX, localY)
    if (!target) return false

    target.triggerPress(button)
    return true
  }

  function colorHex(colorValue) {
    var c = colorValue
    if (typeof c === "string") c = Qt.color(c)
    function hexChannel(value) {
      var s = Math.round(Util.clamp(value, 0, 1) * 255).toString(16)
      return s.length < 2 ? "0" + s : s
    }
    return "#" + hexChannel(c.r) + hexChannel(c.g) + hexChannel(c.b)
  }

  function setRequestedTransparency(value) {
    var nextTransparent = value === true
    requestedTransparent = nextTransparent
    if (!nextTransparent) {
      foregroundAnimationEnabled = false
      useTransparentForeground = false
      transparent = false
      transparentForeground = themeForeground
      restoreForegroundAnimation()
      return
    }
    scheduleTransparentForegroundRefresh()
  }

  function restoreForegroundAnimation() {
    Qt.callLater(function() {
      Qt.callLater(function() { root.foregroundAnimationEnabled = true })
    })
  }

  function scheduleTransparentForegroundRefresh() {
    if (!requestedTransparent) {
      transparentForeground = themeForeground
      return
    }
    transparentForegroundTimer.restart()
  }

  function refreshTransparentForeground() {
    if (!requestedTransparent || transparentForegroundProc.running) return

    transparentForegroundProc.command = [
      "omarchy-bar-text-color",
      root.position,
      String(root.barSize),
      colorHex(root.themeForeground),
      colorHex(root.themeContrastForeground)
    ]
    transparentForegroundProc.running = true
  }

  onRequestedTransparentChanged: scheduleTransparentForegroundRefresh()
  onPositionChanged: scheduleTransparentForegroundRefresh()
  onThemeForegroundChanged: scheduleTransparentForegroundRefresh()
  onThemeContrastForegroundChanged: scheduleTransparentForegroundRefresh()

  Timer {
    id: transparentForegroundTimer
    interval: 120
    repeat: false
    onTriggered: root.refreshTransparentForeground()
  }

  Process {
    id: transparentForegroundProc
    stdout: SplitParser {
      onRead: function(line) {
        var value = String(line || "").trim()
        if (!/^#[0-9A-Fa-f]{6}$/.test(value)) return

        root.foregroundAnimationEnabled = false
        root.transparentForeground = value
        if (root.requestedTransparent) {
          root.useTransparentForeground = true
          root.transparent = true
        }
        root.restoreForegroundAnimation()
      }
    }
  }

  FileView {
    path: root.stateHome + "/omarchy/current"
    watchChanges: true
    printErrors: false
    onFileChanged: root.scheduleTransparentForegroundRefresh()
  }

  function runProcess(process) {
    if (!process.running)
      process.running = true
  }

  function showTooltip(target, text) {
    clearTooltip()

    if (!targetTooltipHovered(target) || !text) {
      tooltipRequest += 1
      return
    }

    var request = tooltipRequest + 1
    tooltipRequest = request
    pendingTooltipTarget = target
    pendingTooltipText = text

    Qt.callLater(function() {
      if (request !== tooltipRequest) return
      if (!targetTooltipHovered(pendingTooltipTarget)) {
        clearTooltip()
        return
      }
      tooltipTarget = pendingTooltipTarget
      tooltipText = pendingTooltipText
      pendingTooltipTarget = null
      pendingTooltipText = ""
      tooltipTimer.restart()
    })
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target && pendingTooltipTarget !== target) return

    tooltipRequest += 1
    clearTooltip()
  }

  Timer {
    id: tooltipTimer
    interval: 400
    onTriggered: {
      if (root.targetTooltipHovered(root.tooltipTarget)) root.tooltipShown = true
      else root.clearTooltip()
    }
  }

  Timer {
    interval: 100
    running: root.tooltipShown
    repeat: true
    onTriggered: if (!root.targetTooltipHovered(root.tooltipTarget)) root.hideTooltip(root.tooltipTarget)
  }

  // Presence of the `bar-off` flag = bar hidden. Watching the parent toggles
  // directory because FileView can't observe a file that doesn't exist yet,
  // and the flag is created/removed by `omarchy-toggle-bar`.
  Process {
    id: barHiddenProbe
    running: true
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser { onRead: function(line) { root.barHidden = String(line).trim() === "yes" } }
  }
  FileView {
    path: root.home + "/.local/state/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: barHiddenProbe.running = true
  }

  // The directory watch can permanently stop delivering events after flag
  // changes land in quick succession, stranding the bar off screen until the
  // shell restarts. `omarchy-toggle-bar` nudges this after flipping the flag
  // so the probe re-reads it even when the watch has gone quiet.
  IpcHandler {
    target: "omarchy.bar"

    // Start rather than restart: a probe already in flight was launched by the
    // directory watch after the flag flipped, so its answer is current, and
    // killing it here can swallow the result entirely.
    function syncHidden(): void {
      barHiddenProbe.running = true
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BarPanel {
        required property var modelData

        screen: modelData
      }
    }
  }

  // Модули, вытащенные на рабочий стол.
  Variants {
    model: Quickshell.screens
    delegate: Component {
      BarDeskPanel {
        required property var modelData
        screen: modelData
      }
    }
  }

  // Мост от бара к карточке открытой панели модуля (PopBridge.qml).
  Variants {
    model: Quickshell.screens
    delegate: Component {
      PopBridge {
        required property var modelData
        screen: modelData
        bar: root
      }
    }
  }

  // skin: форма frame — рамка по остальным краям экрана (ScreenBorder.qml).
  Variants {
    model: root.skin.framed ? Quickshell.screens : []

    delegate: Component {
      ScreenBorder {
        required property var modelData

        screen: modelData
        skin: root.skin
        barSize: root.barSize
        position: root.position
        shown: !root.barHidden && !root.transparent
        // skin.frameEmptyOnly (surface): рамка — только на пустом столе этого монитора, без резерва места
        reserve: !root.skin.frameEmptyOnly
        frameShown: {
          if (!root.skin.frameEmptyOnly) return true
          root.skinCompactRevision
          var m = Hyprland.monitorFor(modelData)
          return !!(m && m.activeWorkspace) && m.activeWorkspace.toplevels.values.length === 0
        }
        extraSpots: root.deskSpots[String(modelData.name)] || []
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      DragGhostPanel {
        required property var modelData

        screen: modelData
        ghostScreen: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BarMoveGhostPanel {
        required property var modelData

        screen: modelData
        ghostScreen: modelData
      }
    }
  }

  component BarPanel: PanelWindow {
    id: barWindow

    // Hiding parks the bar just past its screen edge instead of unmapping it.
    // Unmapping frees the layer surface and the whole scene graph, so every
    // reveal has to rebuild them — new surface, re-shaped glyphs, re-uploaded
    // textures — which measures ~150ms against ~20ms to tear down. Parking
    // keeps the surface alive, so showing is only a margin change.
    visible: !remapGuard.remapping
    // skin: окно толще бара (отступ + тень), резервируем только бар с отступом.
    exclusionMode: root.barHidden ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: skinFrame.reserved
    mask: Region { item: skinFrame.hitArea }

    // skin: курсор над баром (или над полоской спрятанного бара) держит его на экране.
    HoverHandler { id: skinHover }

    // skin: compact на этом мониторе; наведение (или открытая панель) разворачивает бар.
    readonly property var skinWorkspace: {
      var m = Hyprland.monitorFor(barWindow.screen)
      return m ? m.activeWorkspace : null
    }
    readonly property bool skinCompactWanted: root.skinPreview === "expanded" ? false
      : root.skinPreview === "compact" && root.skin.compactMode !== "off" ? true
      : root.skinCompactFor(skinWorkspace, root.skinCompactRevision)
    readonly property bool skinCompact: skinCompactWanted
      && !(root.skin.compactExpandOnHover && (skinHover.hovered || root.activePopout !== null))

    ScreenMoveRemap {
      id: remapGuard
      window: barWindow
    }

    margins {
      top: root.barHidden && root.position === "top" ? -skinFrame.extent : 0
      bottom: root.barHidden && root.position === "bottom" ? -skinFrame.extent : 0
      left: root.barHidden && root.position === "left" ? -skinFrame.extent : 0
      right: root.barHidden && root.position === "right" ? -skinFrame.extent : 0
    }

    anchors {
      top: root.position === "top" || root.vertical
      bottom: root.position === "bottom" || root.vertical
      left: root.position === "left" || !root.vertical
      right: root.position === "right" || !root.vertical
    }

    implicitWidth: root.vertical ? skinFrame.extent : 0
    implicitHeight: root.vertical ? 0 : skinFrame.extent
    // skin: фон рисует SkinFrame, само окно всегда прозрачное.
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-bar"
    WlrLayershell.layer: WlrLayer.Top

    SkinFrame {
      id: skinFrame
      anchors.fill: parent
      skin: root.skin
      barSize: root.barSize
      position: root.position
      transparent: root.transparent
      engaged: skinHover.hovered || root.activePopout !== null || root.barMoveActive || root.barDragSource !== null
      compact: barWindow.skinCompact
    }

    Loader {
      id: sectionsHost
      // skin: секции живут внутри видимой подложки; модули и острова находят
      // здесь compact и форму своего окна (root.skinHostOf).
      readonly property bool skinHost: true
      readonly property bool skinCompact: barWindow.skinCompact
      readonly property string skinShape: skinFrame.shape
      // доля длины гибких модулей (root.refitFlex)
      property real flexScale: 1
      onWidthChanged: root.requestFlexRefit(sectionsHost)
      onHeightChanged: root.requestFlexRefit(sectionsHost)
      x: skinFrame.body.x
      y: skinFrame.body.y
      width: skinFrame.body.width
      height: skinFrame.body.height
      sourceComponent: root.vertical ? verticalBar : horizontalBar

      // A child of the loader, not a sibling of the sections: an ancestor stays
      // hovered while the pointer is over a widget, where a sibling would lose
      // hover to the section the pointer entered.
      HoverHandler {
        onHoveredChanged: root.setBarHovered(hovered)
        // Unplugging a monitor destroys its bar without a leave event, which
        // would strand this surface's tally and hold the peek open for good.
        Component.onDestruction: if (hovered) root.setBarHovered(false)
      }
    }

    PopupWindow {
      id: tooltipWindow

      visible: root.tooltipShown && root.tooltipTarget !== null && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
      color: "transparent"
      implicitWidth: Math.ceil(tooltipBubble.implicitWidth)
      implicitHeight: Math.ceil(tooltipBubble.implicitHeight)

      anchor {
        id: tooltipAnchor
        window: barWindow
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        rect.width: 1
        rect.height: 1

        onAnchoring: {
          var target = root.tooltipTarget
          if (!root.targetBelongsToWindow(target, barWindow)) return

          var popupWidth = tooltipWindow.implicitWidth
          var popupHeight = tooltipWindow.implicitHeight
          var localX = target.width / 2 - popupWidth / 2
          var localY = target.height + 6

          if (root.position === "bottom") {
            localY = -popupHeight - 6
          } else if (root.position === "left") {
            localX = target.width + 6
            localY = target.height / 2 - popupHeight / 2
          } else if (root.position === "right") {
            localX = -popupWidth - 6
            localY = target.height / 2 - popupHeight / 2
          }

          var point = barWindow.contentItem.mapFromItem(target, localX, localY)
          tooltipAnchor.rect.x = Math.round(point.x)
          tooltipAnchor.rect.y = Math.round(point.y)
        }
      }

      BorderSurface {
        id: tooltipBubble
        implicitWidth: tooltipLabel.implicitWidth + 20
        implicitHeight: tooltipLabel.implicitHeight + 14
        color: Commons.Color.tooltip.background
        borderSpec: Border.surfaceSpec("tooltip", "border", Commons.Color.tooltip.border, 1)
        radius: Style.cornerRadius

        Text {
          id: tooltipLabel
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: root.tooltipText
          color: Commons.Color.tooltip.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }

    Component {
      id: horizontalBar

      Item {
        anchors.fill: parent

        // skin: центр не заходит на левую и правую секции (см. centerOffset).
        CenterModules {
          anchors.fill: parent
          minStart: hLeft.x + hLeft.width + root.sectionPadding
          maxEnd: hRight.x - root.sectionPadding
        }

        // skin: острова под левой и правой секциями.
        SkinIsland { skin: root.skin; target: hLeft; vertical: false; transparent: root.transparent }
        SkinIsland { skin: root.skin; target: hRight; vertical: false; transparent: root.transparent }

        LeftModules {
          id: hLeft
          anchors.left: parent.left
          anchors.leftMargin: root.sectionPadding
          anchors.verticalCenter: parent.verticalCenter
        }

        RightModules {
          id: hRight
          anchors.right: parent.right
          anchors.rightMargin: root.sectionPadding
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    Component {
      id: verticalBar

      Item {
        anchors.fill: parent

        CenterModules {
          anchors.fill: parent
          minStart: vLeft.y + vLeft.height + root.sectionPadding
          maxEnd: vRight.y - root.sectionPadding
        }

        LeftModules {
          id: vLeft
          anchors.top: parent.top
          anchors.topMargin: root.sectionPadding
          anchors.horizontalCenter: parent.horizontalCenter
        }

        RightModules {
          id: vRight
          anchors.bottom: parent.bottom
          anchors.bottomMargin: root.sectionPadding
          anchors.horizontalCenter: parent.horizontalCenter
        }
      }
    }
  }

  // skin: см. SkinWorkspaces.qml.
  Component { id: skinWorkspacesComponent; SkinWorkspaces { } }

  Component { id: emptyModuleComponent; Item { implicitWidth: 0; implicitHeight: 0; visible: false } }

  // Модули бара на рабочем столе (deskItems этого экрана): карточка цвета бара с его контуром, внутри — тот же модуль,
  // что был на баре (тот же компонент из реестра или свой QML, тот же bar-api). Тянут за любое место (клик — модулю);
  // у кромки рамки / бара карточка вплотную и сливается (углы у кромки вогнутые, контур рамки стирает ScreenBorder).
  component BarDeskPanel: PanelWindow {
    id: deskWin

    readonly property string scrName: screen ? String(screen.name) : ""
    readonly property var mine: {
      var out = []
      for (var i = 0; i < root.deskItems.length; i++)
        if (String(root.deskItems[i].screen || "") === scrName) out.push({ index: i, item: root.deskItems[i] })
      return out
    }
    // рабочая область (без бара и рамки)
    function inset(e) { return e === root.position ? root.barSize : root.skin.framed ? root.skin.frameWidth : 0 }
    readonly property rect work: Qt.rect(inset("left"), inset("top"), width - inset("left") - inset("right"), height - inset("top") - inset("bottom"))
    readonly property bool solidEdges: ["floating", "pill", "islands", "notches", "notch", "hug"].indexOf(String(root.skin.value("shape"))) === -1
    function mergeable(e) { return solidEdges && !root.transparent && (root.skin.framed || e === root.position) }
    property bool holding: false

    // несут модуль с бара на этот экран: окно ловит курсор целиком, призрак модуля идёт за ним
    readonly property bool carrying: root.carry !== null && root.carry.screen === scrName
    property point carryPt: carrying ? Qt.point(root.carry.x, root.carry.y) : Qt.point(0, 0)
    onCarryingChanged: if (carrying) { carryPt = Qt.point(root.carry.x, root.carry.y); carryIdle.restart() }
    Timer { id: carryIdle; interval: 700; onTriggered: if (deskWin.carrying) root.dropCarry(deskWin.carryPt.x, deskWin.carryPt.y) }

    visible: (mine.length > 0 || carrying) && !root.barHidden
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-bar-desk"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { regions: deskWin.holding || deskWin.carrying ? [deskAll] : deskRegions.instances }
    Region { id: deskAll; x: 0; y: 0; width: deskWin.width; height: deskWin.height }
    // область ввода — прямоугольники карточек (их обновляет таймер ниже: itemAt() в привязке маски срабатывает раньше,
    // чем Repeater создаст карточки, и маска выходит пустой)
    property var cardRects: []
    Variants {
      id: deskRegions
      model: deskWin.cardRects
      Region { required property var modelData; x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h }
    }

    // места стыков — ScreenBorder (в px рабочей области)
    function exportSpots() {
      var out = []
      for (var i = 0; i < deskCards.count; i++) {
        var c = deskCards.itemAt(i)
        if (!c) continue
        for (var j = 0; j < c.merged.length; j++) {
          var e = c.merged[j], v = e === "top" || e === "bottom"
          out.push({ edge: e, a0: Math.round(v ? c.x - work.x : c.y - work.y), a1: Math.round(v ? c.x + c.width - work.x : c.y + c.height - work.y), f: 12 })
        }
      }
      root.setDeskSpots(scrName, out)
      var rects = []
      for (var k = 0; k < deskCards.count; k++) {
        var it = deskCards.itemAt(k)
        if (it) rects.push({ x: Math.round(it.x), y: Math.round(it.y), w: Math.round(it.width), h: Math.round(it.height) })
      }
      if (JSON.stringify(rects) !== JSON.stringify(cardRects)) cardRects = rects
    }
    Timer { interval: 250; running: deskWin.visible; repeat: true; triggeredOnStart: true; onTriggered: deskWin.exportSpots() }
    onVisibleChanged: if (!visible) root.setDeskSpots(scrName, [])

    MouseArea {
      anchors.fill: parent
      visible: deskWin.carrying
      z: 100
      hoverEnabled: true
      acceptedButtons: Qt.AllButtons
      cursorShape: Qt.ClosedHandCursor
      onPositionChanged: function(m) { deskWin.carryPt = Qt.point(m.x, m.y); carryIdle.restart() }
      onPressed: function(m) { root.dropCarry(m.x, m.y) }
      onReleased: function(m) { if (deskWin.carrying) root.dropCarry(m.x, m.y) }
    }
    Image {
      visible: deskWin.carrying
      z: 99
      source: deskWin.carrying ? root.carry.image : ""
      x: deskWin.carryPt.x - width / 2
      y: deskWin.carryPt.y - height / 2
      opacity: 0.85
    }

    Repeater {
      id: deskCards
      model: deskWin.mine

      Item {
        id: card
        required property var modelData
        readonly property int deskIndex: modelData.index
        readonly property var entry: modelData.item.entry
        readonly property string moduleName: root.entryId(entry)
        readonly property var moduleSettings: root.entrySettings(entry)
        readonly property string customType: root.customModuleType(entry)
        readonly property var registryMetadata: root.barWidgetRegistry.metadataFor(root.canonicalWidgetId(moduleName))
        readonly property bool firstParty: registryMetadata && registryMetadata.firstParty === true
        readonly property bool registered: registryComponent !== null
        readonly property string pluginApiId: registered ? root.canonicalWidgetId(moduleName) : "bar-entry:" + moduleName
        readonly property var registryComponent: {
          var w = root.barWidgetRegistry.widgets
          if (customType) return null
          var name = root.canonicalWidgetId(moduleName)
          if (name === "omarchy.workspaces" && w[name]) return skinWorkspacesComponent
          return w[name] ? w[name].component : null
        }
        readonly property bool qmlCustom: customType === "qml"
        readonly property var activeItem: registered ? deskReg.item : qmlCustom ? deskQml.item : null
        function injectProps() {
          var t = activeItem
          if (!t) return
          if ("bar" in t) t.bar = firstParty ? root : root.pluginBarApiFor(pluginApiId, moduleName, registered) || null
          if ("moduleName" in t) t.moduleName = moduleName
          if ("settings" in t) t.settings = moduleSettings
        }
        onActiveItemChanged: Qt.callLater(injectProps)

        readonly property real pad: 8
        // skin: облик райса и на столе (RiceLook.dresses) — подложка riceDress в карточке и поля вдоль модуля под неё
        readonly property string dressSource: qmlCustom && entry && typeof entry === "object" ? String(entry.source || "") : ""
        readonly property bool riceDressed: root.skin.value("riceModules") !== false
          && root.riceLook.dresses(moduleName, dressSource, moduleSettings)
        readonly property real dressStart: riceDressed ? deskDress.padStart : 0
        readonly property real dressEnd: riceDressed ? deskDress.padEnd : 0
        readonly property bool dressTint: riceDressed && deskDress.colorize && !root.riceLook.riceFile(dressSource)
        readonly property real mw: activeItem ? Math.max(1, root.vertical ? root.barSize : activeItem.implicitWidth) : 40
        readonly property real mh: activeItem ? Math.max(1, root.vertical ? activeItem.implicitHeight : root.barSize) : 40
        readonly property real dw: mw + (root.vertical ? 0 : dressStart + dressEnd)
        readonly property real dh: mh + (root.vertical ? dressStart + dressEnd : 0)
        width: dw + 2 * pad
        height: dh + 2 * pad
        // позиция: сохранённая или та, куда тянут; в пределах рабочей области, у сливающейся кромки — вплотную
        property point drag: Qt.point(NaN, NaN)
        function fit(px, py) {
          var w = deskWin.work
          var x = Math.max(w.x, Math.min(w.x + w.width - width, px))
          var y = Math.max(w.y, Math.min(w.y + w.height - height, py))
          if (deskWin.mergeable("left") && x - w.x < 32) x = w.x
          if (deskWin.mergeable("right") && w.x + w.width - (x + width) < 32) x = w.x + w.width - width
          if (deskWin.mergeable("top") && y - w.y < 32) y = w.y
          if (deskWin.mergeable("bottom") && w.y + w.height - (y + height) < 32) y = w.y + w.height - height
          return Qt.point(x, y)
        }
        readonly property point at: fit(isNaN(drag.x) ? (isFinite(Number(modelData.item.x)) ? Number(modelData.item.x) : deskWin.work.x + 40) : drag.x,
                                        isNaN(drag.y) ? (isFinite(Number(modelData.item.y)) ? Number(modelData.item.y) : deskWin.work.y + 40) : drag.y)
        x: at.x
        y: at.y

        readonly property var merged: {
          var w = deskWin.work, out = []
          if (deskWin.mergeable("top") && y <= w.y + 0.5) out.push("top")
          if (deskWin.mergeable("bottom") && y + height >= w.y + w.height - 0.5) out.push("bottom")
          if (deskWin.mergeable("left") && x <= w.x + 0.5) out.push("left")
          if (deskWin.mergeable("right") && x + width >= w.x + w.width - 0.5) out.push("right")
          return out
        }
        function isMerged(e) { return merged.indexOf(e) !== -1 }

        // карточка: у слитых сторон уходит под рамку (там её контур и скругления не видны), сверху — вогнутые углы
        readonly property real bw: root.skin.borderWidth
        readonly property real r: 14
        readonly property real hide: r + bw + 3
        Rectangle {
          x: card.isMerged("left") ? -card.hide : 0
          y: card.isMerged("top") ? -card.hide : 0
          width: card.width + (card.isMerged("left") ? card.hide : 0) + (card.isMerged("right") ? card.hide : 0)
          height: card.height + (card.isMerged("top") ? card.hide : 0) + (card.isMerged("bottom") ? card.hide : 0)
          radius: card.r
          color: Qt.rgba(root.skin.backgroundColor.r, root.skin.backgroundColor.g, root.skin.backgroundColor.b, Math.max(0.85, root.skin.backgroundColor.a))
          border.width: card.bw
          border.color: root.skin.borderColor
        }
        Repeater {
          model: [["top", -1], ["top", 1], ["bottom", -1], ["bottom", 1], ["left", -1], ["left", 1], ["right", -1], ["right", 1]].filter(function(m) {
            var adj = m[0] === "top" || m[0] === "bottom" ? (m[1] < 0 ? "left" : "right") : (m[1] < 0 ? "top" : "bottom")
            return card.isMerged(m[0]) && !card.isMerged(adj)
          })
          MergeFillet {
            required property var modelData
            edge: modelData[0]; side: modelData[1]
            w: card.width; h: card.height
            f: 12; bw: card.bw; ext: 3
            fill: Qt.rgba(root.skin.backgroundColor.r, root.skin.backgroundColor.g, root.skin.backgroundColor.b, Math.max(0.85, root.skin.backgroundColor.a))
            line: root.skin.borderColor
          }
        }

        RiceDress {
          id: deskDress
          separators: false
          x: card.pad; y: card.pad
          width: card.dw; height: card.dh
          visible: card.riceDressed
          rice: root.riceLook.rice
          cozy: root.riceLook.cozy
          vertical: root.vertical
          across: root.barSize
          hovered: deskHover.hovered
          name: card.moduleName
          tray: card.moduleName === "omarchy.tray" || card.moduleName === "kamradsmeshnyavy.tray"
          fg: root.barForeground
          bg: root.background.a > 0 ? Qt.rgba(root.background.r, root.background.g, root.background.b, 1) : Commons.Color.background
        }
        Item {
          id: holder
          x: card.pad + (root.vertical ? 0 : card.dressStart)
          y: card.pad + (root.vertical ? card.dressStart : 0)
          width: card.mw; height: card.mh
          // skin: перекраска модуля в цвет райса (shaders/ricetint.frag), как на баре
          layer.enabled: card.dressTint
          layer.effect: ShaderEffect {
            property color ink: deskDress.ink
            fragmentShader: Qt.resolvedUrl("shaders/ricetint.frag.qsb")
          }
          Loader {
            id: deskReg
            active: card.registered
            sourceComponent: card.registered ? card.registryComponent : null
            anchors.fill: parent
            onLoaded: { card.injectProps(); Qt.callLater(card.injectProps) }
          }
          Loader {
            id: deskQml
            active: card.qmlCustom
            source: card.qmlCustom ? root.customModuleSource(card.entry) : ""
            anchors.fill: parent
            onLoaded: { card.injectProps(); Qt.callLater(card.injectProps) }
          }
        }
        // перенос и клики — с элемента поверх модуля: тянут — DragHandler, клик — модулю, как на баре (цели раздаёт
        // pressModuleClickTarget; свои MouseArea модулей тут нажатие не получают)
        Item {
          anchors.fill: parent
          z: 10
          TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onTapped: function(ev, button) {
              var p = ev.position
              root.pressModuleClickTarget(card, button, p.x, p.y)
            }
          }
          DragHandler {
            id: cardDrag
            target: null
            dragThreshold: 6
            property point base
            onActiveChanged: {
              deskWin.holding = active
              if (active) { base = Qt.point(card.x, card.y); card.drag = Qt.point(card.x, card.y); return }
              var p = { x: Number(card.drag.x), y: Number(card.drag.y) }, w = deskWin.width, h = deskWin.height
              var cx = p.x + card.width / 2, cy = p.y + card.height / 2
              var inner = root.barInnerEdge(w, h)
              var near = root.position === "left" ? p.x - inner < 24 : root.position === "right" ? inner - (p.x + card.width) < 24
                : root.position === "top" ? p.y - inner < 24 : inner - (p.y + card.height) < 24
              card.drag = Qt.point(NaN, NaN)
              if (near) root.dockDeskItem(card.deskIndex, root.vertical ? cy : cx, root.vertical ? h : w)
              else { var f = card.fit(p.x, p.y); root.moveDeskItem(card.deskIndex, f.x, f.y) }
            }
            onTranslationChanged: if (active) card.drag = Qt.point(Number(base.x) + translation.x, Number(base.y) + translation.y)
          }
          HoverHandler { id: deskHover; cursorShape: cardDrag.active ? Qt.ClosedHandCursor : Qt.ArrowCursor }
        }
        // пока тянут — без привязки к кромкам, чтобы до бара можно было дотянуть
        states: State {
          when: cardDrag.active
          PropertyChanges { target: card; x: card.drag.x; y: card.drag.y }
        }
      }
    }
  }

  component DragGhostPanel: PanelWindow {
    id: ghostWindow

    required property var ghostScreen
    readonly property bool screenMatches: root.barDragScreen === ghostScreen ||
      (root.barDragScreen && ghostScreen && root.barDragScreen.name && ghostScreen.name && root.barDragScreen.name === ghostScreen.name)
    readonly property bool active: root.barDragSource && root.barDragScreen && screenMatches
    readonly property var sourceItem: root.barDragSource ? root.barDragSource.activeItem : null
    readonly property int ghostPadding: Style.space(1)
    readonly property int ghostWidth: sourceItem ? Math.max(1, Math.ceil(sourceItem.width)) : 1
    readonly property int ghostHeight: sourceItem ? Math.max(1, Math.ceil(sourceItem.height)) : 1

    visible: active && sourceItem !== null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-bar-drag-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Visual-only drag feedback. Keep the input region empty so the ghost can
    // sit under the cursor without stealing the MouseArea's active pointer grab.
    mask: Region {}


    Item {
      visible: ghostWindow.visible
      x: Math.round(root.barDragScreenX - root.barDragOffsetX - ghostWindow.ghostPadding)
      y: Math.round(root.barDragScreenY - root.barDragOffsetY - ghostWindow.ghostPadding)
      width: ghostWindow.ghostWidth + ghostWindow.ghostPadding * 2
      height: ghostWindow.ghostHeight + ghostWindow.ghostPadding * 2

      BorderSurface {
        anchors.fill: parent
        color: root.transparent ? "transparent" : root.background
        borderSpec: Border.flat(root.barForeground, 1)
        radius: Math.min(Style.cornerRadius, height / 2)
        opacity: root.transparent ? 0.45 : 0.94
      }

      Image {
        anchors.fill: parent
        anchors.margins: ghostWindow.ghostPadding
        source: root.barDragImageUrl
        fillMode: Image.Stretch
        smooth: true
        opacity: 0.84
      }
    }

    Rectangle {
      readonly property var targetRect: root.barDragTargetGeometry

      visible: ghostWindow.active && targetRect !== null
      x: targetRect ? Math.round(targetRect.x) : 0
      y: targetRect ? Math.round(targetRect.y) : 0
      width: targetRect ? targetRect.width : 0
      height: targetRect ? targetRect.height : 0
      color: Commons.Color.accent
      radius: Math.min(width, height) / 2
    }
  }

  component BarMoveGhostPanel: PanelWindow {
    id: moveGhostWindow

    required property var ghostScreen
    readonly property bool screenMatches: root.barMoveScreen === ghostScreen ||
      (root.barMoveScreen && ghostScreen && root.barMoveScreen.name && ghostScreen.name && root.barMoveScreen.name === ghostScreen.name)
    visible: root.barMoveActive && screenMatches
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-bar-move-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Visual-only preview of the candidate edge. Keep the input region empty
    // so the overlay never steals the gesture area's active pointer grab.
    mask: Region {}

    // One fixed-geometry slab per edge, crossfaded on candidate changes.
    // Resizing a single slab between edges repaints mid-transition and
    // flickers; fading between static ones does not.
    Repeater {
      model: ["top", "bottom", "left", "right"]

      BorderSurface {
        id: edgeSlab

        required property string modelData
        readonly property bool edgeVertical: modelData === "left" || modelData === "right"
        readonly property int edgeSize: edgeVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal

        x: modelData === "right" ? parent.width - edgeSize : 0
        y: modelData === "bottom" ? parent.height - edgeSize : 0
        width: edgeVertical ? edgeSize : parent.width
        height: edgeVertical ? parent.height : edgeSize
        color: root.transparent ? "transparent" : root.background
        borderSpec: Border.flat(root.barForeground, 1)
        visible: opacity > 0
        opacity: root.barMoveCandidate === modelData ? (root.transparent ? 0.45 : 0.7) : 0

        Behavior on opacity {
          NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
      }
    }
  }

  // skin: центральная секция стоит посередине, но не поверх левой и правой: на вертикальном баре
  // длинная правая секция (трей, индикаторы, часы) доходила до середины, и значок активного окна
  // ложился на трей. Группа «до якоря + якорь + после» сдвигается назад от правой секции, затем
  // вперёд от левой; при совсем переполненном баре прижата к левой.
  function centerOffset(ideal, before, size, after, minStart, maxEnd) {
    var pos = ideal
    if (pos + size + after > maxEnd) pos = maxEnd - size - after
    if (pos - before < minStart) pos = minStart + before
    return pos
  }

  function findCenterAnchorEntry() {
    var entries = root.layoutEntries("center")
    var idx = root.entryIndex(entries, root.centerAnchor)
    return idx === -1 ? null : entries[idx]
  }

  component LeftModules: ModuleList {
    entries: root.layoutEntries("left")
    region: "left"
  }

  component RightModules: ModuleList {
    entries: root.layoutEntries("right")
    region: "right"
  }

  component CenterModules: Item {
    id: centerRoot

    property var entries: root.layoutEntries("center")
    // skin: свободное место между левой и правой секциями (по x или по y).
    property real minStart: 0
    property real maxEnd: root.vertical ? height : width
    readonly property bool hasAnchor: root.entryIndex(entries, root.centerAnchor) !== -1
    readonly property var anchorEntry: root.findCenterAnchorEntry()

    Loader {
      anchors.fill: parent
      sourceComponent: root.vertical ? verticalCenterModules : horizontalCenterModules
    }

    Component {
      id: horizontalCenterModules

      Item {
        anchors.fill: parent

        CenterGestureArea { anchors.fill: parent }

        HoverHandler {
          onHoveredChanged: root.setCenterSectionHovered(hovered)
        }

        // skin: остров под центром — от первого до последнего видимого списка.
        SkinIsland {
          skin: root.skin
          target: centerAnchorModule
          vertical: false
          transparent: root.transparent
          visible: root.skin.islandShape(shape) && spanEnd - spanStart > 0
          spanStart: centerRoot.hasAnchor
            ? (hBefore.width > 0 ? hBefore.x : centerAnchorModule.x)
            : hPlain.x
          spanEnd: centerRoot.hasAnchor
            ? (hAfter.width > 0 ? hAfter.x + hAfter.width : centerAnchorModule.x + centerAnchorModule.width)
            : hPlain.x + hPlain.width
        }

        ModuleList {
          id: hPlain
          visible: !centerRoot.hasAnchor
          entries: centerRoot.entries
          region: "center"
          anchors.verticalCenter: parent.verticalCenter
          x: root.centerOffset((parent.width - width) / 2, 0, width, 0, centerRoot.minStart, centerRoot.maxEnd)
        }

        ModuleList {
          id: hBefore
          visible: centerRoot.hasAnchor
          entries: root.entriesBefore(centerRoot.entries, root.centerAnchor)
          region: "center"
          anchors.right: centerAnchorModule.left
          anchors.verticalCenter: centerAnchorModule.verticalCenter
        }

        ModuleSlot {
          id: centerAnchorModule
          visible: centerRoot.hasAnchor
          entry: centerRoot.anchorEntry
          region: "center"
          anchors.verticalCenter: parent.verticalCenter
          x: root.centerOffset((parent.width - width) / 2, hBefore.visible ? hBefore.width : 0, width,
                               hAfter.visible ? hAfter.width : 0, centerRoot.minStart, centerRoot.maxEnd)
        }

        ModuleList {
          id: hAfter
          visible: centerRoot.hasAnchor
          entries: root.entriesAfter(centerRoot.entries, root.centerAnchor)
          region: "center"
          anchors.left: centerAnchorModule.right
          anchors.verticalCenter: centerAnchorModule.verticalCenter
        }
      }
    }

    Component {
      id: verticalCenterModules

      Item {
        anchors.fill: parent

        CenterGestureArea { anchors.fill: parent }

        HoverHandler {
          onHoveredChanged: root.setCenterSectionHovered(hovered)
        }

        ModuleList {
          visible: !centerRoot.hasAnchor
          entries: centerRoot.entries
          region: "center"
          anchors.horizontalCenter: parent.horizontalCenter
          y: root.centerOffset((parent.height - height) / 2, 0, height, 0, centerRoot.minStart, centerRoot.maxEnd)
        }

        ModuleList {
          id: vBefore
          visible: centerRoot.hasAnchor
          entries: root.entriesBefore(centerRoot.entries, root.centerAnchor)
          region: "center"
          anchors.bottom: centerAnchorModule.top
          anchors.horizontalCenter: centerAnchorModule.horizontalCenter
        }

        ModuleSlot {
          id: centerAnchorModule
          visible: centerRoot.hasAnchor
          entry: centerRoot.anchorEntry
          region: "center"
          anchors.horizontalCenter: parent.horizontalCenter
          y: root.centerOffset((parent.height - height) / 2, vBefore.visible ? vBefore.height : 0, height,
                               vAfter.visible ? vAfter.height : 0, centerRoot.minStart, centerRoot.maxEnd)
        }

        ModuleList {
          id: vAfter
          visible: centerRoot.hasAnchor
          entries: root.entriesAfter(centerRoot.entries, root.centerAnchor)
          region: "center"
          anchors.top: centerAnchorModule.bottom
          anchors.horizontalCenter: centerAnchorModule.horizontalCenter
        }
      }
    }
  }

  component CenterGestureArea: MouseArea {
    id: gestureArea

    property bool dragging: false
    property bool suppressClick: false
    property real pressedX: 0
    property real pressedY: 0
    readonly property real dragThreshold: Style.space(4)

    acceptedButtons: Qt.LeftButton
    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
    pressAndHoldInterval: 200

    function startDrag(x, y) {
      if (dragging) return
      dragging = true
      root.beginBarMove(root.targetWindow(gestureArea))
      var scenePoint = gestureArea.mapToItem(null, x, y)
      root.updateBarMove(root.windowScreenPoint(scenePoint, root.barMoveWindow))
    }

    onPressed: function(mouse) {
      dragging = false
      suppressClick = false
      pressedX = mouse.x
      pressedY = mouse.y
    }

    onPressAndHold: function(mouse) {
      // A widget above us propagates its composed press-and-hold down here without
      // ever handing over the grab, so we'd get no release or cancel to end the move.
      if (!gestureArea.pressed) return
      startDrag(mouse.x, mouse.y)
    }

    onPositionChanged: function(mouse) {
      if (!(mouse.buttons & Qt.LeftButton)) return

      if (!dragging) {
        var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
        if (distance < dragThreshold) return
        startDrag(mouse.x, mouse.y)
        return
      }

      var scenePoint = gestureArea.mapToItem(null, mouse.x, mouse.y)
      root.updateBarMove(root.windowScreenPoint(scenePoint, root.barMoveWindow))
    }

    onReleased: function(mouse) {
      if (!dragging) return
      dragging = false
      suppressClick = true
      root.finishBarMove()
      mouse.accepted = true
    }

    onCanceled: {
      dragging = false
      suppressClick = false
      root.clearBarMove()
    }

    onClicked: function(mouse) {
      if (suppressClick) {
        suppressClick = false
        mouse.accepted = true
      }
    }

    onDoubleClicked: function(mouse) {
      if (suppressClick) {
        suppressClick = false
        return
      }
      if (mouse.button === Qt.LeftButton) {
        root.toggleTransparency()
        mouse.accepted = true
      }
    }
  }

  component ModuleList: Loader {
    id: moduleListRoot

    property var entries: []
    property string region: ""

    visible: entries.length > 0
    // A hidden list must not build its modules. The center section declares
    // both an anchored and an unanchored arrangement and shows whichever
    // fits, so leaving the other one loaded mounts every center module
    // twice — two IPC handlers registered for the same target, two clocks
    // ticking, two of every timer and fetch behind them.
    active: visible && entries.length > 0
    sourceComponent: root.vertical ? verticalModuleList : horizontalModuleList
    width: item ? item.implicitWidth : 0
    height: item ? item.implicitHeight : 0

    Component {
      id: horizontalModuleList

      Row {
        // skin: зазор между модулями.
        spacing: root.skin.spacing

        Repeater {
          model: moduleListRoot.entries

          ModuleSlot {
            required property var modelData
            entry: modelData
            region: moduleListRoot.region
          }
        }
      }
    }

    Component {
      id: verticalModuleList

      Column {
        spacing: root.skin.spacing

        Repeater {
          model: moduleListRoot.entries

          ModuleSlot {
            required property var modelData
            entry: modelData
            region: moduleListRoot.region
          }
        }
      }
    }
  }

  component ModuleSlot: Item {
    id: slot

    required property var entry
    property string region: ""
    readonly property string moduleName: root.entryId(entry)
    readonly property var moduleSettings: root.entrySettings(entry)
    readonly property string customType: root.customModuleType(entry)
    readonly property var registryMetadata: root.barWidgetRegistry.metadataFor(root.canonicalWidgetId(moduleName))
    readonly property bool firstParty: registryMetadata && registryMetadata.firstParty === true
    readonly property string pluginApiId: registered ? root.canonicalWidgetId(moduleName) : "bar-entry:" + moduleName
    // Re-evaluate when the registry mutates (Component reference changes,
    // plugin enabled/disabled, etc.). Reading the `widgets` property creates
    // the binding dependency — the wrapped function call alone wouldn't.
    readonly property var registryComponent: {
      var w = root.barWidgetRegistry.widgets
      if (customType) return null
      var registryName = root.canonicalWidgetId(moduleName)
      // skin: свои workspaces (подписи, иконки окон) вместо стоковых.
      if (registryName === "omarchy.workspaces" && w[registryName]) return skinWorkspacesComponent
      return w[registryName] ? w[registryName].component : null
    }
    readonly property bool qmlCustom: customType === "qml"
    readonly property bool commandCustom: customType === "command"
    readonly property bool registered: registryComponent !== null
    readonly property var activeItem: {
      if (registered) return registryLoader.item
      if (qmlCustom) return qmlLoader.item
      return componentLoader.item
    }
    readonly property bool hovered: moduleHover.hovered
    readonly property bool dragSource: root.barDragSource === slot
    readonly property bool panelOpen: root.activePopout === slot.activeItem
    // Modules bigger than the mark they want (a text label in a padded slot,
    // a multi-line stack on a vertical bar) can say how long the open-panel
    // dot should be along the bar, so it tracks what the module paints
    // instead of a fraction of whatever slot it happens to fill.
    readonly property real panelIndicatorExtent: {
      var key = root.vertical ? "openPanelIndicatorHeight" : "openPanelIndicatorWidth"
      var hint = activeItem && key in activeItem ? activeItem[key] : undefined
      if (hint !== undefined && hint !== null && hint > 0) return Math.round(hint)
      return Math.max(Style.space(10), Math.round((root.vertical ? slot.height : slot.width) * 0.55))
    }
    // skin: compact прячет часть модулей (skin.compactModules).
    readonly property Item skinHostItem: root.skinHostOf(slot.parent)
    readonly property bool compactHidden: skinHostItem !== null && skinHostItem.skinCompact
      && root.skin.compactHides(root.canonicalWidgetId(moduleName), region)
    // skin: облик райса у чужого модуля (RiceLook.dresses) — подложка riceDress и поля вдоль бара под неё.
    readonly property string dressSource: qmlCustom && entry && typeof entry === "object" ? String(entry.source || "") : ""
    readonly property bool riceDressed: root.skin.value("riceModules") !== false
      && root.riceLook.dresses(moduleName, dressSource, moduleSettings)
    readonly property real dressStart: riceDressed ? riceDress.padStart : 0
    readonly property real dressEnd: riceDressed ? riceDress.padEnd : 0
    readonly property bool dressTint: riceDressed && riceDress.colorize && !root.riceLook.riceFile(dressSource)
    visible: !compactHidden
    // skin: гибкий модуль ("flex": true) — его длина вдоль бара ужимается долей flexScale своего окна (root.refitFlex)
    readonly property bool flexible: !!(moduleSettings && moduleSettings.flex === true)
    readonly property real flexNominal: activeItem ? (root.vertical ? activeItem.implicitHeight : activeItem.implicitWidth) : 0
    readonly property real flexScale: flexible && skinHostItem && skinHostItem.flexScale !== undefined ? skinHostItem.flexScale : 1
    readonly property real alongLen: flexible ? Math.round(flexNominal * flexScale) : flexNominal
    implicitWidth: !compactHidden && activeItem && activeItem.visible ? (root.vertical ? root.barSize : alongLen + dressStart + dressEnd) : 0
    implicitHeight: !compactHidden && activeItem && activeItem.visible ? (root.vertical ? alongLen + dressStart + dressEnd : activeItem.implicitHeight) : 0
    onWidthChanged: if (!root.vertical) root.requestFlexRefit(skinHostItem)
    onHeightChanged: if (root.vertical) root.requestFlexRefit(skinHostItem)
    onVisibleChanged: root.requestFlexRefit(skinHostItem)
    onSkinHostItemChanged: root.requestFlexRefit(skinHostItem)
    onFlexNominalChanged: root.requestFlexRefit(skinHostItem)
    width: implicitWidth
    height: implicitHeight
    z: modulePointer.dragging ? 100 : 0

    Component.onCompleted: root.registerModuleSlot(slot)
    Component.onDestruction: {
      if (root.barDragSource === slot) root.clearBarDrag()
      root.unregisterModuleSlot(slot)
    }

    HoverHandler { id: moduleHover }

    // skin: подложка модуля — pills (всегда) или hover (только под курсором).
    Rectangle {
      readonly property string style: root.skin.moduleStyle
      readonly property int inset: Style.space(3)
      // В compact подложка бара тоньше модуля — капсула не должна вылезать за неё.
      readonly property real across: Math.min(root.vertical ? slot.width : slot.height,
        slot.skinHostItem ? (root.vertical ? slot.skinHostItem.width : slot.skinHostItem.height) : 9999)
      visible: style !== "plain" && slot.width > 0 && !slot.dragSource && !slot.riceDressed
        && slot.moduleName !== "omarchy.spacer" && (style === "pills" || slot.hovered || slot.panelOpen)
      anchors.centerIn: parent
      width: root.vertical ? across - 2 * inset : slot.width
      height: root.vertical ? slot.height : across - 2 * inset
      radius: Math.min(width, height) / 2
      color: slot.hovered || slot.panelOpen ? Qt.rgba(root.skin.moduleColor.r, root.skin.moduleColor.g, root.skin.moduleColor.b,
        Math.min(1, root.skin.moduleColor.a * 2 + 0.04)) : root.skin.moduleColor
      Behavior on color { ColorAnimation { duration: 140 } }
    }

    BorderSurface {
      visible: slot.dragSource
      anchors.fill: parent
      anchors.margins: Style.space(1)
      color: root.transparent ? "transparent" : root.background
      borderSpec: Border.flat(root.barForeground, 1)
      radius: Math.min(Style.cornerRadius, height / 2)
      opacity: root.transparent ? 0.22 : 0.32
    }

    // skin: облик райса (RiceDress.qml) — под модулем, поверх подложки pills.
    RiceDress {
      id: riceDress
      anchors.fill: parent
      visible: slot.riceDressed && slot.width > 0 && !slot.dragSource
      rice: root.riceLook.rice
      cozy: root.riceLook.cozy
      vertical: root.vertical
      across: root.barSize
      hovered: slot.hovered
      active: slot.panelOpen
      name: slot.moduleName
      tray: slot.moduleName === "omarchy.tray" || slot.moduleName === "kamradsmeshnyavy.tray"
      fg: root.barForeground
      bg: root.background.a > 0 ? Qt.rgba(root.background.r, root.background.g, root.background.b, 1) : Commons.Color.background
    }

    Loader {
      id: componentLoader
      active: !slot.qmlCustom && !slot.registered
      sourceComponent: slot.commandCustom ? customCommandModuleComponent : emptyModuleComponent
      anchors.fill: parent
      // skin: поля под облик райса и перекраска модуля в его цвет (shaders/ricetint.frag)
      anchors.leftMargin: root.vertical ? 0 : slot.dressStart
      anchors.rightMargin: root.vertical ? 0 : slot.dressEnd
      anchors.topMargin: root.vertical ? slot.dressStart : 0
      anchors.bottomMargin: root.vertical ? slot.dressEnd : 0
      layer.enabled: slot.dressTint
      layer.effect: ShaderEffect {
        property color ink: riceDress.ink
        fragmentShader: Qt.resolvedUrl("shaders/ricetint.frag.qsb")
      }
      opacity: slot.dragSource ? 0.22 : 1.0
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Loader {
      id: registryLoader
      active: slot.registered
      sourceComponent: slot.registered ? slot.registryComponent : null
      anchors.fill: parent
      // skin: поля под облик райса и перекраска модуля в его цвет (shaders/ricetint.frag)
      anchors.leftMargin: root.vertical ? 0 : slot.dressStart
      anchors.rightMargin: root.vertical ? 0 : slot.dressEnd
      anchors.topMargin: root.vertical ? slot.dressStart : 0
      anchors.bottomMargin: root.vertical ? slot.dressEnd : 0
      layer.enabled: slot.dressTint
      layer.effect: ShaderEffect {
        property color ink: riceDress.ink
        fragmentShader: Qt.resolvedUrl("shaders/ricetint.frag.qsb")
      }
      opacity: slot.dragSource ? 0.22 : 1.0
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Loader {
      id: qmlLoader
      active: slot.qmlCustom
      source: slot.qmlCustom ? root.customModuleSource(slot.entry) : ""
      anchors.fill: parent
      // skin: поля под облик райса и перекраска модуля в его цвет (shaders/ricetint.frag)
      anchors.leftMargin: root.vertical ? 0 : slot.dressStart
      anchors.rightMargin: root.vertical ? 0 : slot.dressEnd
      anchors.topMargin: root.vertical ? slot.dressStart : 0
      anchors.bottomMargin: root.vertical ? slot.dressEnd : 0
      layer.enabled: slot.dressTint
      layer.effect: ShaderEffect {
        property color ink: riceDress.ink
        fragmentShader: Qt.resolvedUrl("shaders/ricetint.frag.qsb")
      }
      opacity: slot.dragSource ? 0.22 : 1.0
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Rectangle {
      id: openPanelIndicator

      readonly property int inset: Style.space(2)

      visible: opacity > 0
      opacity: slot.panelOpen && !slot.dragSource ? 0.9 : 0
      color: Commons.Color.accent
      radius: Math.min(width, height) / 2
      width: root.vertical ? Style.space(2) : slot.panelIndicatorExtent
      height: root.vertical ? slot.panelIndicatorExtent : Style.space(2)
      // The mark sits on the module's inner edge — the one facing the
      // desktop — so it underlines a top bar, overlines a bottom one, and
      // points inward from a left or right one. It reads as pointing at the
      // panel that opens on that side.
      // Snap toward the start of the slot, matching native glyph rendering.
      x: root.vertical
        ? (root.position === "left" ? parent.width - width - inset : inset)
        : Math.floor((parent.width - width) / 2)
      y: root.vertical
        ? Math.floor((parent.height - height) / 2)
        : (root.position === "top" ? parent.height - height - inset : inset)
      z: 50

      Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
      }
    }

    MouseArea {
      id: modulePointer

      property bool dragging: false
      property bool suppressClick: false
      property real pressedX: 0
      property real pressedY: 0
      readonly property bool canReorder: root.shell && typeof root.shell.mutateShellConfig === "function"
      readonly property real dragThreshold: Style.space(4)

      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      enabled: slot.visible && slot.width > 0 && slot.height > 0
      propagateComposedEvents: true
      // Only the hovered slot needs the hit test; without the guard every
      // slot on every monitor re-ran it on each click target change.
      cursorShape: moduleHover.hovered && root.moduleClickTargetAt(slot, mouseX, mouseY) ? Qt.PointingHandCursor : Qt.ArrowCursor
      // Do not assign drag.target here: ModuleSlot is owned by Row/Column
      // positioners, and mutating slot.x/slot.y can leave stale offsets that
      // make neighboring modules overlap after a small aborted drag.

      onPressed: function(mouse) {
        dragging = false
        suppressClick = false
        pressedX = mouse.x
        pressedY = mouse.y
        root.clearBarDrag()
      }

      onPositionChanged: function(mouse) {
        if (!canReorder || !(mouse.buttons & Qt.LeftButton)) return

        var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
        if (distance >= dragThreshold) {
          if (!dragging) {
            root.barDragWindow = root.targetWindow(slot.activeItem) || root.targetWindow(slot)
            root.barDragScreen = root.barDragWindow ? root.barDragWindow.screen : null
            root.barDragOffsetX = pressedX
            root.barDragOffsetY = pressedY
            root.captureBarDragGhost(slot)
            root.barDragSource = slot
          }
          dragging = true
          root.hideTooltip(slot.activeItem)
        }

        if (dragging) {
          var scenePoint = slot.mapToItem(null, mouse.x, mouse.y)
          var screenPoint = root.barDragScreenPoint(scenePoint)
          root.barDragSceneX = scenePoint.x
          root.barDragSceneY = scenePoint.y
          root.barDragScreenX = screenPoint.x
          root.barDragScreenY = screenPoint.y

          var drop = root.moduleDropAtScene(scenePoint, slot)
          root.barDragTarget = drop ? drop.slot : null
          root.barDragAfter = drop ? drop.after : false
          root.barDragTargetGeometry = drop ? root.dropMarkerRect(drop.slot, drop.after) : null
        }
      }

      onReleased: function(mouse) {
        var wasDragging = dragging
        var targetSlot = root.barDragTarget
        var afterTarget = root.barDragAfter

        if (wasDragging) suppressClick = true

        dragging = false
        root.clearBarDrag()

        // За краем бара Hyprland не шлёт ему движения, а отпускание приходит с последней точкой внутри бара — где курсор
        // на самом деле, спрашиваем у Hyprland: дальше 60 px от бара — модуль уходит на стол (BarDeskPanel),
        // иначе — обычная перестановка.
        if (wasDragging) {
          root.finishBarDrag(slot, targetSlot, afterTarget)
          mouse.accepted = true
        } else if (!wasDragging) {
          mouse.accepted = false
        }
      }

      onCanceled: {
        dragging = false
        suppressClick = false
        root.clearBarDrag()
      }

      onClicked: function(mouse) {
        if (suppressClick) {
          suppressClick = false
          mouse.accepted = true
          return
        }

        if (!root.pressModuleClickTarget(slot, mouse.button, mouse.x, mouse.y)) mouse.accepted = false
      }
    }

    onActiveItemChanged: Qt.callLater(injectProps)
    onModuleSettingsChanged: injectProps()

    function injectProps() {
      var target = activeItem
      if (!target || typeof root === "undefined" || !root) return
      if ("bar" in target) {
        var api = firstParty ? root : root.pluginBarApiFor(pluginApiId, moduleName, registered)
        target.bar = api || null
      }
      if ("moduleName" in target) target.moduleName = moduleName
      if ("settings" in target) target.settings = moduleSettings
    }

    Component {
      id: customCommandModuleComponent
      CustomCommandModule { entry: slot.entry }
    }
  }

  component CustomCommandModule: WidgetButton {
    id: customRoot

    required property var entry
    readonly property string moduleName: root.entryId(entry)
    readonly property var settings: root.entrySettings(entry)
    property string outputText: ""
    property string outputTooltip: ""
    property bool outputActive: false

    function setting(name, fallback) {
      var value = settings ? settings[name] : undefined
      return value === undefined || value === null ? fallback : value
    }

    function update(raw) {
      var data = Util.parseModuleJson(raw)
      var klass = data.class || data.alt || ""

      outputText = data.text || String(raw || "").trim()
      outputTooltip = data.tooltip || String(setting("tooltip", ""))
      outputActive = klass === "active" || (Array.isArray(klass) && klass.indexOf("active") !== -1)
    }

    bar: root
    text: outputText || String(setting("text", ""))
    tooltipText: outputTooltip || String(setting("tooltip", ""))
    active: outputActive
    keepSpace: setting("keepSpace", false) === true
    horizontalMargin: Number(setting("horizontalMargin", 7.5))
    verticalPadding: Number(setting("verticalPadding", 6))
    fontSize: Number(setting("fontSize", 12))

    onPressed: function(button) {
      var command = ""
      if (button === Qt.RightButton)
        command = String(setting("onRightClick", ""))
      else if (button === Qt.MiddleButton)
        command = String(setting("onMiddleClick", ""))
      else
        command = String(setting("onClick", ""))

      if (command) root.run(command)
    }

    Process {
      id: customProc
      command: ["bash", "-lc", String(customRoot.setting("exec", ""))]
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: customRoot.update(text)
      }
    }

    Timer {
      interval: Math.max(1, Number(customRoot.setting("interval", 5))) * 1000
      running: String(customRoot.setting("exec", "")) !== ""
      repeat: true
      triggeredOnStart: true
      onTriggered: root.runProcess(customProc)
    }
  }
}
