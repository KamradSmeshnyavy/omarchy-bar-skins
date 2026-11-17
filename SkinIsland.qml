import QtQuick

// Остров под одной секцией бара в форме islands. Занимает границы `target`
// плюс отступ скина; пустая секция острова не рисует.
Rectangle {
  id: island

  required property var skin
  required property Item target
  required property bool vertical
  property bool transparent: false
  // Явные границы (центр с якорем собирается из нескольких списков).
  property real spanStart: target ? (vertical ? target.y : target.x) : 0
  property real spanEnd: target ? (vertical ? target.y + target.height : target.x + target.width) : 0

  readonly property int pad: Math.max(skin.islandGap, 6)
  // Форма окна, в котором остров (compact может её сменить).
  readonly property Item host: {
    var p = parent
    while (p && p.skinHost !== true) p = p.parent
    return p || null
  }
  readonly property string shape: host ? host.skinShape : skin.shape

  visible: skin.islandShape(shape) && target !== null && target.visible && spanEnd - spanStart > 0
  z: -1

  // notches: остров уходит за край экрана на радиус (окно его обрезает) — скруглены только углы к экрану.
  readonly property bool notch: shape === "notches" && !vertical
  readonly property bool atBottom: skin.position === "bottom"
  x: vertical ? 0 : spanStart - pad
  y: vertical ? spanStart - pad : notch && !atBottom ? -radius : 0
  width: vertical ? parent.width : spanEnd - spanStart + 2 * pad
  height: vertical ? spanEnd - spanStart + 2 * pad : parent.height + (notch ? radius : 0)

  radius: skin.radiusFor(vertical ? width : parent.height, "islands")
  color: transparent || skin.vitreus ? "transparent" : skin.backgroundColor
  border.width: skin.vitreus ? 0 : skin.borderWidth
  border.color: skin.borderColor

  gradient: skin.hasGradient && !transparent && !skin.vitreus ? islandGradient : null

  // vitreus: вырез — стекло, вливающееся в край экрана вогнутыми изгибами (перешеек к полоске у края)
  LiquidGlass {
    visible: island.skin.vitreus && !island.transparent && island.visible
    active: visible
    anchors.fill: parent
    radius: island.radius
    layerNamespace: "omarchy-bar"
    belowWindows: true
    tintColor: Qt.rgba(island.skin.backgroundColor.r, island.skin.backgroundColor.g, island.skin.backgroundColor.b, 1)
    bleed: island.notch ? 30 : 0
    joinRect: island.notch ? Qt.rect(-30, island.atBottom ? island.height - 2 : island.radius, island.width + 60, 2) : Qt.rect(0, 0, 0, 0)
    joinRadius: 1
    joinK: island.notch ? 26 : 0
  }
  // жёсткая тень острова (скин hardShadow или общая тень панелей — BarSkin.hardShadow): плашка под островом
  Rectangle {
    visible: island.skin.hardShadow > 0 && !island.transparent && !island.skin.vitreus && !island.notch
    z: -1
    x: island.skin.hardShadow
    y: island.skin.hardShadow
    width: island.width
    height: island.height
    radius: island.radius
    color: Qt.rgba(island.skin.hardShadowColor.r, island.skin.hardShadowColor.g, island.skin.hardShadowColor.b, 1)
  }
  // brackets: уголки-скобки HUD на углах острова (Space, elifouts/Dotfiles — его Pill.qml Bracket)
  Repeater {
    model: island.skin.brackets > 0 && !island.transparent ? 4 : 0
    Item {
      required property int index
      readonly property int s: island.skin.brackets
      readonly property bool atRight: index % 2 === 1
      readonly property bool atBottom: index > 1
      x: atRight ? island.width - s : 0
      y: atBottom ? island.height - s : 0
      width: s; height: s
      Rectangle { width: parent.s; height: 1; y: parent.atBottom ? parent.s - 1 : 0; color: island.skin.bracketColor }
      Rectangle { width: 1; height: parent.s; x: parent.atRight ? parent.s - 1 : 0; color: island.skin.bracketColor }
    }
  }
  Gradient {
    id: islandGradient
    orientation: island.vertical || island.skin.gradientVertical ? Gradient.Vertical : Gradient.Horizontal
    GradientStop { position: 0; color: island.skin.backgroundColor }
    GradientStop { position: 1; color: island.skin.gradientColor }
  }
}
