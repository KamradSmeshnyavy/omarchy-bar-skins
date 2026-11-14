import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons

// Язычки рамки Vitreus (по мотивам Vitreus, MIT; код свой): посередине верхней и нижней кромки рамки (кроме кромки с
// баром) при наведении из рамки вырастает язычок 81 × 23 с тремя точками, вогнутыми изгибами вливаясь в неё. Верхний
// открывает лаунчер, нижний — Prefs (Super+Alt+I). Скин: "tabs": true; у стекла (vitreus) язычок — то же жидкое стекло,
// что и рамка, у сплошной рамки — пластик цвета бара с контуром. Своё окно слоя Top: язычок ложится поверх окон.
Scope {
  id: tabs

  required property var screen
  required property var skin
  required property int barSize
  required property string position
  property bool shown: true

  readonly property int fw: skin.frameWidth
  function inset(edge) { return edge === position ? barSize : fw }

  Variants {
    model: tabs.skin.value("tabs") === true ? ["top", "bottom"].filter(e => e !== tabs.position) : []

    delegate: Component {
      PanelWindow {
        id: win
        required property string modelData
        readonly property bool atTop: modelData === "top"
        readonly property real tw: 81
        readonly property real th: 23
        readonly property real f: 11
        // середина рабочей области по горизонтали
        readonly property real workL: tabs.inset("left")
        readonly property real workW: (tabs.screen ? tabs.screen.width : 0) - tabs.inset("left") - tabs.inset("right")
        readonly property real marginL: Math.round(workL + (workW - implicitWidth) / 2)
        readonly property string command: atTop ? "omarchy-shell omarchy.dock apps" : "omarchy-shell widgets togglePrefs"

        screen: tabs.screen
        visible: tabs.shown
        anchors { top: win.atTop; bottom: !win.atTop; left: true }
        margins.left: marginL
        implicitWidth: tw + 2 * f + 24
        implicitHeight: tabs.fw + th + 14
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        surfaceFormat.opaque: false
        WlrLayershell.namespace: "omarchy-bar-tab"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // в покое ловит только полоску рамки над язычком, раскрытый — и сам язычок (zone растёт вместе с ним; не body:
        // у нижней кромки он отражён, и область ввода по нему выходит пустой)
        mask: Region { item: zone }

        property real g: hover.hovered ? 1 : 0
        Behavior on g { NumberAnimation { duration: win.g > 0.5 ? 180 : 320; easing.type: win.g > 0.5 ? Easing.InCubic : Easing.OutBack; easing.overshoot: 1.6 } }

        Item { id: zone; x: win.f + 12; width: win.tw; height: tabs.fw + 4 + (win.th + 4) * Math.min(1, win.g * 3); y: win.atTop ? 0 : parent.height - height }

        // стекло: язычок и кусок кромки рамки — одна фигура (кромка шире окна, её концы не видны). Не в body: у нижней
        // кромки фигуру считаем сами, а не отражаем — иначе обои под стеклом перевернутся. Саму кромку рисует рамка:
        // стекло язычка обрезано по ней с нахлёстом 3 px (закрыть светлый ободок рамки на стыке), иначе кусок кромки
        // в окне язычка светлее остальной рамки.
        Item {
          readonly property real cut: Math.max(0, tabs.fw - 3)
          clip: true
          y: win.atTop ? cut : 0
          width: win.width
          height: win.height - cut
        Loader {
          active: tabs.skin.vitreus
          y: win.atTop ? -parent.cut : 0
          width: win.width
          height: win.height
          sourceComponent: LiquidGlass {
            readonly property real h: Math.max(0, win.th * win.g)
            readonly property real x0: win.f + 12
            visible: h > 0.5
            active: visible
            screenOrigin: Qt.point(win.marginL, win.atTop ? 0 : (tabs.screen ? tabs.screen.height : 0) - win.height)
            belowWindows: true
            tintColor: Qt.rgba(tabs.skin.backgroundColor.r, tabs.skin.backgroundColor.g, tabs.skin.backgroundColor.b, 1)
            radius: Math.min(9, h / 2)
            panelRect: win.atTop ? Qt.rect(x0, tabs.fw - 2, win.tw, h + 2) : Qt.rect(x0, win.height - tabs.fw - h, win.tw, h + 2)
            joinRect: win.atTop ? Qt.rect(-60, -30, win.width + 120, tabs.fw + 30) : Qt.rect(-60, win.height - tabs.fw, win.width + 120, tabs.fw + 30)
            joinRadius: 0
            joinK: win.f * Math.min(1, h / 8)
          }
        }
        }

        // содержимое рисуется для верхней кромки; у нижней — отражено по вертикали
        Item {
          id: body
          anchors.fill: parent
          transform: Scale { origin.y: body.height / 2; yScale: win.atTop ? 1 : -1 }

          HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: Quickshell.execDetached(["bash", "-c", win.command]) }

          readonly property real x0: win.f + 12
          readonly property real h: Math.max(0, win.th * win.g)

          // пластик: заливка (заходит на кромку рамки и закрывает её контур) и контур без верхней линии
          Shape {
            visible: !tabs.skin.vitreus && body.h > 0.5
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real bw: tabs.skin.borderWidth
            readonly property real fi: Math.min(win.f, body.h)
            readonly property real r: Math.min(7, body.h / 2)
            readonly property real y0: tabs.fw
            ShapePath {
              fillColor: tabs.skin.backgroundColor
              strokeWidth: -1
              startX: body.x0 - win.f; startY: shape.y0 - shape.bw - 0.5
              PathLine { x: body.x0 - win.f; y: shape.y0 }
              PathQuad { x: body.x0; y: shape.y0 + shape.fi; controlX: body.x0; controlY: shape.y0 }
              PathLine { x: body.x0; y: shape.y0 + body.h - shape.r }
              PathQuad { x: body.x0 + shape.r; y: shape.y0 + body.h; controlX: body.x0; controlY: shape.y0 + body.h }
              PathLine { x: body.x0 + win.tw - shape.r; y: shape.y0 + body.h }
              PathQuad { x: body.x0 + win.tw; y: shape.y0 + body.h - shape.r; controlX: body.x0 + win.tw; controlY: shape.y0 + body.h }
              PathLine { x: body.x0 + win.tw; y: shape.y0 + shape.fi }
              PathQuad { x: body.x0 + win.tw + win.f; y: shape.y0; controlX: body.x0 + win.tw; controlY: shape.y0 }
              PathLine { x: body.x0 + win.tw + win.f; y: shape.y0 - shape.bw - 0.5 }
            }
            ShapePath {
              fillColor: "transparent"
              strokeColor: shape.bw > 0 ? tabs.skin.borderColor : "transparent"
              strokeWidth: shape.bw > 0 ? shape.bw : -1
              startX: body.x0 - win.f - 2; startY: shape.y0 - shape.bw / 2
              PathLine { x: body.x0 - win.f; y: shape.y0 - shape.bw / 2 }
              PathQuad { x: body.x0 - shape.bw / 2; y: shape.y0 + shape.fi; controlX: body.x0 - shape.bw / 2; controlY: shape.y0 - shape.bw / 2 }
              PathLine { x: body.x0 - shape.bw / 2; y: shape.y0 + body.h - shape.r }
              PathQuad { x: body.x0 + shape.r; y: shape.y0 + body.h + shape.bw / 2; controlX: body.x0 - shape.bw / 2; controlY: shape.y0 + body.h + shape.bw / 2 }
              PathLine { x: body.x0 + win.tw - shape.r; y: shape.y0 + body.h + shape.bw / 2 }
              PathQuad { x: body.x0 + win.tw + shape.bw / 2; y: shape.y0 + body.h - shape.r; controlX: body.x0 + win.tw + shape.bw / 2; controlY: shape.y0 + body.h + shape.bw / 2 }
              PathLine { x: body.x0 + win.tw + shape.bw / 2; y: shape.y0 + shape.fi }
              PathQuad { x: body.x0 + win.tw + win.f; y: shape.y0 - shape.bw / 2; controlX: body.x0 + win.tw + shape.bw / 2; controlY: shape.y0 - shape.bw / 2 }
              PathLine { x: body.x0 + win.tw + win.f + 2; y: shape.y0 - shape.bw / 2 }
            }
            id: shape
          }

          // три точки
          Row {
            spacing: 6
            x: body.x0 + (win.tw - width) / 2
            y: tabs.fw + body.h / 2 - height / 2
            opacity: Math.max(0, (win.g - 0.4) / 0.6)
            Repeater {
              model: 3
              Rectangle { width: 5; height: 5; radius: 2.5; color: Commons.Color.foreground; opacity: 0.75 }
            }
          }
        }
      }
    }
  }
}
