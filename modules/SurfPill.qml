import QtQuick
import qs.Commons as Commons

// Пилюля бара surface (по мотивам surface-dots, snes19xx — bars/TopBarItem.qml; README разрешает брать со ссылкой):
// скруглённая подложка цвета карточки (78 %), при наведении — подсветка и косой блик, пробегающий слева направо,
// нажатие — лёгкое сжатие. Содержимое — дети пилюли (по центру). Общая часть модулей Surf*.qml.
Item {
  id: pill
  default property alias content: inner.data
  readonly property SurfPal pal: SurfPal {}
  property color fill: pal.card
  property bool shimmer: true
  property bool hoverFill: true
  property real pad: 12
  readonly property bool hovered: hov.hovered
  property bool pressed: false
  readonly property real contentWidth: inner.childrenRect.width

  implicitWidth: inner.childrenRect.width + pad * 2
  implicitHeight: 34
  scale: pressed ? 0.97 : hovered ? 1.02 : 1
  Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: height / 2
    color: pill.fill
    clip: true
    Behavior on color { ColorAnimation { duration: 180 } }
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: pill.pal.dark ? "#ffffff" : "#000000"
      opacity: !pill.hoverFill ? 0 : pill.pressed ? 0.18 : pill.hovered ? 0.1 : 0
      Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    // косой блик: при наведении пробегает по пилюле
    Rectangle {
      id: glint
      visible: pill.shimmer
      width: 44; height: parent.height * 2
      y: -parent.height / 2
      x: -60
      rotation: 20
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: pill.pal.dark ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.1) }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }
    layer.enabled: true
  }
  NumberAnimation { id: sweep; target: glint; property: "x"; from: -60; to: pill.width + 20; duration: 650; easing.type: Easing.OutCubic }
  onHoveredChanged: if (hovered && shimmer) sweep.restart()

  Item {
    id: inner
    anchors.centerIn: parent
    width: childrenRect.width
    height: childrenRect.height
  }
  HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
}
