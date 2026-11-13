import QtQuick
import Quickshell
import "glyphrice"

// Из glyph-rice (bar/Bar.qml, GPL-3.0) — модуль бара kamradsmeshnyavy.bar. k — масштаб от пилюли glyph-rice (64 px) к толщине бара.
// Часы Doto: сбоку столбиком — часы над минутами и день недели, сверху — строкой. Клик — календарь дашборда.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property int across: bar && bar.barSize ? bar.barSize : 32
  readonly property real k: Math.max(0.5, across / 64)
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : GTheme.fg

  SystemClock { id: clock; precision: SystemClock.Minutes }
  implicitWidth: vertical ? across : pile.implicitWidth + 12
  implicitHeight: vertical ? pile.implicitHeight + 12 : across
  Grid {
    id: pile
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 4
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    Num { text: Qt.formatTime(clock.date, "HH"); font.pixelSize: 30 * root.k; color: root.fg }
    Num { visible: !root.vertical; text: ":"; font.pixelSize: 30 * root.k; color: root.fg }
    Num { text: Qt.formatTime(clock.date, "mm"); font.pixelSize: 30 * root.k; color: root.fg }
    Lb {
      topPadding: root.vertical ? 8 * root.k : 0
      leftPadding: root.vertical ? 0 : 12 * root.k
      text: Qt.locale("en_US").toString(clock.date, "ddd d")
      px: 10 * root.k
    }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["omarchy-shell", "widgets", "toggleDashboard"])
  }
}
