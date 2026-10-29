import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// skin: форма frame — рамка цвета бара по остальным краям экрана, внутренние углы
// рабочей области скруглены (как у caelestia; написано с нуля). Полосу бара рисует
// SkinFrame, здесь — всё остальное:
//   overlay   окно на весь экран поверх окон (слой Top), рисует рамку и углы, клики пропускает;
//   reserve   три невидимые полоски у других краёв — exclusiveZone, чтобы окна не заезжали под рамку.
Scope {
  id: border

  required property var screen
  required property var skin
  required property int barSize
  required property string position
  property bool shown: true

  readonly property int frameWidth: skin.frameWidth
  readonly property int radius: skin.frameRadius
  // Отступы рабочей области от краёв экрана: у края с баром — сам бар.
  function inset(edge) { return edge === position ? barSize : frameWidth }

  Variants {
    model: ["top", "bottom", "left", "right"].filter(e => e !== border.position)

    delegate: Component {
      PanelWindow {
        required property string modelData
        readonly property bool vertical: modelData === "left" || modelData === "right"

        screen: border.screen
        visible: border.shown
        anchors {
          top: modelData !== "bottom"
          bottom: modelData !== "top"
          left: modelData !== "right"
          right: modelData !== "left"
        }
        implicitWidth: vertical ? border.frameWidth : 0
        implicitHeight: vertical ? 0 : border.frameWidth
        exclusiveZone: border.frameWidth
        color: "transparent"
        surfaceFormat.opaque: false
        mask: Region {}
        WlrLayershell.namespace: "omarchy-bar-frame-reserve"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      }
    }
  }

  PanelWindow {
    id: overlay

    screen: border.screen
    visible: border.shown
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    mask: Region {}
    WlrLayershell.namespace: "omarchy-bar-frame"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        id: path

        fillColor: border.skin.backgroundColor
        fillRule: ShapePath.OddEvenFill
        strokeWidth: -1

        Behavior on fillColor { ColorAnimation { duration: 280; easing.type: Easing.InOutCubic } }

        // Внешний контур — экран без полосы бара (её рисует сам бар).
        PathRectangle {
          x: border.position === "left" ? border.barSize : 0
          y: border.position === "top" ? border.barSize : 0
          width: overlay.width - (border.position === "left" || border.position === "right" ? border.barSize : 0)
          height: overlay.height - (border.position === "top" || border.position === "bottom" ? border.barSize : 0)
        }
        // Внутренний — рабочая область со скруглёнными углами; even-odd вырезает её.
        PathRectangle {
          x: border.inset("left")
          y: border.inset("top")
          width: overlay.width - border.inset("left") - border.inset("right")
          height: overlay.height - border.inset("top") - border.inset("bottom")
          radius: border.radius
        }
      }
    }
  }
}
