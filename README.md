# Omarchy Bar Skins

[🇷🇺 Русский](README.ru.md)

A drop-in replacement for the [Omarchy](https://omarchy.org) top bar: the stock `omarchy.bar` with a skin
layer on top. Every widget, panel and gesture of the stock bar keeps working — the skin only changes how
the bar is drawn.

- **18 skins** — floating, islands, pill, notch, underline, hug, glass, neon, capsules, autohide, …
- **9 layouts** — centered, bottom, left-vertical, right-heavy, media-center, …
- **Compact mode** — the bar shrinks to a thin strip (only when a window is focused, only in fullscreen, or
  always) and expands back when you hover it
- **Workspaces** — 20+ label styles (roman, kanji, greek, circled, braille…), app icons per workspace,
  an accent pill under the active one
- Colours are theme roles, so the bar recolours itself with every `omarchy theme set`

![Skins](screenshots/skins.webp)

Compact mode expanding on hover:

![Compact mode](screenshots/compact.webp)

## Install

```sh
omarchy plugin add https://github.com/KamradSmeshnyavy/omarchy-bar-skins --enable
omarchy restart shell
```

`--enable` makes it the bar in use (`bar.id` in `~/.config/omarchy/shell.json`). If the plugin fails to
load, the shell falls back to the stock bar on its own. To go back manually:
`omarchy plugin enable omarchy.bar`.

Tested on Omarchy 4.0.6 with Quickshell 0.3.2.

## Pick a skin

The active skin is `~/.config/omarchy/bar-skin.json`. The bar watches the file and redraws instantly:

```sh
cp ~/.config/omarchy/plugins/kamradsmeshnyavy.bar/skins/islands.json ~/.config/omarchy/bar-skin.json
```

A layout goes into the `bar` section of `shell.json`:

```sh
cd ~/.config/omarchy
jq --slurpfile l plugins/kamradsmeshnyavy.bar/layouts/centered.json '.bar += $l[0]' shell.json > shell.json.new \
  && mv shell.json.new shell.json
```

The [Customizer](https://github.com/KamradSmeshnyavy/omarchy-customizer) drives all of this in one
overlay with live preview — skins, layouts and every setting below:

![Customizer](screenshots/customizer.webp)

## Skin schema

```jsonc
{
  "shape": "floating",        // full floating pill islands notch underline hug
  "height": 30,               // 0 = stock height
  "gap": 6,                   // distance from the screen edge
  "margin": 10,               // left/right margins
  "width": 1.0,               // share of the screen width (floating/pill/notch)
  "radius": 12,
  "padding": -1,              // module padding inside the background; -1 = stock
  "islandGap": 6,
  "background": "bar",        // colour: a role or #hex
  "backgroundAlpha": 0.85,    // -1 = alpha from the theme
  "gradient": "accent",       // second colour of a horizontal gradient (omit for none)
  "border": "accent", "borderWidth": 1, "borderAlpha": 0.6,
  "text": "bar", "active": "bar",
  "shadow": true,
  "glow": false,              // a halo in the border colour instead of a shadow
  "autoHide": false,          // hide behind the edge, slide out on hover
  "moduleStyle": "plain",     // plain pills hover
  "moduleBackground": "foreground", "moduleAlpha": 0.08,
  "spacing": 0,
  "font": "",                 // empty = system font
  "transparent": false        // stock transparent mode (written to shell.json)
}
```

A colour is `bar` (the stock bar colour from the theme's `[bar]`), a shell role (`background`,
`foreground`, `accent`, `muted`, `urgent`), any key of the current theme's `colors.toml` (`red`, `cyan`,
`lighter_background`, …) or `#rrggbb`. Roles follow the theme.

Shapes: `full` is stock; `floating` — a strip with gaps; `pill` — floating with half-height radius;
`islands` — one island per section; `notch` — a notch at the edge; `underline` — a line along the edge;
`hug` — full width with concave corners below it. Vertical bars support only `full` and `floating`.

### Compact

| Key | Default | |
|---|---|---|
| `compact` | `off` | `single` — one tiled window on the workspace; `fullscreen`; `always` |
| `compactHeight` | `22` | background height in compact; `0` — unchanged |
| `compactModules` | `essentials` | `essentials` (menu, workspaces, clock, network, audio, power), `center`, `minimal`, `all` |
| `compactShape` | `full` | shape in compact; `same` — as usual |
| `compactAlpha` | `-1` | background alpha in compact |
| `compactReserve` | `keep` | `keep` — windows don't jump; `shrink` — windows take the space |
| `compactExpandOnHover` | `true` | expand on hover and while a bar panel is open |

### Workspaces

| Key | Default | |
|---|---|---|
| `wsLabelStyle` | `omarchy` | omarchy numbers circled circled-filled circled-sans circled-sans-filled parens fullwidth superscript roman roman-small kanji greek cyrillic braille dots squares diamonds stars triangles hearts hexagons bars none |
| `wsWindowIcons` | `false` | app icons inside a workspace |
| `wsIconStyle` | `color` | color mono tinted accent bubble faded glyph letter dots count |
| `wsMaxIcons` | `3` | icons per workspace, the rest is `+N` |
| `wsDedupe` | `true` | one icon per app |
| `wsShown` | `5` | workspaces always visible |
| `wsShowEmpty` | `true` | show empty ones |
| `wsActivePill` | `false` | accent pill under the active one |
| `wsActiveColor` | style | colour of the active workspace: a role or `#hex` |

## Files

| File | |
|---|---|
| `BarSkin.qml` | reads the skin, defaults, colour roles |
| `SkinFrame.qml` | the shaped background, input mask, exclusive zone |
| `SkinIsland.qml` | islands under sections |
| `SkinWorkspaces.qml` | workspaces widget that replaces `omarchy.workspaces` in this bar |
| `skins/`, `layouts/` | presets |
| `UPSTREAM.md` | stock `omarchy.bar` docs: widget catalogue, custom modules |

Changes against the stock `Bar.qml` are marked `// skin:`, so the clone is easy to rebase onto a new
Omarchy release: `diff -u $OMARCHY_PATH/shell/plugins/bar/Bar.qml Bar.qml`.

## Related

- [omarchy-launcher-skins](https://github.com/KamradSmeshnyavy/omarchy-launcher-skins) — 10 full-screen launcher skins
- [omarchy-lock-designs](https://github.com/KamradSmeshnyavy/omarchy-lock-designs) — 21 lock screen designs
- [omarchy-wallpaper-fx](https://github.com/KamradSmeshnyavy/omarchy-wallpaper-fx) — 24 wallpaper transitions
- [omarchy-image-picker-styles](https://github.com/KamradSmeshnyavy/omarchy-image-picker-styles) — six theme/wallpaper picker styles
- [omarchy-customizer](https://github.com/KamradSmeshnyavy/omarchy-customizer) — one overlay for all of them, with live preview
- [dotfiles](https://github.com/KamradSmeshnyavy/dotfiles) — where all of them live

## With the Customizer

[omarchy-customizer](https://github.com/KamradSmeshnyavy/omarchy-customizer) is one overlay (Super+Shift+T) with live preview for this plugin's settings and
the rest of the look & feel: themes, wallpapers, Hyprland animations, transparency, blur, screen shaders.
One command installs it and offers this plugin and the others:

```sh
curl -fsSL https://raw.githubusercontent.com/KamradSmeshnyavy/omarchy-customizer/main/install.sh | bash
```

## License

MIT. Based on `omarchy.bar` from [Omarchy](https://github.com/basecamp/omarchy) (MIT, © David Heinemeier Hansson).
