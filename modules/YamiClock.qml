import QtQuick
import Quickshell
import qs.Commons as Commons

// Часы yami (по мотивам Trendorin/yami, MIT; код свой) — модуль бара kamradsmeshnyavy.bar: «00:21 Fr 13.11» пиксельным
// шрифтом бара; сбоку — время над датой. Клик — дашборд.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: !!bar && bar.vertical === true
  readonly property int across: bar && bar.barSize ? bar.barSize : 30
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : Commons.Color.foreground
  readonly property string font: bar && bar.fontFamily ? bar.fontFamily : "Tiny5"
  readonly property int px: Math.max(9, Math.round(across * 0.44))

  SystemClock { id: clk; precision: SystemClock.Minutes }
  readonly property string day: Qt.locale().toString(clk.date, "ddd").slice(0, 2)

  implicitWidth: vertical ? across : row.implicitWidth + 10
  implicitHeight: vertical ? col.implicitHeight + 10 : across

  Row {
    id: row
    visible: !root.vertical
    anchors.centerIn: parent
    spacing: 6
    Text { text: Qt.formatTime(clk.date, "HH:mm"); color: root.fg; font.family: root.font; font.pixelSize: root.px }
    Text { text: root.day + " " + Qt.formatDate(clk.date, "dd.MM"); color: root.fg; opacity: 0.55; font.family: root.font; font.pixelSize: root.px }
  }
  Column {
    id: col
    visible: root.vertical
    anchors.centerIn: parent
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(clk.date, "HH"); color: root.fg; font.family: root.font; font.pixelSize: root.px + 4 }
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(clk.date, "mm"); color: root.fg; font.family: root.font; font.pixelSize: root.px + 4 }
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(clk.date, "dd.MM"); color: root.fg; opacity: 0.55; font.family: root.font; font.pixelSize: root.px - 1 }
  }
  HoverHandler { cursorShape: Qt.PointingHandCursor }
  function triggerPress(button) { Quickshell.execDetached(["omarchy-shell", "widgets", "toggleDashboard"]) }
}
