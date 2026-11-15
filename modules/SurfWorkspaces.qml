import QtQuick
import Quickshell
import Quickshell.Hyprland
import "SurfIcons.js" as Icons

// Столы surface (по мотивам surface-dots, snes19xx — bars/TopBar.qml; README разрешает брать со ссылкой) — модуль бара
// kamradsmeshnyavy.bar. Пилюля с десятью столами: у занятого — значки его окон (Nerd Font по классу окна), у пустого —
// точка. Под текущим едет пилюля акцента, под наведённым — полупрозрачная пилюля с перелётом, наведённый стол
// приподнимается. Окно, просящее внимания, мигает красным и жёлтым. Клик — перейти, колесо — соседний стол.
// settings.count — сколько столов (10).
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 40
  readonly property int count: Number(settings && settings.count) || 10
  readonly property SurfPal pal: SurfPal {}

  readonly property int active: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
  property int hoverId: 0
  function wins(id) {
    var w = Hyprland.workspaces.values.find(function(x) { return x.id === id })
    return w ? w.toplevels.values : []
  }
  function clsOf(t) {
    var o = t && t.lastIpcObject
    var c = o && (o["class"] || o.initialClass || o.initialTitle) || (t && t.wayland && t.wayland.appId) || (t && t.title) || ""
    return String(c)
  }
  function go(ws) { Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = '" + ws + "' }))"]) }

  implicitWidth: box.implicitWidth
  implicitHeight: across

  SurfPill {
    id: box
    anchors.verticalCenter: parent.verticalCenter
    shimmer: false
    hoverFill: false
    pad: 11
    scale: 1
    implicitWidth: row.width + 22
    Item {
    id: lane
    width: row.width; height: 34
    // пилюля текущего стола
    Rectangle {
      readonly property Item t: rep.count >= root.active && root.active > 0 ? rep.itemAt(root.active - 1) : null
      visible: !!t
      x: t ? t.x : 0
      width: t ? t.width : 0
      height: 22
      y: (lane.height - height) / 2
      radius: 13
      color: root.pal.accent
      Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
      Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }
    // пилюля наведённого стола
    Rectangle {
      readonly property Item t: root.hoverId > 0 && root.hoverId !== root.active ? rep.itemAt(root.hoverId - 1) : null
      opacity: t ? 1 : 0
      x: t ? t.x : x
      width: t ? t.width : width
      height: 25
      y: (lane.height - height) / 2
      radius: 13
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: root.pal.alpha(root.pal.accent, 0.35) }
        GradientStop { position: 0.45; color: root.pal.alpha(root.pal.accent, 0.55) }
        GradientStop { position: 1.0; color: root.pal.alpha(root.pal.accent, 0.35) }
      }
      Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
      Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
    }
    Row {
      id: row
      spacing: 2
      Repeater {
        id: rep
        model: root.count
        Item {
          id: ws
          required property int index
          readonly property int wid: index + 1
          readonly property bool on: wid === root.active
          readonly property var list: root.wins(wid)
          readonly property bool hov: root.hoverId === wid
          width: list.length > 0 ? list.length * 22 + 12 : 26
          height: 34
          y: !on && hov ? -2 : 0
          scale: !on && hov ? 1.1 : 1
          Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
          Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
          Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
          readonly property color ink: on ? root.pal.onAccent : hov ? (root.pal.dark ? "#f2f2f2" : root.pal.accent) : root.pal.glyph
          Text {
            anchors.centerIn: parent
            visible: ws.list.length === 0
            text: "•"
            color: ws.ink
            font.family: root.pal.icons
            font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: 140 } }
          }
          Row {
            anchors.centerIn: parent
            visible: ws.list.length > 0
            Repeater {
              model: ws.list
              Item {
                required property var modelData
                width: 22; height: 22
                Text {
                  id: g
                  anchors.centerIn: parent
                  text: Icons.iconFor(root.clsOf(parent.modelData))
                  font.family: root.pal.icons
                  font.pixelSize: 18
                  color: parent.modelData && parent.modelData.urgent ? flash.c : ws.ink
                  scale: ws.on && ws.hov ? 1.25 : 1
                  Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                }
                QtObject {
                  id: flash
                  property color c: root.pal.glyph
                  property SequentialAnimation a: SequentialAnimation {
                    running: !!(g.parent.modelData && g.parent.modelData.urgent)
                    loops: Animation.Infinite
                    ColorAnimation { target: flash; property: "c"; to: "#e67e80"; duration: 200 }
                    ColorAnimation { target: flash; property: "c"; to: "#dbbc7f"; duration: 200 }
                  }
                }
              }
            }
          }
          HoverHandler {
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: { if (hovered) root.hoverId = ws.wid; else if (root.hoverId === ws.wid) root.hoverId = 0 }
          }
          // клик приходит от бара (его область нажатий поверх модуля зовёт triggerPress зарегистрированной цели)
          function triggerPress(button) { root.go(ws.wid) }
          property BarClick click: BarClick { bar: root.bar; target: ws }
        }
      }
    }
    }
  }
  WheelHandler { onWheel: function(e) { root.go(e.angleDelta.y > 0 ? "e-1" : "e+1") } }
}
