import QtQuick
import Quickshell.Io

// RunCat: пиксельный кот бежит тем быстрее, чем выше загрузка CPU (идея RunCat / glyph-rice; кадры
// нарисованы здесь же, без чужих картинок). CPU — /proc/stat раз в 2 с. Наведение — подсказка с процентом.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  readonly property bool vertical: !bar || bar.vertical !== false
  readonly property bool tooltipHovered: hover.hovered
  readonly property color ink: bar && bar.barForeground ? bar.barForeground : "#ffffff"

  // Кадры 14×8: «#» — пиксель. Бег: лапы попеременно вытянуты и поджаты, хвост качается.
  readonly property var frames: [
    ["            # ",
     "#          ###",
     " #   ######## ",
     "  ########### ",
     "  ##########  ",
     "  ## #   # ## ",
     " #   #   #   #",
     "              "],
    ["           #  ",
     " #        ### ",
     "  # ######### ",
     "  ########### ",
     "  ##########  ",
     "   # ## ## #  ",
     "   #  # #  #  ",
     "              "],
    ["            # ",
     "  #        ###",
     "   ######### ",
     "  ########### ",
     "  ##########  ",
     "   ## # # ##  ",
     "    ##   ##   ",
     "              "],
    ["           #  ",
     " #        ### ",
     "  # ######### ",
     "  ########### ",
     "  ##########  ",
     "  # ##   ## # ",
     " #    # #    #",
     "              "]
  ]
  readonly property int px: 2
  property int frame: 0
  property real cpu: 0
  property var prev: null

  // Толщина слота — как у бара (штатные модули так же), иначе модуль прижат к верху ряда.
  readonly property int across: bar && bar.barSize ? bar.barSize : 26
  implicitWidth: vertical ? across : 14 * px + 6
  implicitHeight: vertical ? 8 * px + 8 : across

  onTooltipHoveredChanged: {
    if (!bar) return
    if (tooltipHovered) bar.showTooltip(root, "CPU " + Math.round(cpu * 100) + "%")
    else bar.hideTooltip(root)
  }
  HoverHandler { id: hover }

  Process {
    id: probe
    command: ["bash", "-c", "read -r _ u n s i w q sq st _ < /proc/stat; echo $((u+n+s+i+w+q+sq+st)) $((i+w))"]
    stdout: StdioCollector {
      onStreamFinished: {
        var f = text.trim().split(/\s+/)
        var total = Number(f[0]), idle = Number(f[1])
        if (root.prev && total > root.prev.total)
          root.cpu = Math.max(0, Math.min(1, 1 - (idle - root.prev.idle) / (total - root.prev.total)))
        root.prev = { total: total, idle: idle }
        if (root.tooltipHovered && root.bar) root.bar.showTooltip(root, "CPU " + Math.round(root.cpu * 100) + "%")
      }
    }
  }
  Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!probe.running) probe.running = true }
  // 0 % — шаг раз в 250 мс, 100 % — раз в 45 мс.
  Timer {
    interval: Math.round(250 - 205 * root.cpu)
    repeat: true
    running: root.visible
    onTriggered: root.frame = (root.frame + 1) % root.frames.length
  }

  Grid {
    anchors.centerIn: parent
    columns: 14
    Repeater {
      model: 14 * 8
      Rectangle {
        required property int index
        width: root.px; height: root.px
        color: root.frames[root.frame][Math.floor(index / 14)].charAt(index % 14) === "#" ? root.ink : "transparent"
      }
    }
  }
}
