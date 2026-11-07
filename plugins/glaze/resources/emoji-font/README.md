# Bundled emoji font

Shipped with an app only when the glaze plugin's define `glaze_bundled_emoji` is
set (see the plugin's `ceramic.yml` and README.md). The text system then loads
`assets/glaze/emoji/NotoColorEmoji.ttf.bin` as its first emoji font.

- `assets/glaze/emoji/NotoColorEmoji.ttf.bin`: Noto Color Emoji 2.057 (CBDT / CBLC
  bitmap build), unmodified copy of `2D/fonts/NotoColorEmoji.ttf` of
  <https://github.com/googlefonts/noto-emoji> at commit
  `99701e07d3d1fe1bdbcdb14964547f0fd592966f` (the file used to be at
  `fonts/NotoColorEmoji.ttf`), renamed with a `.bin` suffix so
  that Ceramic treats it as a binary asset. SHA-256
  `15671215ab769fdc7162a045d56fd7d7e477c51b04e6b3c761d914d8fdd6cc44`.
- License: the font is under the SIL Open Font License 1.1
  (`assets/glaze/emoji/OFL-NotoColorEmoji.txt`, `2D/fonts/LICENSE` of the
  repository); the emoji images are under the Apache License 2.0
  (`assets/glaze/emoji/Apache-2.0-NotoColorEmoji-images.txt`, notice from
  `2D/svg/LICENSE`); the flag images come from region-flags, public domain
  or exempt from copyright (`assets/glaze/emoji/PUBLIC-DOMAIN-region-flags.txt`,
  `third_party/region-flags/LICENSE`).
