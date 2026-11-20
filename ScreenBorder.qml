import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
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
  // reserve — держать место под рамкой (exclusiveZone); frameShown — рисовать рамку (плавно гаснет)
  property bool reserve: true
  property bool frameShown: true
  property real frameFade: frameShown ? 1 : 0
  Behavior on frameFade { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

  readonly property int frameWidth: skin.frameWidth
  readonly property int radius: skin.frameRadius
  // Отступы рабочей области от краёв экрана: у края с баром — сам бар.
  function inset(edge) { return edge === position ? barSize : frameWidth }

  // Места стыков: карточки виджетов стола у кромки слиты с рамкой (kamradsmeshnyavy.widgets пишет
  // $XDG_RUNTIME_DIR/omarchy-merge-widgets[-float]-<экран>.json: [{ edge, a0, a1, f }] в px рабочей области). Слой
  // виджетов — под рамкой, поэтому контур рамки на стыке стирает она сама (вогнутые углы рисует карточка).
  readonly property string screenName: screen ? String(screen.name) : ""
  property var spots: []
  property var spotsFloat: []
  // и модули бара, вытащенные на стол (BarDeskPanel в Bar.qml)
  property var extraSpots: []
  readonly property var allSpots: spots.concat(spotsFloat, extraSpots)
  FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-merge-widgets-" + border.screenName + ".json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { border.spots = JSON.parse(text()) || [] } catch (e) { border.spots = [] } }
    onLoadFailed: border.spots = []
  }
  FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-merge-widgets-float-" + border.screenName + ".json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { border.spotsFloat = JSON.parse(text()) || [] } catch (e) { border.spotsFloat = [] } }
    onLoadFailed: border.spotsFloat = []
  }

  // Рябь: панель «капля» втянулась в бар (DripMotion в kamradsmeshnyavy.widgets пишет
  // $XDG_RUNTIME_DIR/omarchy-bar-ripple.json: { screen, x, y, t }) — по краю стекла бара и рамки расходятся волны, как у
  // Vitreus (ring 510 мс). Только у стеклянной рамки (vitreus); в покое шейдер не перерисовывается.
  property point rippleAt: Qt.point(0, 0)
  property real rippleT: 0
  NumberAnimation { id: rippleRun; target: border; property: "rippleT"; from: 0; to: 1; duration: 620 }
  FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-bar-ripple.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var r = JSON.parse(text())
        if (!r || (r.screen && r.screen !== border.screenName) || Date.now() - Number(r.t) > 1500) return
        border.rippleAt = Qt.point(Number(r.x) || 0, Number(r.y) || 0)
        rippleRun.restart()
      } catch (e) {}
    }
  }

  Variants {
    model: ["top", "bottom", "left", "right"].filter(e => e !== border.position)

    delegate: Component {
      PanelWindow {
        required property string modelData
        readonly property bool vertical: modelData === "left" || modelData === "right"

        screen: border.screen
        visible: border.shown && border.reserve
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

  // Слой окна задаётся только при создании: Variants пересоздаёт его при смене стекла (vitreus — Bottom, иначе Top),
  // иначе после живого переключения райса на Vitreus рамка оставалась в Top и закрывала модули бара.
  Variants {
    model: [border.skin.vitreus]

    delegate: Component {
      PanelWindow {
        id: overlay
        required property bool modelData

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
        // vitreus: стекло рамки — под окнами (они в рамку не заходят: её место зарезервировано), бар (Top) — над ним
        WlrLayershell.layer: modelData ? WlrLayer.Bottom : WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // vitreus: полоса бара и рамка — один кусок стекла (LiquidGlass): поле окна минус рабочая область со скруглёнными
        // углами; главная фигура — полоса бара. Окно рамки — на весь экран монитора, его угол и есть начало координат.
        LiquidGlass {
          visible: border.skin.vitreus
          active: visible
          anchors.fill: parent
          screenOrigin: Qt.point(0, 0)
          belowWindows: true
          tintColor: Qt.rgba(border.skin.backgroundColor.r, border.skin.backgroundColor.g, border.skin.backgroundColor.b, 1)
          radius: 0
          panelRect: border.position === "left" ? Qt.rect(0, 0, border.barSize, overlay.height)
            : border.position === "right" ? Qt.rect(overlay.width - border.barSize, 0, border.barSize, overlay.height)
            : border.position === "top" ? Qt.rect(0, 0, overlay.width, border.barSize)
            : Qt.rect(0, overlay.height - border.barSize, overlay.width, border.barSize)
          frameOn: true
          frameHole: Qt.rect(border.inset("left"), border.inset("top"), overlay.width - border.inset("left") - border.inset("right"),
                             overlay.height - border.inset("top") - border.inset("bottom"))
          frameHoleRadius: border.radius
          frameK: 0
          rippleAt: border.rippleAt
          rippleT: border.rippleT
          rippleAmp: rippleRun.running ? 4 : 0
        }

        LinearGradient {
          id: candyFill
          x1: 0; y1: 0; x2: overlay.width; y2: overlay.height
          GradientStop { position: 0; color: "#ffb3dc" }
          GradientStop { position: 0.38; color: "#cfc4ff" }
          GradientStop { position: 0.68; color: "#aab4ff" }
          GradientStop { position: 1; color: "#ffd0ea" }
        }
        Shape {
          visible: !border.skin.vitreus && border.frameFade > 0
          opacity: border.frameFade
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer

          ShapePath {
            id: path

            fillColor: border.skin.backgroundColor
            // UwU (skin candy): его пастельный градиент через весь экран
            fillGradient: border.skin.candy ? candyFill : null
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

          // Опциональный внутренний контур рамки (например, 1px #2a2a2a в скине dotmatrix).
          ShapePath {
            readonly property real bw: border.skin.borderWidth
            fillColor: "transparent"
            strokeColor: bw > 0 ? border.skin.borderColor : "transparent"
            strokeWidth: bw > 0 ? bw : -1

            Behavior on strokeColor { ColorAnimation { duration: 280; easing.type: Easing.InOutCubic } }

            PathRectangle {
              x: border.inset("left") - border.skin.borderWidth * 0.5
              y: border.inset("top") - border.skin.borderWidth * 0.5
              width: overlay.width - border.inset("left") - border.inset("right") + border.skin.borderWidth
              height: overlay.height - border.inset("top") - border.inset("bottom") + border.skin.borderWidth
              radius: border.radius + border.skin.borderWidth * 0.5
            }
          }
        }

        // разрывы контура на стыках (только у сплошной рамки с контуром; у стекла слияние рисует сама карточка)
        Repeater {
          model: !border.skin.vitreus && border.skin.borderWidth > 0 ? border.allSpots : []
          // Item, не Rectangle: внутри Rectangle имя border — его собственный контур, а не ScreenBorder
          Item {
            id: gapItem
            required property var modelData
            readonly property color col: border.skin.backgroundColor
            Rectangle { anchors.fill: parent; color: gapItem.col }
            readonly property string e: String(modelData.edge)
            readonly property bool horiz: e === "top" || e === "bottom"
            readonly property real bw: border.skin.borderWidth
            readonly property real f: Number(modelData.f) || 14
            readonly property real a0: Number(modelData.a0) - f * 0.5
            readonly property real a1: Number(modelData.a1) + f * 0.5
            x: horiz ? border.inset("left") + a0
              : e === "left" ? border.inset("left") - bw - 0.5 : overlay.width - border.inset("right") - 0.5
            y: !horiz ? border.inset("top") + a0
              : e === "top" ? border.inset("top") - bw - 0.5 : overlay.height - border.inset("bottom") - 0.5
            width: horiz ? a1 - a0 : bw + 1
            height: horiz ? bw + 1 : a1 - a0
          }
        }
      }
    }
  }

  // язычки рамки (скин "tabs": true)
  VitTabs {
    screen: border.screen
    skin: border.skin
    barSize: border.barSize
    position: border.position
    shown: border.shown
  }
}
