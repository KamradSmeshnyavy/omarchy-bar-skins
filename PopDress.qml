import QtQuick
import qs.Commons
import qs.Commons as Commons

// «Одёжка» стоковой карточки панели модуля (звук, сеть, Bluetooth… — её рисует KeyboardPanel из qs.Ui: непрозрачная
// заливка popups.background, контур, зазор до бара). У стеклянных основ Vitreus (style.json material liquid, base
// glass / uwu / cyber / obsidian) карточка становится прозрачной, а под ней — жидкое стекло (LiquidGlass) одним куском
// с баром: перешеек вдоль стороны и вогнутые изгибы, как у панелей kamradsmeshnyavy.widgets. С «каплей» (appear drip)
// стекло вытекает из кнопки модуля пружиной (DripMotion), содержимое карточки проявляется после формы, при закрытии
// стекло втягивается в бар и тот колышется. Создаётся в окне панели (Bar.attachPopTab), под карточкой.
Item {
  id: dress
  objectName: "omarchyPopDress"

  required property var kp          // KeyboardPanel
  required property var card        // его BorderSurface
  required property var bar         // Bar.qml
  required property var owner
  readonly property var look: bar.riceLook

  anchors.fill: parent
  z: -1
  visible: look.glass

  readonly property real sw: kp.screen ? kp.screen.width : width
  readonly property real sh: kp.screen ? kp.screen.height : height
  // карточку утащили за язычок: капли из бара нет; прилипла к кромке (pop-places.json edge) — сливается с ней
  readonly property bool loose: bar.popDetached === owner
  readonly property string stuck: loose && bar.popCard && bar.popCard.edge ? String(bar.popCard.edge) : ""
  // кромка, с которой карточка одним куском: бар, а у утащенной — та, у которой её отпустили (или никакая)
  readonly property string edge: loose ? stuck : bar.position
  readonly property bool side: edge === "left" || edge === "right"
  readonly property real bs: edge === bar.position ? bar.barSize : bar.skin.framed ? bar.skin.frameWidth : 0
  // внутренняя кромка бара / рамки (px экрана)
  readonly property real inner: edge === "left" ? bs : edge === "top" ? bs : edge === "right" ? sw - bs : sh - bs
  readonly property bool merge: bar.mergePopups && edge !== ""
  readonly property rect c: Qt.rect(card.x, card.y, card.width, card.height)

  DripMotion {
    id: drop
    active: dress.look.glass && dress.look.drip
    motion: dress.look.motion
    revealDelay: 160
    screenName: dress.kp.screen ? String(dress.kp.screen.name) : ""
    rippleOrigin: {
      var a = dress.anchorAlong
      return dress.side ? Qt.point(dress.edge === "left" ? dress.bs / 2 : dress.sw - dress.bs / 2, a)
                        : Qt.point(a, dress.edge === "top" ? dress.bs / 2 : dress.sh - dress.bs / 2)
    }
  }
  readonly property real d: drop.active ? drop.d : 1
  readonly property real anchorAlong: {
    var p = kp.anchorScreenPos
    return side ? p.y + kp.anchorH / 2 : p.x + kp.anchorW / 2
  }

  // ── форма капли (те же формулы, что DrawerGeom.drip) ──
  readonly property real dd: Math.max(0, d)
  readonly property real bell: Math.max(0, 4 * dd * (1 - dd))
  readonly property real len: side ? c.height : c.width
  readonly property real cross: side ? c.width : c.height
  readonly property real s0: Math.min(120, len)
  readonly property real along: Math.max(0, (s0 + (len - s0) * (Math.min(1, 1.6 * dd) + Math.max(0, dd - 1) * 0.6)) * (1 - 0.07 * bell + 0.003 * drop.wobble))
  readonly property real crossNow: Math.max(0, (cross * dd + Math.max(0, drop.sag)) * (1 - 0.002 * drop.wobble))
  readonly property real center: anchorAlong + ((side ? c.y + c.height / 2 : c.x + c.width / 2) - anchorAlong) * Math.min(1, 1.6 * dd)
  readonly property rect body: {
    if (loose || !drop.active) return c
    var a = center - along / 2
    if (edge === "left") return Qt.rect(c.x, a, crossNow, along)
    if (edge === "right") return Qt.rect(c.x + c.width - crossNow, a, crossNow, along)
    if (edge === "top") return Qt.rect(a, c.y, along, crossNow)
    return Qt.rect(a, c.y + c.height - crossNow, along, crossNow)
  }
  readonly property real cardR: card.radius
  readonly property real bodyR: {
    if (loose || !drop.active) return cardR
    var pill = Math.min(body.width, body.height) / 2
    return pill + (Math.min(cardR, pill) - pill) * Math.max(0, Math.min(1, 1.6 * dd - 0.1))
  }
  readonly property real neckK: edge === "" ? 0 : (26 + 20 * bell) * Math.min(1, 4 * dd) * (1 - 0.85 * look.squareness)
  // опора перешейка — полоса под вырезом у внутренней кромки бара (сама не видна, тянет к себе стекло)
  readonly property rect neck: {
    var e = neckK + 6, t = 5, r = body
    if (!merge) return side ? Qt.rect(edge === "left" ? inner - t - 3 : inner + 3, anchorAlong - 70, t, 140)
                            : Qt.rect(anchorAlong - 70, edge === "top" ? inner - t - 3 : inner + 3, 140, t)
    return side ? Qt.rect(edge === "left" ? inner - t - 3 : inner + 3, r.y - e, t, r.height + 2 * e)
                : Qt.rect(r.x - e, edge === "top" ? inner - t - 3 : inner + 3, r.width + 2 * e, t)
  }
  readonly property rect cut: edge === "top" ? Qt.rect(-4000, -4000, 8000 + sw, 4000 + inner - 3)
    : edge === "bottom" ? Qt.rect(-4000, inner + 3, 8000 + sw, 4000 + sh)
    : edge === "left" ? Qt.rect(-4000, -4000, 4000 + inner - 3, 8000 + sh)
    : Qt.rect(inner + 3, -4000, 4000 + sw, 8000 + sh)

  LiquidGlass {
    id: glass
    visible: dress.look.glass && dress.d > 0.001
    x: dress.body.x; y: dress.body.y
    width: dress.body.width; height: dress.body.height
    radius: dress.bodyR
    screenOrigin: Qt.point(x, y)
    tintColor: Commons.Color.background
    bleed: dress.neckK + 80
    joinRect: dress.neckK > 0 ? Qt.rect(dress.neck.x - x, dress.neck.y - y, dress.neck.width, dress.neck.height) : Qt.rect(0, 0, 0, 0)
    joinRadius: 2.5
    joinK: dress.neckK
    cutRect: dress.edge === "" ? Qt.rect(0, 0, 0, 0) : Qt.rect(dress.cut.x - x, dress.cut.y - y, dress.cut.width, dress.cut.height)
  }

  // карточка: прозрачная, без контура; держится на экране, пока капля втягивается; содержимое — после формы
  function holder() {
    for (var i = 0; i < card.children.length; i++) {
      var ch = card.children[i]
      for (var j = 0; ch && j < ch.children.length; j++) if (ch.children[j].sourceComponent !== undefined) return ch
    }
    return null
  }
  Component.onCompleted: {
    var k = kp, cd = card, dr = dress, h = holder()
    if (bar.mergePopups) k.gap = 0
    cd.color = Qt.binding(function() { return dr.look.glass ? "transparent" : Commons.Color.popups.background })
    cd.borderSpec = Qt.binding(function() { return dr.look.glass ? Border.none() : k.borderSpec })
    cd.opacity = Qt.binding(function() { return drop.active ? (drop.d > 0.002 || k.open ? 1 : 0) : cd.shown })
    if (h) h.opacity = Qt.binding(function() { return Math.min(1, k.morph * 1.6) * (drop.active ? drop.reveal : 1) })
    drop.open = Qt.binding(function() { return k.open })
  }
}
