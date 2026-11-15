import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Док surface (по мотивам режима таскбара surface-dots, snes19xx — bars/TaskBar.qml, «dock mode»; README разрешает
// брать со ссылкой; код свой) — модуль бара kamradsmeshnyavy.bar для раскладки surface-task. Пока бар в compact
// (скин surface-task: compact "empty" — на столе нет окон), по центру полосы: синий глиф Arch (лаунчер), тонкая черта,
// закреплённые приложения дока Omarchy (shell.json → dock.pinned, `omarchy dock pin`; при наведении значок
// подрастает и приподнимается, клик — запуск) и время жирным (клик — дашборд). Когда окна есть — модуль пустой,
// бар показывает обычную раскладку.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 50
  readonly property SurfPal pal: SurfPal {}

  // в режиме дока? — хозяин секций бара (Loader с skinHost) знает compact
  readonly property var host: {
    var p = root.parent
    while (p && p.skinHost !== true) p = p.parent
    return p
  }
  readonly property bool dock: !!host && host.skinCompact === true

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
  readonly property var apps: pinned.map(function(id) {
    var e = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
    return e ? { id: id, name: e.name, icon: e.icon } : null
  }).filter(function(x) { return x !== null })

  property date now: new Date()
  Timer { running: root.dock; repeat: true; interval: 1000; triggeredOnStart: true; onTriggered: root.now = new Date() }

  visible: dock
  implicitWidth: dock ? row.implicitWidth + 8 : 0
  implicitHeight: across
  opacity: dock ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }

  Row {
    id: row
    anchors.centerIn: parent
    anchors.verticalCenterOffset: 2
    spacing: 2

    // лаунчер
    Item {
      id: launch
      width: 48; height: 48
      anchors.verticalCenter: parent.verticalCenter
      Rectangle { anchors.centerIn: parent; width: 40; height: 40; radius: 9; color: root.pal.dark ? "#ffffff" : "#000000"; opacity: lh.hovered ? 0.09 : 0 }
      Text {
        anchors.centerIn: parent
        text: ""
        color: root.pal.dark ? "#89b4fa" : "#1e66f5"
        font.family: root.pal.icons
        font.pixelSize: 24
        scale: lh.hovered ? 1.12 : 1
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
      }
      HoverHandler { id: lh; cursorShape: Qt.PointingHandCursor }
      function triggerPress(button) { Quickshell.execDetached(["bash", "-c", String(root.settings && root.settings.command || "omarchy-menu toggle root")]) }
      property BarClick click: BarClick { bar: root.bar; target: launch }
    }
    Rectangle { width: 1; height: 32; anchors.verticalCenter: parent.verticalCenter; color: root.pal.dark ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15) }
    Item { width: 4; height: 1 }

    // закреплённые приложения
    Repeater {
      model: root.apps
      Item {
        id: app
        required property var modelData
        width: 46; height: 48
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        IconImage {
          anchors.horizontalCenter: parent.horizontalCenter
          y: (parent.height - height) / 2 - (ah.hovered ? 4 : 0)
          implicitSize: 32
          scale: ah.hovered ? 1.15 : 1
          asynchronous: false
          source: Quickshell.iconPath(String(app.modelData.icon || ""), "application-x-executable")
          Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
          Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        }
        HoverHandler {
          id: ah
          cursorShape: Qt.PointingHandCursor
          onHoveredChanged: if (root.bar) { if (hovered) root.bar.showTooltip(app, app.modelData.name); else root.bar.hideTooltip(app) }
        }
        function triggerPress(button) { Quickshell.execDetached(["bash", "-c", "uwsm-app -- gtk-launch \"$1\"", "surf-dock", app.modelData.id]) }
        property BarClick click: BarClick { bar: root.bar; target: app }
      }
    }
    Item { width: 4; height: 1 }

    // время
    Item {
      id: clock
      width: tm.implicitWidth + 24; height: 32
      anchors.verticalCenter: parent.verticalCenter
      scale: ch.hovered ? 1.05 : 1
      Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
      Rectangle { anchors.fill: parent; radius: 9; color: root.pal.dark ? Qt.rgba(1, 1, 1, 0.094) : Qt.rgba(0, 0, 0, 0.094); visible: ch.hovered }
      Text {
        id: tm
        anchors.centerIn: parent
        text: Qt.formatDateTime(root.now, root.settings && root.settings.hour12 === false ? "HH:mm" : "h:mm AP")
        color: root.pal.text
        font.family: root.pal.font
        font.pixelSize: 13
        font.bold: true
      }
      HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
      function triggerPress(button) { Quickshell.execDetached(["omarchy-shell", "widgets", "toggleDashboard"]) }
      property BarClick click: BarClick { bar: root.bar; target: clock }
    }
  }
}
