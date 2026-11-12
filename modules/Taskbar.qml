import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets

// Таскбар / док (по мотивам surface-dots): на столе с окнами — значки окон этого стола (клик — фокус,
// активное подчёркнуто), на пустом столе — закреплённые приложения дока Omarchy (shell.json → dock.pinned,
// `omarchy dock pin`; клик — запуск). Вместе со скином compact = "empty" и compactModules = "taskbar" бар на
// пустом столе сжимается в пилюлю-док с одним этим модулем (скин surface-dock, раскладка taskbar).
// Иконки грузятся синхронно: их немного, а асинхронная загрузка тематических иконок в двух видах сразу
// роняла Quickshell (см. kamradsmeshnyavy.menu).
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  readonly property bool vertical: !!bar && bar.vertical === true
  readonly property color ink: bar && bar.barForeground ? bar.barForeground : "#ffffff"
  readonly property int across: bar && bar.barSize ? bar.barSize : 30
  readonly property int icon: Math.max(16, Math.min(28, across - 10))
  readonly property int cell: icon + 10

  property var pinned: []
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var d = JSON.parse(text() || "{}")
        root.pinned = d.dock && Array.isArray(d.dock.pinned) ? d.dock.pinned : []
      } catch (e) { root.pinned = [] }
    }
    onFileChanged: reload()
  }

  readonly property var ws: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.activeWorkspace : null
  readonly property var windows: {
    var list = Hyprland.toplevels.values, out = []
    for (var i = 0; ws && i < list.length; i++) {
      var t = list[i]
      if (!t.workspace || t.workspace.id !== ws.id) continue
      var ipc = t.lastIpcObject || {}
      out.push({ address: String(ipc.address || ""), cls: String(ipc["class"] || ""), title: String(ipc.title || t.title || ""),
                 active: Hyprland.activeToplevel === t })
    }
    return out
  }
  readonly property bool dockMode: windows.length === 0
  readonly property var items: dockMode
    ? pinned.map(function(id) {
        var e = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
        return e ? { kind: "app", id: id, name: e.name, icon: e.icon, active: false } : null
      }).filter(function(x) { return x !== null })
    : windows.map(function(w) {
        var e = DesktopEntries.heuristicLookup(w.cls)
        return { kind: "win", address: w.address, name: w.title || w.cls, icon: e ? e.icon : w.cls, active: w.active }
      })

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (/^(openwindow|closewindow|movewindow|movewindowv2|workspace|workspacev2|activewindowv2)$/.test(event.name)) refresh.restart()
    }
  }
  Timer { id: refresh; interval: 120; onTriggered: Hyprland.refreshToplevels() }

  implicitWidth: vertical ? across : Math.max(cell, items.length * cell)
  implicitHeight: vertical ? Math.max(cell, items.length * cell) : across

  Grid {
    anchors.centerIn: parent
    columns: root.vertical ? 1 : Math.max(1, root.items.length)
    Repeater {
      model: root.items
      Item {
        id: slot
        required property var modelData
        width: root.cell; height: root.cell
        Rectangle {
          anchors.centerIn: parent
          width: root.cell - 2; height: root.cell - 2
          radius: 8
          color: root.ink
          opacity: mouse.containsMouse ? 0.12 : 0
        }
        IconImage {
          anchors.centerIn: parent
          implicitSize: root.icon
          asynchronous: false
          source: Quickshell.iconPath(String(slot.modelData.icon || ""), "application-x-executable")
        }
        Rectangle {
          visible: slot.modelData.active
          anchors.horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
          anchors.verticalCenter: root.vertical ? parent.verticalCenter : undefined
          anchors.bottom: root.vertical ? undefined : parent.bottom
          anchors.left: root.vertical ? parent.left : undefined
          width: root.vertical ? 2 : 12
          height: root.vertical ? 12 : 2
          radius: 1
          color: root.ink
        }
        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: if (root.bar) root.bar.showTooltip(slot, slot.modelData.name)
          onExited: if (root.bar) root.bar.hideTooltip(slot)
          onClicked: {
            if (slot.modelData.kind === "app")
              Quickshell.execDetached(["bash", "-c", "uwsm-app -- gtk-launch \"$1\"", "taskbar", slot.modelData.id])
            else
              Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ window = 'address:" + slot.modelData.address + "' }))"])
          }
        }
      }
    }
  }
}
