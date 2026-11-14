import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// Мост от бара к карточке открытой панели модуля (звук, сеть, Bluetooth, монитор… — их рисует KeyboardPanel из qs.Ui
// со своим зазором и контуром со всех сторон). Как у Vitreus и caelestia, карточка должна сливаться с баром: мост
// заливает зазор цветом карточки, закрывает её контур и скругления со стороны бара, продолжает её боковой контур до
// кромки бара и рисует вогнутые углы (MergeFillet). Окно — Overlay поверх карточки (появляется после неё — выше),
// клики не ловит. Где карточка — бар узнаёт из notePopoutCard (bar.popCard, px экрана).
Scope {
  id: root

  required property var screen
  required property var bar
  // карточку утащили за язычок — она больше не у бара
  // утащенная за язычок карточка сливается только с той кромкой, у которой её отпустили (popCard.edge)
  readonly property bool want: bar.mergePopups && bar.popCard !== null && (bar.popDetached === null || !!bar.popCard.edge) && screen && bar.popCard.screen === String(screen.name)

  // Окно создаётся заново на каждое открытие: новый слой Overlay ложится выше карточки, открытой перед ним
  // (заранее созданное окно Hyprland держал под ней).
  LazyLoader {
    active: root.want
    PanelWindow {
      id: br

      property var bar: root.bar
      property var scr: root.screen
      screen: scr
      readonly property var card: bar.popCard && scr && bar.popCard.screen === String(scr.name) ? bar.popCard : null
      readonly property string e: card && card.edge ? String(card.edge) : bar.position
      // толщина бара или рамки у этой кромки
      readonly property real bs: e === bar.position ? bar.barSize : bar.skin.framed ? bar.skin.frameWidth : 0
      // внутренняя кромка бара / рамки
      readonly property real edgeAt: e === "left" || e === "top" ? bs : e === "right" ? width - bs : height - bs
      readonly property rect c: card ? Qt.rect(card.x, card.y, card.width, card.height) : Qt.rect(0, 0, 0, 0)
      // зазор между кромкой и карточкой
      readonly property real g: !card ? -1 : e === "left" ? c.x - edgeAt : e === "right" ? edgeAt - (c.x + c.width)
        : e === "top" ? c.y - edgeAt : edgeAt - (c.y + c.height)
      readonly property bool on: bar.mergePopups && card !== null && g >= 0 && g <= 40

      readonly property var spec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Math.max(1, Style.space(2)))
      readonly property real bw: Math.max(1, Border.left(spec))
      readonly property color fill: Commons.Color.popups.background
      // один цвет стыка: контур карточки целиком перекрашивается в контур бара (если он есть), иначе — свой
      readonly property bool barLine: bar.skin.borderWidth > 0
      readonly property color line: barLine ? bar.skin.borderColor : Commons.Color.popups.border
      readonly property real r: Style.cornerRadius
      readonly property real f: 12
      readonly property real ext: 3

      visible: true
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      surfaceFormat.opaque: false
      mask: Region {}
      WlrLayershell.namespace: "omarchy-bar-bridge"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      // появляется вместе с карточкой (она растёт ~180 мс), уходит сразу
      property real shown: 0
      Component.onCompleted: appear.restart()
      SequentialAnimation {
        id: appear
        PauseAnimation { duration: 90 }
        NumberAnimation { target: br; property: "shown"; to: 1; duration: 110; easing.type: Easing.OutCubic }
      }

      // тело карточки вместе с мостом: от кромки бара до дальнего края карточки
      readonly property rect body: e === "left" ? Qt.rect(edgeAt, c.y, c.x + c.width - edgeAt, c.height)
        : e === "right" ? Qt.rect(c.x, c.y, edgeAt - c.x, c.height)
        : e === "top" ? Qt.rect(c.x, edgeAt, c.width, c.y + c.height - edgeAt)
        : Qt.rect(c.x, c.y, c.width, edgeAt - c.y)

      Item {
        anchors.fill: parent
        opacity: br.shown
        visible: br.on

        // контур карточки цветом бара — поверх её собственного (сторону у бара закроет заливка ниже)
        Rectangle {
          visible: br.barLine
          x: br.c.x; y: br.c.y; width: br.c.width; height: br.c.height
          radius: br.r
          color: "transparent"
          border.width: br.bw + 0.5
          border.color: br.line
        }
        // заливка зазора и полоски контура карточки у бара (с заходом на кромку бара на ext)
        Rectangle {
          color: br.fill
          x: br.e === "left" ? br.edgeAt - br.ext : br.e === "right" ? br.c.x + br.c.width - br.bw - 0.5 : br.c.x + br.bw
          y: br.e === "top" ? br.edgeAt - br.ext : br.e === "bottom" ? br.c.y + br.c.height - br.bw - 0.5 : br.c.y + br.bw
          width: br.e === "left" || br.e === "right" ? br.g + br.ext + br.bw + 0.5 : br.c.width - 2 * br.bw
          height: br.e === "top" || br.e === "bottom" ? br.g + br.ext + br.bw + 0.5 : br.c.height - 2 * br.bw
        }
        // углы карточки у бара — квадратные: заливка r × r и контур, продолженный до кромки
        Repeater {
          model: br.on ? [-1, 1] : []
          Item {
            required property var modelData
            readonly property bool lo: modelData < 0
            readonly property bool side: br.e === "left" || br.e === "right"
            // угол карточки со стороны бара
            readonly property real cx: br.e === "left" ? br.c.x : br.e === "right" ? br.c.x + br.c.width - br.r : (lo ? br.c.x : br.c.x + br.c.width - br.r)
            readonly property real cy: br.e === "top" ? br.c.y : br.e === "bottom" ? br.c.y + br.c.height - br.r : (lo ? br.c.y : br.c.y + br.c.height - br.r)
            Rectangle {
              x: parent.cx; y: parent.cy; width: br.r; height: br.r
              color: br.fill
            }
            // боковой контур карточки — от кромки бара до конца скругления
            Rectangle {
              color: br.line
              x: parent.side ? (br.e === "left" ? br.edgeAt - 1 : br.c.x + br.c.width - br.r) : (parent.lo ? br.c.x : br.c.x + br.c.width - br.bw)
              y: !parent.side ? (br.e === "top" ? br.edgeAt - 1 : br.c.y + br.c.height - br.r) : (parent.lo ? br.c.y : br.c.y + br.c.height - br.bw)
              width: parent.side ? br.g + br.r + 1 : br.bw
              height: parent.side ? br.bw : br.g + br.r + 1
            }
          }
        }
        // вогнутые углы у кромки бара
        Item {
          x: br.body.x; y: br.body.y; width: br.body.width; height: br.body.height
          Repeater {
            model: br.on ? [-1, 1] : []
            MergeFillet {
              required property var modelData
              edge: br.e
              side: modelData
              w: br.body.width; h: br.body.height
              f: br.f; bw: br.bw; ext: br.ext
              fill: br.fill; line: br.line
            }
          }
        }
      }
    }
  }
}
