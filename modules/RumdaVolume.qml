import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons as Commons

// Громкость Rumda (по мотивам hexonide/rumda; код свой): карточка со значком и вертикальной полосой — заливка
// снизу цветом акцента. Колесо — ±5 %, клик — панель звука.
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 48
  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real vol: sink && sink.audio ? Math.min(1, sink.audio.volume) : 0
  readonly property bool muted: !!sink && !!sink.audio && sink.audio.muted
  implicitWidth: across
  implicitHeight: card.height + 8
  RumdaCard {
    id: card
    bar: root.bar
    hot: hov.hovered
    anchors.centerIn: parent
    width: root.across - 14; height: 78
    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 6; text: root.muted ? "󰝟" : "󰕾"; color: Commons.Color.accent; font.family: Commons.Style.font.family; font.pixelSize: 12 }
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      y: 26; width: 8; height: parent.height - 34; radius: 1
      color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25)
      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: parent.height * (root.muted ? 0 : root.vol); radius: 1
        gradient: Gradient { GradientStop { position: 0; color: Qt.lighter(Commons.Color.accent, 1.15) } GradientStop { position: 1; color: Commons.Color.accent } }
      }
    }
  }
  HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
  WheelHandler { onWheel: function(e) { if (root.sink && root.sink.audio) root.sink.audio.volume = Math.max(0, Math.min(1, root.vol + (e.angleDelta.y > 0 ? 0.05 : -0.05))) } }
  function triggerPress(button) { if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted }
}
