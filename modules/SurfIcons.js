// Значки окон по классу — таблица из surface-dots (snes19xx, bars/TopBar.qml getIcon; README разрешает брать со ссылкой).
.pragma library
var RULES = [[["firefox", "zen", "librewolf"], "󰈹"], [["chromium", "chrome", "thorium"], ""], [["brave"], ""], [["qutebrowser"], "󰖟"], [["kitty"], "󰄛"], [["alacritty", "foot", "terminal", "ghostty", "wezterm"], ""], [["code", "codium"], ""], [["sublime"], "󰅳"], [["neovide", "nvim"], ""], [["idea", "jetbrains"], ""], [["pycharm"], ""], [["webstorm"], ""], [["clion"], ""], [["android"], "󰀴"], [["kate", "texteditor"], "󰈔"], [["nautilus", "org.gnome.nautilus", "files"], ""], [["thunar", "dolphin", "nemo"], ""], [["discord", "vesktop"], "󰙯"], [["slack"], "󰒱"], [["telegram"], ""], [["signal"], "󰭹"], [["element"], "󰘨"], [["whatsapp"], "󰖣"], [["spotify"], ""], [["vlc"], "󰕼"], [["mpv", "haruna", "strawberry", "rhythmbox", "totem"], ""], [["gimp"], ""], [["inkscape"], "󰕙"], [["krita"], ""], [["blender"], "󰂫"], [["audacity"], "󰎈"], [["obs"], ""], [["kdenlive"], "󰕧"], [["steam"], ""], [["lutris"], "󰺵"], [["heroic"], "󰊖"], [["prismlauncher"], "󰍳"], [["libreoffice-writer"], "󰈬"], [["calc"], "󰧷"], [["impress"], "󰈧"], [["libreoffice"], "󰈙"], [["evince"], "󰈦"], [["thunderbird"], ""], [["settings", "missioncenter"], ""], [["look"], ""], [["systemmonitor"], "󰄨"], [["pavucontrol"], "󰕾"], [["calculator"], "󰃬"], [["weather"], ""], [["evercal"], "󰃭"], [["playing"], "󰎄"], [["photos", "org.gnome.loupe", "imv", "feh", "eog", "gthumb", "qimgv", "viewnior"], ""], [["swappy"], "󰫕"], [["amberol"], "󱖏"], [["xdm"], ""], [["zathura"], ""], [["focuswriter"], "󱞁"], [["lollypop"], "󰎆"]]
var FALLBACK = ""
function iconFor(cls) {
  var c = String(cls || "").toLowerCase()
  for (var i = 0; i < RULES.length; i++)
    for (var j = 0; j < RULES[i][0].length; j++)
      if (c.indexOf(RULES[i][0][j]) !== -1) return RULES[i][1]
  return FALLBACK
}
