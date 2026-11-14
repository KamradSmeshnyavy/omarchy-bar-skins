import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

// Часы Vitreus (по мотивам natepayn3/Vitreus, MIT; код свой) — модуль бара kamradsmeshnyavy.bar. k — масштаб от полосы
// Vitreus (62 px) к толщине бара.
// Сбоку — столбиком: час крупно (30) градиентом акцента (светлый → акцент → тёмный), карандашная черта, минуты (17),
// день недели и дата мелко. Сверху / снизу — строкой: час градиентом, минуты, справа день и дата в две строки.
// Шрифт цифр — заголовочный из профиля шрифтов (~/.config/omarchy/fonts.json "title"), иначе шрифт бара.
// settings.hour12: true — 12-часовой формат с am / pm. Клик — дашборд.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property int across: bar && bar.barSize ? bar.barSize : 32
  readonly property real k: Math.max(0.55, across / 62)
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : Commons.Color.foreground
  readonly property color acc: Commons.Color.accent
  readonly property bool h12: settings && settings.hour12 === true
  readonly property string sans: bar && bar.fontFamily ? bar.fontFamily : "sans-serif"
  property string title: ""
  readonly property string numFont: title || sans

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/fonts.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.title = String(JSON.parse(text()).title || "") } catch (e) { root.title = "" } }
  }
  SystemClock { id: clock; precision: SystemClock.Minutes }
  readonly property string hh: h12 ? String(((clock.date.getHours() + 11) % 12) + 1) : Qt.formatTime(clock.date, "HH")
  readonly property string mm: Qt.formatTime(clock.date, "mm")
  readonly property string ap: clock.date.getHours() < 12 ? "am" : "pm"
  readonly property string day: Qt.locale().toString(clock.date, "ddd").toUpperCase()
  readonly property string date: Qt.locale().toString(clock.date, "d MMM").toUpperCase()

  implicitWidth: vertical ? across : row.implicitWidth + 16 * k
  implicitHeight: vertical ? col.implicitHeight + 16 * k : across

  // час градиентом: текст — маска, под ним — полоса светлый → акцент → тёмный
  component GradNum: Item {
    id: gn
    property string text
    property real px: 30
    implicitWidth: t.implicitWidth
    implicitHeight: t.implicitHeight
    Text {
      id: t
      text: gn.text
      font.family: root.numFont
      font.pixelSize: Math.round(gn.px)
      font.weight: Font.DemiBold
      color: "white"
      visible: false
      layer.enabled: true
    }
    Rectangle {
      anchors.fill: t
      visible: false
      layer.enabled: true
      id: grad
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(root.acc, 1.42) }
        GradientStop { position: 0.55; color: root.acc }
        GradientStop { position: 1; color: Qt.darker(root.acc, 1.35) }
      }
    }
    MultiEffect {
      anchors.fill: t
      source: grad
      maskEnabled: true
      maskSource: t
      maskThresholdMin: 0.4
      maskSpreadAtMin: 0.3
    }
  }
  // карандашная черта: чуть неровная, два штриха
  component Pencil: Item {
    property real len: 20
    implicitWidth: len
    implicitHeight: 4 * root.k
    Rectangle { y: 1.2 * root.k; width: parent.len; height: 1.4 * root.k; radius: 1; color: root.fg; opacity: 0.55; rotation: -1.2 }
    Rectangle { x: 2 * root.k; y: 2.4 * root.k; width: parent.len - 5 * root.k; height: 0.9 * root.k; radius: 1; color: root.fg; opacity: 0.3; rotation: 0.8 }
  }
  component Small: Text {
    font.family: root.sans
    font.pixelSize: Math.max(7, Math.round(9 * root.k))
    font.weight: Font.DemiBold
    font.letterSpacing: 0.8 * root.k
    color: root.fg
    opacity: 0.7
  }

  Column {
    id: col
    visible: root.vertical
    anchors.centerIn: parent
    spacing: 2 * root.k
    GradNum { anchors.horizontalCenter: parent.horizontalCenter; text: root.hh; px: 30 * root.k }
    Pencil { anchors.horizontalCenter: parent.horizontalCenter; len: 22 * root.k }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.mm
      font.family: root.numFont
      font.pixelSize: Math.round(17 * root.k)
      font.weight: Font.Medium
      color: root.fg
    }
    Small { anchors.horizontalCenter: parent.horizontalCenter; visible: root.h12; text: root.ap.toUpperCase() }
    Item { width: 1; height: 3 * root.k }
    Small { anchors.horizontalCenter: parent.horizontalCenter; text: root.day }
    Small { anchors.horizontalCenter: parent.horizontalCenter; text: root.date; opacity: 0.5 }
  }
  Row {
    id: row
    visible: !root.vertical
    anchors.centerIn: parent
    spacing: 6 * root.k
    GradNum { anchors.verticalCenter: parent.verticalCenter; text: root.hh; px: Math.min(30 * root.k, root.across * 0.62) }
    Pencil { anchors.verticalCenter: parent.verticalCenter; len: 4 * root.k; rotation: 90 }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.mm + (root.h12 ? " " + root.ap : "")
      font.family: root.numFont
      font.pixelSize: Math.round(Math.min(17 * root.k, root.across * 0.4))
      font.weight: Font.Medium
      color: root.fg
    }
    Column {
      anchors.verticalCenter: parent.verticalCenter
      leftPadding: 4 * root.k
      Small { text: root.day }
      Small { text: root.date; opacity: 0.5 }
    }
  }
  HoverHandler { cursorShape: Qt.PointingHandCursor }
  // клик приходит от бара (его область нажатий поверх модуля зовёт triggerPress)
  function triggerPress(button) { Quickshell.execDetached(["omarchy-shell", "widgets", "toggleDashboard"]) }
}
