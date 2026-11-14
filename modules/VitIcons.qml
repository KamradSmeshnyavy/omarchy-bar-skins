import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.Commons as Commons

// Группа иконок Vitreus (по мотивам natepayn3/Vitreus, MIT; код и рисунки свои) — модуль бара kamradsmeshnyavy.bar.
// Подложка-карточка (цвет текста бара на 8 %) и в ней иконки линиями: обзор столов, поиск (лаунчер), шестерёнка
// (Customizer), управление (панель Super+M). Какие и в каком порядке — settings.items (по умолчанию
// "overview,search,settings,controls"). Наведение — иконка светлеет и чуть растёт.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property int across: bar && bar.barSize ? bar.barSize : 32
  readonly property real k: Math.max(0.55, across / 62)
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : Commons.Color.foreground

  readonly property var actions: ({
    overview: ["omarchy-shell", "widgets", "toggleOverview"],
    search: ["omarchy-menu", "toggle", "root"],
    settings: ["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"],
    controls: ["omarchy-shell", "widgets", "toggleSettings"]
  })
  readonly property var items: String(settings && settings.items || "overview,search,settings,controls").split(",")
    .map(function(s) { return s.trim() }).filter(function(s) { return root.actions[s] !== undefined })

  readonly property real cell: 30 * k
  readonly property real inset: 4 * k
  readonly property real len: items.length * cell + 2 * inset
  readonly property real thick: cell + 2 * inset

  implicitWidth: vertical ? across : len + 8 * k
  implicitHeight: vertical ? len + 8 * k : across

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: root.vertical ? root.thick : root.len
    height: root.vertical ? root.len : root.thick
    radius: 10 * root.k
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
    border.width: 1
    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)

    Grid {
      anchors.centerIn: parent
      columns: root.vertical ? 1 : root.items.length
      Repeater {
        model: root.items
        Item {
          id: cellItem
          required property var modelData
          width: root.cell; height: root.cell
          Rectangle {
            anchors.fill: parent
            anchors.margins: 2 * root.k
            radius: 7 * root.k
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, hov.hovered ? 0.1 : 0)
            Behavior on color { ColorAnimation { duration: 140 } }
          }
          Shape {
            id: ico
            anchors.centerIn: parent
            width: 16 * root.k; height: 16 * root.k
            scale: hov.hovered ? 1.1 : 1
            opacity: hov.hovered ? 1 : 0.78
            Behavior on scale { NumberAnimation { duration: 140 } }
            preferredRendererType: Shape.CurveRenderer
            readonly property real s: width / 16
            readonly property real w: 1.6 * root.k
            readonly property string kind: cellItem.modelData

            // обзор: четыре скруглённые клетки
            ShapePath {
              strokeColor: ico.kind === "overview" ? root.fg : "transparent"; strokeWidth: ico.w; fillColor: "transparent"
              PathRectangle { x: 1.5 * ico.s; y: 1.5 * ico.s; width: 5.5 * ico.s; height: 5.5 * ico.s; radius: 1.5 * ico.s }
              PathRectangle { x: 9 * ico.s; y: 1.5 * ico.s; width: 5.5 * ico.s; height: 5.5 * ico.s; radius: 1.5 * ico.s }
              PathRectangle { x: 1.5 * ico.s; y: 9 * ico.s; width: 5.5 * ico.s; height: 5.5 * ico.s; radius: 1.5 * ico.s }
              PathRectangle { x: 9 * ico.s; y: 9 * ico.s; width: 5.5 * ico.s; height: 5.5 * ico.s; radius: 1.5 * ico.s }
            }
            // поиск: линза и ручка
            ShapePath {
              strokeColor: ico.kind === "search" ? root.fg : "transparent"; strokeWidth: ico.w; fillColor: "transparent"; capStyle: ShapePath.RoundCap
              PathAngleArc { centerX: 7 * ico.s; centerY: 7 * ico.s; radiusX: 5 * ico.s; radiusY: 5 * ico.s; startAngle: 0; sweepAngle: 360 }
              PathMove { x: 10.8 * ico.s; y: 10.8 * ico.s }
              PathLine { x: 14.5 * ico.s; y: 14.5 * ico.s }
            }
            // шестерёнка: кольцо и восемь зубцов
            ShapePath {
              strokeColor: ico.kind === "settings" ? root.fg : "transparent"; strokeWidth: ico.w; fillColor: "transparent"
              PathAngleArc { centerX: 8 * ico.s; centerY: 8 * ico.s; radiusX: 4.6 * ico.s; radiusY: 4.6 * ico.s; startAngle: 0; sweepAngle: 360 }
              PathAngleArc { moveToStart: true; centerX: 8 * ico.s; centerY: 8 * ico.s; radiusX: 1.8 * ico.s; radiusY: 1.8 * ico.s; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
              strokeColor: ico.kind === "settings" ? root.fg : "transparent"; strokeWidth: ico.w * 1.3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
              PathMultiline {
                paths: {
                  var out = [], s = ico.s
                  for (var i = 0; i < 8; i++) {
                    var a = i * Math.PI / 4
                    out.push([Qt.point(8 * s + Math.cos(a) * 5.4 * s, 8 * s + Math.sin(a) * 5.4 * s), Qt.point(8 * s + Math.cos(a) * 7 * s, 8 * s + Math.sin(a) * 7 * s)])
                  }
                  return out
                }
              }
            }
            // управление: два ползунка
            ShapePath {
              strokeColor: ico.kind === "controls" ? root.fg : "transparent"; strokeWidth: ico.w; fillColor: "transparent"; capStyle: ShapePath.RoundCap
              // линии прерываются у ручек
              PathMove { x: 1.5 * ico.s; y: 5 * ico.s }
              PathLine { x: 8 * ico.s; y: 5 * ico.s }
              PathMove { x: 13 * ico.s; y: 5 * ico.s }
              PathLine { x: 14.5 * ico.s; y: 5 * ico.s }
              PathMove { x: 1.5 * ico.s; y: 11 * ico.s }
              PathLine { x: 3 * ico.s; y: 11 * ico.s }
              PathMove { x: 8 * ico.s; y: 11 * ico.s }
              PathLine { x: 14.5 * ico.s; y: 11 * ico.s }
            }
            ShapePath {
              strokeColor: ico.kind === "controls" ? root.fg : "transparent"; strokeWidth: ico.w
              fillColor: "transparent"
              PathAngleArc { centerX: 10.5 * ico.s; centerY: 5 * ico.s; radiusX: 2.1 * ico.s; radiusY: 2.1 * ico.s; startAngle: 0; sweepAngle: 360 }
              PathAngleArc { moveToStart: true; centerX: 5.5 * ico.s; centerY: 11 * ico.s; radiusX: 2.1 * ico.s; radiusY: 2.1 * ico.s; startAngle: 0; sweepAngle: 360 }
            }
          }
          HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
          function triggerPress(button) { Quickshell.execDetached(root.actions[cellItem.modelData]) }
          // клики приходят от бара: поверх модуля — его область нажатий (перетаскивание), она зовёт triggerPress
          // у зарегистрированных целей под курсором
          property BarClick click: BarClick { bar: root.bar; target: cellItem }

        }
      }
    }
  }
}
