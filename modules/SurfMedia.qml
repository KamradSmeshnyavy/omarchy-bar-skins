import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris

// Середина бара surface (по мотивам surface-dots, snes19xx — bars/TopBar.qml; README разрешает брать со ссылкой):
// пока что-то играет — нота акцентом и «Название - Исполнитель» (исполнитель вторичным цветом), иначе — заголовок
// активного окна («Desktop» на пустом столе). Жирный моноширинный шрифт значков. Клик — пауза / играть.
// settings.width — предел ширины текста (350).
Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int across: bar && bar.barSize ? bar.barSize : 40
  readonly property SurfPal pal: SurfPal {}
  readonly property int maxW: Number(settings && settings.width) || 350

  readonly property var player: {
    var l = Mpris.players.values
    for (var i = 0; i < l.length; i++) if (l[i].playbackState === MprisPlaybackState.Playing) return l[i]
    return null
  }
  readonly property bool playing: !!player
  readonly property string title: Hyprland.activeToplevel && Hyprland.activeToplevel.title ? Hyprland.activeToplevel.title : "Desktop"

  implicitWidth: (playing ? song.implicitWidth : win.implicitWidth) + 8
  implicitHeight: across

  Text {
    id: win
    anchors.centerIn: parent
    visible: !root.playing
    text: root.title
    width: Math.min(implicitWidth, root.maxW + 150)
    elide: Text.ElideRight
    color: root.pal.text
    font.family: root.pal.icons
    font.weight: 700
    font.pixelSize: 13
  }
  Row {
    id: song
    anchors.centerIn: parent
    visible: root.playing
    spacing: 10
    Text { text: ""; color: root.pal.accent; font.family: root.pal.icons; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.player ? root.player.trackTitle + " <font color='" + root.pal.text2 + "'>- " + root.player.trackArtist + "</font>" : ""
      textFormat: Text.StyledText
      width: Math.min(implicitWidth, root.maxW)
      elide: Text.ElideRight
      color: root.pal.text
      font.family: root.pal.icons
      font.weight: 700
      font.pixelSize: 13
    }
  }
  function triggerPress(button) { if (root.player && root.player.canTogglePlaying) root.player.togglePlaying() }
}
