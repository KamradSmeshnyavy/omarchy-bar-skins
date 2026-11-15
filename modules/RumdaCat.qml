import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

// Кот Rumda — свой рисунок (у Rumda — картинка, здесь векторный кот из фигур): сидит на верхнем краю бара,
// хвост трубой за спиной покачивает кончиком, кот моргает и иногда дёргает ухом. Смена темы — кот
// спрыгивает вниз за кромку и через секунду возвращается. Модуль ставят первым в верхнюю группу бара: сам он
// почти не занимает места, кот рисуется над полосой (settings.lift — на сколько выше начала группы, по умолчанию 8).
// Цвет — светлый акцент темы (на тёмном баре — песочный, на светлом — карамельный).
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 48
  readonly property real lift: Number(settings && settings.lift) || 8
  readonly property color fur: Qt.lighter(Commons.Color.accent, 1.18)
  readonly property color shade: Qt.darker(Commons.Color.accent, 1.15)
  readonly property color eye: bar && bar.background ? bar.background : Commons.Color.background

  implicitWidth: across
  implicitHeight: 1

  // смена темы — кот прыгает вниз и возвращается
  property string themeName: ""
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: { var t = text().trim(); if (root.themeName && t !== root.themeName) hop.restart(); root.themeName = t }
  }
  property real drop: 0          // 0 — сидит, 1 — спрыгнул
  SequentialAnimation {
    id: hop
    NumberAnimation { target: root; property: "drop"; to: 1; duration: 380; easing.type: Easing.InBack }
    PauseAnimation { duration: 900 }
    NumberAnimation { target: root; property: "drop"; to: 0; duration: 520; easing.type: Easing.OutBack }
  }

  // моргание и ухо
  property real blink: 0
  property real ear: 0
  SequentialAnimation on blink {
    loops: Animation.Infinite
    PauseAnimation { duration: 3800 }
    NumberAnimation { to: 1; duration: 90 }
    NumberAnimation { to: 0; duration: 120 }
    PauseAnimation { duration: 2600 }
    NumberAnimation { to: 1; duration: 90 }
    NumberAnimation { to: 0; duration: 120 }
    NumberAnimation { to: 1; duration: 90 }
    NumberAnimation { to: 0; duration: 120 }
  }
  SequentialAnimation on ear {
    loops: Animation.Infinite
    PauseAnimation { duration: 7000 }
    NumberAnimation { to: 1; duration: 80 }
    NumberAnimation { to: 0; duration: 160 }
  }
  // хвост: медленное покачивание
  property real swing: 0
  SequentialAnimation on swing {
    loops: Animation.Infinite
    NumberAnimation { to: 1; duration: 1600; easing.type: Easing.InOutSine }
    NumberAnimation { to: -1; duration: 1600; easing.type: Easing.InOutSine }
  }

  // кот: 46 × 52, сидит так, что лапы на верхней кромке бара
  Item {
    id: cat
    width: 46; height: 52
    x: (root.width - width) / 2 - 2
    y: -height - root.lift + root.drop * 70
    opacity: 1 - root.drop * 0.9

    // хвост поднимается за спиной справа и покачивает кончиком (рисуется до тела — основание прячется за ним);
    // наружу за кромку бара не свисает: окно бара кончается у его края и обрезало бы его
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: "transparent"; strokeColor: root.fur; strokeWidth: 4.5; capStyle: ShapePath.RoundCap
        startX: 32; startY: 48
        PathCubic { x: 41 + 3 * root.swing; y: 20; control1X: 46; control1Y: 44; control2X: 47; control2Y: 30 }
        PathQuad { x: 37 + 4 * root.swing; y: 16 - root.swing; controlX: 39 + 4 * root.swing; controlY: 14 }
      }
    }
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      // тело и голова одним силуэтом
      ShapePath {
        fillColor: root.fur; strokeWidth: -1
        startX: 8; startY: 52
        // спина и бок
        PathCubic { x: 10; y: 28; control1X: 2; control1Y: 46; control2X: 4; control2Y: 34 }
        // шея к голове
        PathCubic { x: 9; y: 16; control1X: 12; control1Y: 25; control2X: 8; control2Y: 21 }
        // левое ухо
        PathLine { x: 10; y: 2 - 3 * root.ear }
        PathLine { x: 17; y: 9 }
        // темя
        PathCubic { x: 29; y: 9; control1X: 21; control1Y: 7; control2X: 25; control2Y: 7 }
        // правое ухо
        PathLine { x: 36; y: 2 }
        PathLine { x: 37; y: 16 }
        // щека и грудь
        PathCubic { x: 31; y: 30; control1X: 38; control1Y: 23; control2X: 35; control2Y: 28 }
        PathCubic { x: 38; y: 52; control1X: 37; control1Y: 36; control2X: 40; control2Y: 46 }
        PathLine { x: 8; y: 52 }
      }
      // глаза: зажмуриваются при моргании
      ShapePath {
        fillColor: root.eye; strokeWidth: -1
        PathAngleArc { centerX: 17.5; centerY: 17; radiusX: 2.2; radiusY: Math.max(0.3, 2.6 * (1 - root.blink)); startAngle: 0; sweepAngle: 360 }
        PathAngleArc { moveToStart: true; centerX: 28.5; centerY: 17; radiusX: 2.2; radiusY: Math.max(0.3, 2.6 * (1 - root.blink)); startAngle: 0; sweepAngle: 360 }
      }
      // нос
      ShapePath {
        fillColor: root.shade; strokeWidth: -1
        startX: 21.5; startY: 21
        PathLine { x: 24.5; y: 21 }
        PathLine { x: 23; y: 23 }
        PathLine { x: 21.5; y: 21 }
      }
      // лапки
      ShapePath {
        fillColor: "transparent"; strokeColor: root.shade; strokeWidth: 1.4; capStyle: ShapePath.RoundCap
        startX: 18; startY: 52
        PathLine { x: 18; y: 45 }
        PathMove { x: 27; y: 52 }
        PathLine { x: 27; y: 45 }
      }
    }
  }
}
