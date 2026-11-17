import QtQuick
import qs.Commons as Commons
import "dotmatrix" as DotMatrix
import "modules" as Mods

// Облик райса для чужого модуля бара (RiceLook.dresses): подложка под модулем в слоте ModuleSlot (Bar.qml) — та же,
// что у своих модулей этого райса, — и, где у райса свой цвет значков, перекраска модуля (ink, colorize):
//   bruteon   — пастельная плитка BruteTile с контуром и жёсткой тенью, значки и текст тёмные (цвет плитки — по
//               имени модуля, у модуля он не меняется при перестановке);
//   rumda     — карточка RumdaCard (смесь фона с текстом, рамка 2 px), при наведении светлее;
//   surface   — пилюля цвета карточки (78 %), при наведении подсветка;
//   cozytile  — значки и текст акцентом, справа — косая черта цвета язычков;
//   unit3     — тонкая черта слева (текст 8 %), как между его модулями справа, при наведении — лёгкая подложка;
//   yami      — квадратная ячейка, при наведении — текст 14 %;
//   vitreus   — скруглённая подложка (текст 10 %) при наведении, как у иконок Vitreus;
//   glyph     — круглая подложка (текст 8 %) при наведении;
//   dotmatrix — тонкий контур палитры DOT-MATRIX при наведении.
// Поля вдоль бара — padStart / padEnd; слот добавляет их к ширине (или высоте у вертикального бара) модуля.
Item {
  id: dress

  property string rice: ""
  property bool vertical: false
  property real across: 32          // толщина бара (barSize)
  property bool hovered: false
  property bool active: false       // открыта панель модуля
  property string name: ""          // id модуля — от него цвет плитки Bruteon
  property bool tray: false         // трей не перекрашивается: у значков приложений свои цвета
  property color fg: Commons.Color.foreground
  property color bg: Commons.Color.background
  property color accent: Commons.Color.accent
  property bool separators: true    // разделители между модулями (черты Cozytile и Unit-3) — только на баре, не на столе
  property var cozy: null           // палитра Cozytile (RiceLook.cozy): ink — значки, slash — косая черта

  readonly property bool hot: hovered || active
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  function mix(x, y, k) { return Qt.rgba(x.r + (y.r - x.r) * k, x.g + (y.g - x.g) * k, x.b + (y.b - x.b) * k, 1) }

  // ── поля и перекраска ──
  readonly property var pads: ({
    bruteon: [9, 12], rumda: [8, 8], surface: [12, 12], cozytile: [8, 30], unit3: [9, 8],
    yami: [6, 6], vitreus: [6, 6], glyph: [6, 6], dotmatrix: [6, 6]
  })
  readonly property real padStart: !pads[rice] ? 0 : separators ? pads[rice][0] : 8
  readonly property real padEnd: !pads[rice] ? 0 : separators ? pads[rice][1] : 8
  readonly property color ink: rice === "bruteon" ? brute.pastelInk : rice === "cozytile" ? (cozy ? cozy.ink : accent) : fg
  readonly property bool colorize: !tray && (rice === "bruteon" || rice === "cozytile")

  // ── размеры: along — вдоль бара, thick — поперёк ──
  readonly property real along: vertical ? height : width
  function box(alongLen, thick) {
    return vertical ? Qt.rect((width - thick) / 2, (height - alongLen) / 2, thick, alongLen)
                    : Qt.rect((width - alongLen) / 2, (height - thick) / 2, alongLen, thick)
  }

  // Bruteon: его пастель; плитка 28 px, как у BruteModule
  QtObject {
    id: brute
    readonly property var pastel: ["#ffb77a", "#c5e1a5", "#dcc4ec", "#ffcbd5", "#ffb3a1", "#fbf5f1"]
    readonly property color pastelInk: "#161110"
    readonly property int pick: {
      var h = 0, s = String(dress.name)
      for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0
      return h % pastel.length
    }
    readonly property real thick: Math.min(28, dress.across - 10)
    readonly property rect r: dress.vertical ? dress.box(dress.along - 6, thick) : Qt.rect(2, (dress.height - thick) / 2 - 1, dress.width - 6, thick)
  }
  Mods.BruteTile {
    visible: dress.rice === "bruteon"
    x: brute.r.x; y: brute.r.y; width: brute.r.width; height: brute.r.height
    fill: brute.pastel[brute.pick]
    ink: Commons.Color.foreground
    hovered: dress.hot
  }

  // Rumda: карточка поперёк бара на 14 px уже его толщины
  Mods.RumdaCard {
    visible: dress.rice === "rumda"
    readonly property rect r: dress.box(dress.along - 4, dress.across - 14)
    x: r.x; y: r.y; width: r.width; height: r.height
    hot: dress.hot
    bar: ({ background: dress.bg, barForeground: dress.fg })
  }

  // surface: пилюля цвета карточки
  Mods.SurfPal { id: surf }
  Rectangle {
    visible: dress.rice === "surface"
    readonly property rect r: dress.box(dress.along, Math.min(34, dress.across - 6))
    x: r.x; y: r.y; width: r.width; height: r.height
    radius: Math.min(width, height) / 2
    color: surf.card
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: surf.dark ? "#ffffff" : "#000000"
      opacity: dress.hot ? 0.1 : 0
      Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
  }

  // Cozytile: косая черта справа цветом язычков (фон темы, не бара: бар у Cozytile — dark_background)
  Rectangle {
    visible: dress.rice === "cozytile" && !dress.vertical && dress.separators
    x: dress.width - 11 - 1
    y: 3
    width: 2; height: dress.height - 6
    radius: 1
    rotation: 22
    color: dress.cozy ? dress.cozy.slash : dress.a(dress.bg, 0.9)
  }

  // Unit-3: черта слева во всю высоту и лёгкая подложка при наведении
  Rectangle {
    visible: dress.rice === "unit3" && dress.separators
    width: dress.vertical ? dress.width : 1
    height: dress.vertical ? 1 : dress.height
    color: dress.a(dress.fg, 0.08)
  }
  Rectangle {
    visible: dress.rice === "unit3"
    x: dress.vertical ? 0 : 1; y: dress.vertical ? 1 : 0
    width: dress.vertical ? dress.width : dress.width - 1
    height: dress.vertical ? dress.height - 1 : dress.height
    color: dress.a(dress.fg, 0.06)
    opacity: dress.hot ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }

  // yami: квадратная ячейка
  Rectangle {
    visible: dress.rice === "yami"
    readonly property real cell: Math.max(16, Math.round(dress.across * 0.66))
    readonly property rect r: dress.box(Math.max(cell, dress.along - 4), cell)
    x: r.x; y: r.y; width: r.width; height: r.height
    color: dress.hot ? dress.a(dress.fg, 0.14) : "transparent"
  }

  // Vitreus / Glyph / DOT-MATRIX: подложка только при наведении
  Rectangle {
    visible: dress.rice === "vitreus" || dress.rice === "glyph" || dress.rice === "dotmatrix"
    readonly property real k: Math.max(0.55, dress.across / 62)
    readonly property rect r: dress.box(dress.along - 2, Math.round(dress.across * 0.7))
    x: r.x; y: r.y; width: r.width; height: r.height
    radius: dress.rice === "vitreus" ? 7 * k : Math.min(width, height) / 2
    color: dress.rice === "dotmatrix" ? "transparent" : dress.a(dress.fg, dress.rice === "vitreus" ? 0.1 : 0.08)
    border.width: dress.rice === "dotmatrix" ? 1 : 0
    border.color: DotMatrix.Palette.line
    opacity: dress.hot ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }
}
