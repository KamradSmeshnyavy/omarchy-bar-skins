# Omarchy Bar Skins

[🇬🇧 English](README.md)

Замена верхнего бара [Omarchy](https://omarchy.org): стоковый `omarchy.bar` с прослойкой скинов. Все
виджеты, панели и жесты стокового бара работают как раньше — скин меняет только то, как бар нарисован.

- **28 скинов** (`liquid` рисует своё стекло: блик вдоль бара, яркую освещённую кромку, двойной светлый ободок и подсветку акцентом с другой стороны; ключ `liquid: true` работает в любом скине) — floating, islands, pill, notch, underline, hug, frame, dotmatrix, paper, soft, brutal, bevel, glass, liquid, notches, glyph-pill, surface-dock, neon, capsules, autohide, …
- **10 раскладок** — centered, bottom, left-vertical, dotmatrix, right-heavy, media-center, …
- **Compact** — бар сжимается в тонкую полосу (при одном окне, в полноэкранном режиме или всегда) и
  разворачивается по наведению
- **Workspaces** — 20+ стилей подписей (римские, кандзи, греческие, в кружках, брайль, leds…), иконки приложений,
  плашка под активным
- Цвета — роли темы: бар перекрашивается при каждом `omarchy theme set`

![Скины](screenshots/skins.webp)

![Вертикальный бар](screenshots/vertical.webp)

<!-- Demo video: repo-videos/omarchy-bar-skins.mp4 — drag it here when editing this file on GitHub -->

![Compact](screenshots/compact.webp)

## Установка

```sh
omarchy plugin add https://github.com/KamradSmeshnyavy/omarchy-bar-skins --enable
omarchy restart shell
```

`--enable` делает его текущим баром (`bar.id` в `~/.config/omarchy/shell.json`). Если плагин не
загрузится, шелл сам вернёт стоковый бар. Вернуть вручную: `omarchy plugin enable omarchy.bar`.


## Требования

Omarchy 4 (Quattro) с его оболочкой. Проверено на Omarchy 4.0.6 и Quickshell 0.3.2.

- Необязательно: `cava` — модуль визуализатора звука.
- Дизайны DOT-MATRIX используют шрифты из [Customizer](https://github.com/KamradSmeshnyavy/omarchy-customizer) (Doto, Space Grotesk, Space Mono); без них — шрифт Omarchy.

## Удаление

```sh
omarchy plugin enable omarchy.bar      # сначала вернуть стоковый
omarchy plugin remove kamradsmeshnyavy.bar
omarchy restart shell
```

Настройки остаются в `~/.config/omarchy/bar-skin.json`, `~/.config/omarchy/bar-skins/`, `~/.config/omarchy/bar-layouts/` — удалите их вручную, если не нужны.

## Выбрать скин

Активный скин — `~/.config/omarchy/bar-skin.json`; бар следит за файлом и меняется на лету:

```sh
cp ~/.config/omarchy/plugins/kamradsmeshnyavy.bar/skins/islands.json ~/.config/omarchy/bar-skin.json
```

Раскладка дописывается в секцию `bar` файла `shell.json`:

```sh
cd ~/.config/omarchy
jq --slurpfile l plugins/kamradsmeshnyavy.bar/layouts/centered.json '.bar += $l[0]' shell.json > shell.json.new \
  && mv shell.json.new shell.json
```

В оверлее [Customizer](https://github.com/KamradSmeshnyavy/omarchy-customizer) всё это делается
с живым предпросмотром (Super+Shift+T: Bar Skin, Bar Layout, Bar Tweaks):

![Customizer](screenshots/customizer.webp)

## Схема скина

```jsonc
{
  "shape": "floating",        // full floating pill islands notch underline hug frame
  "height": 30,               // 0 = стоковая высота
  "gap": 6,                   // отступ от края экрана
  "margin": 10,               // поля слева/справа
  "width": 1.0,               // доля ширины (floating/pill/notch)
  "radius": 12,
  "frameWidth": 8,            // frame: толщина рамки по остальным краям экрана
  "padding": -1,              // отступ модулей от краёв подложки; -1 = сток
  "islandGap": 6,             // поля островов
  "background": "bar",        // цвет: роль или #hex
  "backgroundAlpha": 0.85,    // -1 = альфа из темы
  "gradient": "accent",       // второй цвет горизонтального градиента (нет ключа — без градиента)
  "border": "accent", "borderWidth": 1, "borderAlpha": 0.6,
  "text": "bar", "active": "bar",
  "shadow": true,
  "glow": false,              // ореол цвета рамки вместо тени
  "autoHide": false,          // прятать за край, выезжает по наведению
  "moduleStyle": "plain",     // plain pills hover — подложка у каждого модуля
  "moduleBackground": "foreground", "moduleAlpha": 0.08,
  "spacing": 0,               // зазор между модулями
  "font": "",                 // пусто = системный шрифт
  "texture": "",              // PNG-тайл поверх подложки (~ раскрывается); на тёмной — <имя>-dark.png
  "textureAlpha": 0.9,
  "hardShadow": 0,            // жёсткая смещённая тень в px цветом рамки (брутализм)
  "bevel": false,             // ретро-кант: светлый сверху-слева, тёмный снизу-справа
  "transparent": false        // стоковый прозрачный режим (пишется в shell.json)
}
```

Цвет — `bar` (стоковый цвет бара из `[bar]` темы), роль шелла (`background`, `foreground`, `accent`,
`muted`, `urgent`), любой ключ `colors.toml` текущей темы (`red`, `cyan`, `lighter_background`, …)
или `#rrggbb`. Роли перекрашиваются вместе с темой.

Формы: `full` — сток; `floating` — полоса с отступами; `pill` — floating с радиусом в полвысоты;
`islands` — остров под каждой секцией; `notches` — остров под каждой секцией, свисающий с края экрана, скруглены
только углы к экрану (по мотивам Vitreus; скин и раскладка `notches`); `notch` — «чёлка» у края; `underline` — линия по краю; `hug` —
полоса во всю ширину с вогнутыми углами; `frame` — полоса и рамка цвета бара по остальным трём краям
экрана со скруглёнными внутренними углами (`radius`, минимум 8), место под рамку зарезервировано, окна
внутри. Вертикальный бар умеет только `full`, `floating` и `frame`.

### Compact

| Ключ | Умолч. | |
|---|---|---|
| `compact` | `off` | `single` — на workspace одно тайловое окно; `fullscreen`; `always`; `empty` — на столе нет окон |
| `compactHeight` | `22` | высота подложки в compact; `0` — не менять |
| `compactModules` | `essentials` | `essentials` (меню, workspaces, часы, сеть, звук, питание), `center`, `minimal`, `all`, `taskbar` (только модуль Taskbar) |
| `compactShape` | `full` | форма в compact; `same` — как обычно |
| `compactAlpha` | `-1` | альфа фона в compact |
| `compactReserve` | `keep` | `keep` — окна не дёргаются; `shrink` — окна получают место |
| `compactExpandOnHover` | `true` | разворачивать по наведению и пока открыта панель бара |

### Workspaces

| Ключ | Умолч. | |
|---|---|---|
| `wsLabelStyle` | `omarchy` | omarchy numbers circled circled-filled circled-sans circled-sans-filled parens fullwidth superscript roman roman-small kanji greek cyrillic braille dots leds squares diamonds stars triangles hearts hexagons bars none |
| `wsWindowIcons` | `false` | иконки окон внутри workspace |
| `wsIconStyle` | `color` | color mono tinted accent bubble faded glyph letter dots count |
| `wsMaxIcons` | `3` | иконок на workspace, остальные — «+N» |
| `wsDedupe` | `true` | одно приложение — одна иконка |
| `wsShown` | `5` | сколько workspace видно всегда |
| `wsShowEmpty` | `true` | показывать пустые |
| `wsActivePill` | `false` | плашка цвета акцента под активным |
| `wsActiveColor` | как в стиле | цвет текущего workspace: роль темы или `#hex` |


**Бар Vitreus** (по мотивам [Vitreus](https://github.com/natepayn3/Vitreus), код свой): скины `vitreus-island` (одна скруглённая стеклянная пластина сверху), `vitreus-frame` (форма caelestia — стеклянная полоса сбоку и тонкая рамка вокруг экрана со скруглёнными внутренними углами, одним куском стекла под окнами) и `vitreus-notches` (три стеклянных куска свисают с верхнего края и вливаются в него вогнутыми изгибами), раскладки `vitreus-island`, `vitreus-frame-left`, `vitreus-notches`. Ключ скина `"vitreus": true` рисует бар настоящим жидким стеклом (`LiquidGlass.qml`, `shaders/liquidglass.frag`: обои преломляются у края, радужная кайма, ободок, купол света и блик под курсором; настройки — `~/.config/omarchy/glass.json`). Ключ скина `"tabs": true` (включён в обоих скинах `vitreus-frame`, и в пластиковом) добавляет язычки посередине верхней и нижней кромок рамки (`VitTabs.qml`): при наведении из рамки вырастает язычок 81 × 23 с тремя точками, вливаясь в неё вогнутыми изгибами, — верхний открывает лаунчер приложений, нижний — Prefs (Super+Alt+I). Ещё бар пишет свою геометрию в `$XDG_RUNTIME_DIR/omarchy-bar-geom.json` (край, толщина, рамка, кнопки модулей по экранам) — панели других плагинов растут из своей кнопки. **Панели модулей сливаются с баром.** У бара во всю длину края (рамка, сплошной) карточки панелей модулей (звук, сеть, Bluetooth, монитор, клоны DOT-MATRIX — всё, что рисует `KeyboardPanel` из `qs.Ui`) вливаются в него: бар реализует `notePopoutCard`, а `PopBridge.qml` рисует поверх карточки мост в слое Overlay — заливает зазор цветом карточки, спрямляет её углы у бара, продолжает контур до кромки бара и добавляет вогнутые углы (`MergeFillet.qml`). Ключ скина `"mergePopups": false` выключает; у плавающих пилюль и островов зазор остаётся. Меню трея (xdg-popup) не охвачено. Мост перекрашивает весь контур карточки в цвет контура бара — стык одного цвета. **Модули на рабочем столе.** Любой модуль бара, утащенный дальше 60 px от бара, уходит из раскладки на стол (`~/.config/omarchy/bar-desk.json`): карточка цвета бара с его контуром (`omarchy-bar-desk`, под окнами), в ней тот же модуль — клики работают как на баре, тянуть можно куда угодно, у кромки рамки / бара во всю длину края карточка встаёт вплотную и сливается (рамка там разрывает контур); отпущенная рядом с баром — возвращается в раскладку, в ту треть бара, напротив которой отпущена. За краем бара Hyprland перестаёт слать бару события курсора, поэтому дальше модуль «несёт» окно стола (встаёт там, где отпустили кнопку или где курсор замер на 0,7 с). **Перенос панелей модулей.** У карточки каждой панели модуля на верхней кромке — красный язычок: потянул — карточка уходит от бара и свободно ездит по столу (панель остаётся открытой). Отпущенная ближе 32 px от кромки рамки / бара во всю длину края встаёт к ней вплотную и сливается с ней тем же мостом; после закрытия панель снова открывается у бара.

**Новые раскладки.** `glyph-rice` (бар [glyph-rice](https://github.com/Nebelung-cloud/glyph-rice), перенесён модулями `modules/Glyph*.qml`: знак-кольцо из точек — лаунчер, центр краснеет при записи экрана и занятом микрофоне; столы точками, текущий вытягивается в пилюлю; заголовок окна вдоль пилюли; часы Doto посередине — клик: дашборд; дуги Wi-Fi, Bluetooth, звук — колесо: громкость — и стоящая батарея, дышит на зарядке; клик — Quick, правый — меню выключения. Части трея и порядок — `"parts": "wifi,bluetooth,sound,battery"` у записи `glyph-tray`, длина заголовка — `"length"` у `glyph-title`), `notches` (три выреза: лаунчер с воркспейсами, часы, статус), `glyph-left` (левая пилюля по мотивам
glyph-rice: лаунчер и воркспейсы сверху, RunCat посередине, статус, таймер фокуса и часы снизу — со скином `glyph-pill`),
`taskbar` (снизу: воркспейсы, модуль `Taskbar` посередине, статус — со скином `surface-dock`). **Таскбар → док** (по
мотивам surface-dots): модуль `Taskbar` показывает окна стола (клик — фокус), а на пустом столе — закреплённые
приложения дока Omarchy (`omarchy dock pin <id>`; клик — запуск); у скина `surface-dock` `"compact": "empty"` +
`"compactModules": "taskbar"`, поэтому на пустом столе бар сжимается в пилюлю по центру только с этим модулем.

## Файлы

| Файл | |
|---|---|
| `BarSkin.qml` | чтение скина, дефолты, цвета-роли |
| `SkinFrame.qml` | подложка по форме, маска ввода, exclusive zone |
| `SkinIsland.qml` | острова под секциями |
| `SkinWorkspaces.qml` | workspaces, подменяет `omarchy.workspaces` в этом баре |
| `modules/` | кастомные QML-модули для раскладки `dotmatrix` (`DotMatrixMark`, `ActiveAppIcon`, `BatteryGauge`, `DotClock`, `PrivacyLed`) и для любой раскладки: `RunCat` (пиксельный кот бежит быстрее под нагрузкой CPU), `CpuRamRings` (радиальные CPU / RAM), `CavaDots` (спектр 8×5 точками, только пока играет музыка), `FocusTimer` (помодоро: клик — старт / пауза, ПКМ — сброс, колесо — ±5 мин; состояние переживает перезапуск оболочки) — ставятся из Customizer → Bar Widgets → «Не на баре»; трей, Wi-Fi, Bluetooth и звук в раскладке — клоны виджетов Omarchy `kamradsmeshnyavy.{tray,network,bluetooth,audio}` из dotfiles |
| `skins/`, `layouts/` | пресеты |
| `UPSTREAM.md` | документация стокового `omarchy.bar`: каталог виджетов, свои модули |

Правки стокового `Bar.qml` помечены `// skin:` — после обновления Omarchy их легко перенести:
`diff -u $OMARCHY_PATH/shell/plugins/bar/Bar.qml Bar.qml`.

## Вместе с Customizer

[omarchy-customizer](https://github.com/KamradSmeshnyavy/omarchy-customizer) — один оверлей (Super+Shift+T) с живым предпросмотром для настроек этого
плагина и всего остального оформления: темы, обои, анимации Hyprland, прозрачность, блюр, шейдеры экрана.
Поставьте его рядом с этим плагином (остальные компаньоны он найдёт сам):

```sh
omarchy plugin add https://github.com/KamradSmeshnyavy/omarchy-customizer --enable
```

## Лицензия

GPL-3.0 (см. [LICENSE](LICENSE); прежние версии — MIT), авторы заимствований — в [NOTICE](NOTICE). Основано на
`omarchy.bar` из [Omarchy](https://github.com/basecamp/omarchy) (MIT, © David Heinemeier Hansson); модули `Glyph*` — из
[glyph-rice](https://github.com/Nebelung-cloud/glyph-rice) (GPL-3.0).
