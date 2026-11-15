import QtQuick
import Quickshell
import qs.Commons as Commons

// Часы Rumda (по мотивам hexonide/rumda; код свой): в карточке часы над минутами пиксельным Dogica Pixel цветом
// акцента. Клик — дашборд.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 48
  readonly property string px: Qt.fontFamilies().indexOf("Dogica Pixel") !== -1 ? "Dogica Pixel" : (bar && bar.fontFamily ? bar.fontFamily : "monospace")
  SystemClock { id: clk; precision: SystemClock.Minutes }
  implicitWidth: across
  implicitHeight: card.height + 8
  RumdaCard {
    id: card
    bar: root.bar
    hot: hov.hovered
    anchors.centerIn: parent
    width: root.across - 14; height: col.implicitHeight + 16
    Column {
      id: col
      anchors.centerIn: parent
      spacing: 5
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(clk.date, "HH"); color: Commons.Color.accent; font.family: root.px; font.pixelSize: 9 }
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(clk.date, "mm"); color: Commons.Color.accent; font.family: root.px; font.pixelSize: 9 }
    }
  }
  HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
  function triggerPress(button) { Quickshell.execDetached(["omarchy-shell", "widgets", "toggleDashboard"]) }
}
