import QtQuick
import qs.Commons as Commons

// Палитра бара surface — роли из lib/ThemeEngine.qml surface-dots (snes19xx), посчитанные из цветов текущей темы:
// карточка (bgCard на 78 %), основной и вторичный текст, акцент пилюль, контур, тёмный текст на акценте.
// На темах surface-* совпадает с его цветами; на любой другой теме — те же роли из её палитры.
QtObject {
  readonly property color bg: Commons.Color.background
  readonly property color fg: Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property bool dark: 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b < 0.5
  function mix(a, b, k) { return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  // bgCard: на шаг светлее (тёмная) / темнее (светлая) фона, 78 % — как его pal.bg бара
  readonly property color cardSolid: dark ? mix(bg, fg, 0.06) : mix(bg, "#000000", 0.055)
  readonly property color card: alpha(cardSolid, 0.78)
  readonly property color text: fg
  readonly property color text2: mix(fg, bg, 0.38)
  readonly property color onAccent: dark ? "#2d353b" : "#1e2326"
  readonly property color outline: dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.1)
  // значки окон и точки пустых столов: тёплый светлый на тёмной, почти чёрный на светлой
  readonly property color glyph: dark ? mix(fg, bg, 0.12) : mix(fg, "#000000", 0.25)
  readonly property color urgent: Commons.Color.urgent !== undefined ? Commons.Color.urgent : "#e67e80"
  readonly property string font: Qt.fontFamilies().indexOf("Manrope") !== -1 ? "Manrope" : "sans-serif"
  readonly property string icons: "JetBrainsMono Nerd Font"
}
