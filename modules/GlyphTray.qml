import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "glyphrice"

// Из glyph-rice (bar/Bar.qml, GPL-3.0) — модуль бара kamradsmeshnyavy.bar. k — масштаб от пилюли glyph-rice (64 px) к толщине бара.
// Трей: сеть двумя дугами и точкой (выключена — косая черта), bluetooth, звук (колесо — громкость), батарея — стоит
// сбоку и лежит сверху, на зарядке молния и заливка дышит. Клик — быстрые настройки (Super+M), правый — меню выключения.
// settings.parts — что и в каком порядке: "wifi,bluetooth,sound,battery".
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property int across: bar && bar.barSize ? bar.barSize : 32
  readonly property real k: Math.max(0.5, across / 64)
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : GTheme.fg

  readonly property var parts: String(settings && settings.parts || "wifi,bluetooth,sound,battery").split(",").map(function(s) { return s.trim() })
  readonly property var wifi: Networking.devices.values.find(function(d) { return d.type === DeviceType.Wifi }) ?? null
  readonly property var bat: UPower.displayDevice
  readonly property bool batLow: !!bat && bat.percentage < 0.15 && UPower.onBattery
  readonly property PwNode sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: [root.sink].filter(Boolean) }
  readonly property bool muted: !sink || !sink.audio || sink.audio.muted

  implicitWidth: vertical ? across : pile.implicitWidth + 12
  implicitHeight: vertical ? pile.implicitHeight + 12 : across

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(m) { Quickshell.execDetached(["omarchy-shell", "widgets", m.button === Qt.RightButton ? "togglePower" : "toggleSettings"]) }
    onWheel: function(w) {
      if (!root.sink || !root.sink.audio) return
      root.sink.audio.muted = false
      root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05)))
    }
  }

  Grid {
    id: pile
    anchors.centerIn: parent
    columns: root.vertical ? 1 : root.parts.length
    spacing: 18 * root.k
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    Repeater {
      model: root.parts
      Loader {
        required property string modelData
        sourceComponent: ({ wifi: wifiC, bluetooth: btC, sound: soundC, battery: batC })[modelData] || null
        visible: !!sourceComponent && (modelData !== "battery" || (!!root.bat && root.bat.isLaptopBattery))
      }
    }
  }

  // сеть: две дуги и точка, концы круглые; выключена — косая черта
  Component {
    id: wifiC
    Shape {
      id: wf
      width: 20 * root.k
      height: 18 * root.k
      scale: 1
      preferredRendererType: Shape.CurveRenderer
      readonly property real k: root.k
      readonly property color ink: root.wifi && root.wifi.connected ? root.fg : GTheme.grey
      ShapePath {
        strokeColor: wf.ink; strokeWidth: 2.2 * wf.k; capStyle: ShapePath.RoundCap; fillColor: "transparent"
        PathAngleArc { centerX: 10 * wf.k; centerY: 15 * wf.k; radiusX: 5.5 * wf.k; radiusY: 5.5 * wf.k; startAngle: 220; sweepAngle: 100 }
        PathAngleArc { centerX: 10 * wf.k; centerY: 15 * wf.k; radiusX: 10.5 * wf.k; radiusY: 10.5 * wf.k; startAngle: 220; sweepAngle: 100 }
      }
      ShapePath {
        strokeColor: Networking.wifiEnabled ? "transparent" : wf.ink; strokeWidth: 2.2 * wf.k; capStyle: ShapePath.RoundCap
        startX: 3 * wf.k; startY: 2 * wf.k
        PathLine { x: 17 * wf.k; y: 17 * wf.k }
      }
      ShapePath {
        strokeWidth: -1; fillColor: wf.ink
        PathAngleArc { centerX: 10 * wf.k; centerY: 15 * wf.k; radiusX: 1.9 * wf.k; radiusY: 1.9 * wf.k; startAngle: 0; sweepAngle: 360 }
      }
    }
  }
  Component {
    id: btC
    Icon {
      font.pixelSize: 19 * root.k
      text: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "\u{F00AF}" : "\u{F00B2}"
      color: Bluetooth.devices.values.some(function(d) { return d.connected }) ? root.fg : GTheme.grey
    }
  }
  Component {
    id: soundC
    Icon { font.pixelSize: 19 * root.k; text: root.muted ? "\u{F075F}" : "\u{F057E}"; color: root.fg }
  }
  // батарея: сбоку стоит, заряд растёт снизу; сверху лежит, растёт слева. На зарядке — молния, заливка дышит
  Component {
    id: batC
    Grid {
      id: batc
      columns: root.vertical ? 1 : 3
      spacing: 8 * root.k
      horizontalItemAlignment: Grid.AlignHCenter
      verticalItemAlignment: Grid.AlignVCenter
      readonly property bool ac: !UPower.onBattery
      readonly property bool charging: !!root.bat && root.bat.state === UPowerDeviceState.Charging
      property real phase: 0
      readonly property real pulse: charging ? 0.675 + 0.325 * Math.cos(phase * Math.PI / 1.1) : 1
      Timer { running: batc.charging; interval: 50; repeat: true; onTriggered: batc.phase = (batc.phase + 0.05) % 2.2; onRunningChanged: batc.phase = 0 }
      Icon { visible: batc.ac; text: "\u{F140B}"; font.pixelSize: 14 * root.k; color: root.fg }
      Rectangle {
        width: (root.vertical ? 14 : 26) * root.k
        height: (root.vertical ? 26 : 14) * root.k
        radius: 7 * root.k
        color: "transparent"
        border { width: 1.5; color: GTheme.grey }
        Rectangle {
          readonly property real p: root.bat ? root.bat.percentage : 0
          x: 3 * root.k
          y: parent.height - 3 * root.k - height
          width: root.vertical ? parent.width - 6 * root.k : (parent.width - 6 * root.k) * p
          height: root.vertical ? (parent.height - 6 * root.k) * p : parent.height - 6 * root.k
          radius: 4 * root.k
          color: root.batLow ? GTheme.accent : root.fg
          opacity: batc.pulse
        }
      }
      Lb { text: root.bat ? Math.round(root.bat.percentage * 100) : ""; px: 10 * root.k; color: root.fg }
    }
  }
}
