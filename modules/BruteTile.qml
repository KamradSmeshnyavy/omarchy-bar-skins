import QtQuick

// Плитка необрутализма для модулей Bruteon (по мотивам Bruteon, Darkkal44 — облик со скриншотов, код свой): заливка,
// контур 2 px цветом чернил, скругление 7 и жёсткая тень без размытия, сдвинутая вправо-вниз. При наведении тень
// подрастает, при нажатии плитка «вдавливается» в неё. Содержимое — дети плитки (по центру).
Item {
  id: tile
  default property alias content: face.data
  property color fill: "#efe0d6"
  property color ink: "#161110"
  property real radius: 7
  property real shadow: 2.5
  property bool flat: false               // без контура и тени (неактивные значки)
  property bool hovered: false
  property bool pressed: false
  readonly property real lift: flat ? 0 : pressed ? 0 : hovered ? shadow + 1 : shadow

  Rectangle {
    visible: !tile.flat
    x: tile.shadow; y: tile.shadow
    width: tile.width; height: tile.height
    radius: tile.radius
    color: tile.ink
  }
  Rectangle {
    id: face
    x: tile.shadow - tile.lift; y: tile.shadow - tile.lift
    width: tile.width; height: tile.height
    radius: tile.radius
    color: tile.fill
    border.width: tile.flat ? 0 : 2
    border.color: tile.ink
    Behavior on x { NumberAnimation { duration: 90 } }
    Behavior on y { NumberAnimation { duration: 90 } }
  }
}
