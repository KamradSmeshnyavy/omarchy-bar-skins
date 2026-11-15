import QtQuick
import Quickshell
import Quickshell.Io

// Кнопка лаунчера surface (по мотивам surface-dots, snes19xx — bars/TopBar.qml; README разрешает брать со ссылкой):
// синий глиф Arch, при наведении наклоняется на −14°, подрастает и подскакивает, под ним — круглая подсветка.
// Левый клик — лаунчер приложений, правый — тёмная ↔ светлая тема surface (как его правый клик по глифу).
// settings.command — своя команда левого клика; settings.icon — свой глиф.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 40
  readonly property SurfPal pal: SurfPal {}
  readonly property color blue: pal.dark ? "#89b4fa" : "#1e66f5"

  implicitWidth: 36
  implicitHeight: across

  property string themeName: ""
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: root.themeName = text().trim()
  }

  Rectangle {
    anchors.centerIn: parent
    width: 36; height: 36; radius: 18
    color: root.blue
    opacity: hov.hovered ? 0.08 : 0
    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
  }
  Text {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: hov.hovered ? -2 : 0
    text: String(root.settings && root.settings.icon || "")
    color: root.blue
    font.family: root.pal.icons
    font.pixelSize: 21
    rotation: hov.hovered ? -14 : 0
    scale: hov.hovered ? 1.2 : 1
    Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
    Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
  }
  HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }

  function triggerPress(button) {
    if (button === Qt.RightButton) {
      var t = root.themeName.indexOf("surface-") === 0 ? root.themeName : (root.pal.dark ? "surface-dark" : "surface-light")
      Quickshell.execDetached(["omarchy", "theme", "set", /light/.test(t) ? t.replace("light", "dark") : t.replace("dark", "light")])
    } else {
      Quickshell.execDetached(["bash", "-c", String(root.settings && root.settings.command || "omarchy-menu toggle root")])
    }
  }
}
