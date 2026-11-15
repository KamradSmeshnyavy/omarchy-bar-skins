import QtQuick
import QtQuick.Shapes
import qs.Commons as Commons

// Украшение полосы Rumda (по мотивам hexonide/rumda; код и рисунок свои): две изогнутые песочные «волны» поперёк
// бара — settings.flip: true зеркалит их. На светлой теме не видно (Rumda рисует их только на тёмном баре).
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 48
  readonly property bool flip: settings && settings.flip === true
  readonly property color sand: Commons.Color.foreground
  readonly property bool darkBar: { var b = bar && bar.background ? bar.background : Commons.Color.background; return 0.299 * b.r + 0.587 * b.g + 0.114 * b.b < 0.4 }
  implicitWidth: across
  implicitHeight: Number(settings && settings.length) || 90
  Shape {
    visible: root.darkBar
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    transform: Scale { origin.y: root.height / 2; yScale: root.flip ? -1 : 1 }
    ShapePath {
      fillColor: root.sand; strokeWidth: -1
      startX: 2; startY: root.height * 0.55
      PathCubic { x: root.width - 2; y: root.height * 0.12; control1X: root.width * 0.3; control1Y: root.height * 0.35; control2X: root.width * 0.7; control2Y: root.height * 0.18 }
      PathLine { x: root.width - 2; y: root.height * 0.32 }
      PathCubic { x: 2; y: root.height * 0.78; control1X: root.width * 0.7; control1Y: root.height * 0.4; control2X: root.width * 0.3; control2Y: root.height * 0.58 }
      PathLine { x: 2; y: root.height * 0.55 }
    }
    ShapePath {
      fillColor: Qt.rgba(root.sand.r, root.sand.g, root.sand.b, 0.75); strokeWidth: -1
      startX: 2; startY: root.height * 0.95
      PathCubic { x: root.width - 2; y: root.height * 0.55; control1X: root.width * 0.35; control1Y: root.height * 0.8; control2X: root.width * 0.7; control2Y: root.height * 0.62 }
      PathLine { x: root.width - 2; y: root.height * 0.68 }
      PathCubic { x: 2; y: root.height * 1.0; control1X: root.width * 0.7; control1Y: root.height * 0.75; control2X: root.width * 0.35; control2Y: root.height * 0.9 }
    }
  }
}
