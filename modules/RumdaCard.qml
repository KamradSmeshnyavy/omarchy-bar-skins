import QtQuick
import qs.Commons as Commons

// Карточка модуля Rumda (по мотивам hexonide/rumda; код свой): скруглённый квадрат цвета «модуля» — смесь фона бара с
// текстом — с рамкой в 2 px. Её кладут в модули Rumda* (Rumda рисует так каждый модуль бара).
Rectangle {
  id: c
  property var bar: null
  property bool hot: false
  readonly property color bg: bar && bar.background ? bar.background : Commons.Color.background
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : Commons.Color.foreground
  radius: 7
  color: Qt.rgba(bg.r + (fg.r - bg.r) * (hot ? 0.2 : 0.13), bg.g + (fg.g - bg.g) * (hot ? 0.2 : 0.13), bg.b + (fg.b - bg.b) * (hot ? 0.2 : 0.13), 1)
  border.width: 2
  border.color: Qt.rgba(bg.r + (fg.r - bg.r) * 0.08, bg.g + (fg.g - bg.g) * 0.08, bg.b + (fg.b - bg.b) * 0.08, 1)
  Behavior on color { ColorAnimation { duration: 140 } }
}
