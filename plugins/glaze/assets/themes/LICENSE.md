# Theme files

These 21 files are copied unmodified from gpui-kit 0.8.1 (`themes/*.json`),
<https://github.com/longbridge/gpui-kit>, Copyright 2024-2026 Longbridge,
licensed under the Apache License 2.0 (see `LICENSES/Apache-2.0-gpui-kit.txt`
at the root of this repository).

Most of them adapt a color scheme published by another project. gpui-kit
credits it in the `author` and `url` fields of each file, kept as is:

| File | Themes | Credited author | Source |
|---|---|---|---|
| `adventure.json` | Adventure, Adventure Time | iTerm2-Color-Schemes | <https://github.com/mbadolato/iTerm2-Color-Schemes> |
| `alduin.json` | Alduin | AlessandroYorba | <https://github.com/AlessandroYorba/Alduin> |
| `asciinema.json` | Asciinema | asciinema.org | <https://asciinema.org> |
| `aurora.json` | Aurora Light | Longbridge | <https://github.com/longbridge/gpui-kit> |
| `ayu.json` | Ayu Light, Ayu Dark | Zed Industries | <https://github.com/zed-industries/zed/blob/e62dd2a0e584154886ff86cc1e9e3e060558b977/assets/themes/ayu> |
| `catppuccin.json` | Catppuccin Latte, Catppuccin Frappe, Catppuccin Macchiato, Catppuccin Mocha | Catppuccino | <https://github.com/catppuccin/catppuccin> |
| `everforest.json` | Everforest Light, Everforest Dark | sainnhe | <https://github.com/sainnhe/everforest> |
| `fahrenheit.json` | Fahrenheit | iTerm2-Color-Schemes | <https://github.com/mbadolato/iTerm2-Color-Schemes> |
| `flexoki.json` | Flexoki Light, Flexoki Dark | kepano | <https://github.com/kepano/flexoki> |
| `gruvbox.json` | Gruvbox Light, Gruvbox Dark | Pavel Pertsev | <https://github.com/morhetz/gruvbox> |
| `harper.json` | Harper | iTerm2-Color-Schemes | <https://github.com/mbadolato/iTerm2-Color-Schemes> |
| `hybrid.json` | Hybrid Light, Hybrid Dark | Andrew Wong | <https://github.com/w0ng/vim-hybrid> |
| `jellybeans.json` | Jellybeans | nanotech | <https://github.com/nanotech/jellybeans.vim> |
| `kibble.json` | Kibble | iTerm2-Color-Schemes | <https://github.com/mbadolato/iTerm2-Color-Schemes> |
| `macos-classic.json` | macOS Classic Light, macOS Classic Dark | huacnlee | <https://github.com/huacnlee/zed-theme-macos-classic> |
| `mellifluous.json` | Mellifluous Light, Mellifluous Dark | Ramojus Lapinskas | <https://github.com/ramojus/mellifluous.nvim> |
| `molokai.json` | Molokai Light, Molokai Dark | Tomas Restrepo | <https://github.com/tomasr/molokai> |
| `solarized.json` | Solarized Light, Solarized Dark | Ethan Schoonover | <https://ethanschoonover.com/solarized> |
| `spaceduck.json` | Spaceduck | Guillermo Rodriguez | <https://github.com/pineapplegiant/spaceduck> |
| `tokyonight.json` | Tokyo Night, Tokyo Storm, Tokyo Moon | Folke Lemaitre | <https://github.com/folke/tokyonight.nvim> |
| `twilight.json` | Twilight | MacroMates | <https://macromates.com> |

gpui-kit ships these files under its own license and does not include the
license texts of the original color schemes. Check the upstream project before
redistributing a theme outside this plugin.

The default light and dark themes are not here: they are compiled in from
`runtime/src/gpui/component/theme/default-theme.json` (same origin and license).
Load the others at runtime with
`ThemeRegistry.globalMut(cx).loadThemesFromStr(content)`.
