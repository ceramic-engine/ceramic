# Color emoji on native targets: plan

Status (2026-11-01): steps 1 to 6 are done (see "Done" below). Emoji
render in color on macOS through the system fallback (Apple Color Emoji,
`sbix` + `morx`); the `ttf` library also reads `COLR` / `CPAL` and `CBDT` /
`CBLC`, and the fallback lists Segoe UI Emoji (Windows) and Noto Color
Emoji (Linux), not tested on those systems yet. On the web, emoji still come
from the Canvas2D fallback ported from gpui-pre-web. Step 7 (optional
bundled font) is done (2026-11-02, see below).

## Done

- Step 7, bundled emoji font: the define `glaze_bundled_emoji` ships Noto
  Color Emoji 2.057 (the `CBDT` build, 10.7 MB, `emoji-font/assets`, see
  `emoji-font/README.md`) through the plugin's `ceramic.yml`, and the
  plugin adds it to the default text system right after Inter and
  JetBrains Mono, before the app is ready (`glaze.platform.BundledEmojiFont`,
  `CeramicTextSystem.addBundledEmojiFace()`). Native targets and Node.js read
  only its tables (92 KB) through `ceramic.Files.getBytesRange()`;
  browsers load the whole file as a binary asset. It is a face of the font
  database, so it comes before the system emoji font and the browser
  canvas, which keep the graphemes it lacks (CJK keeps its canvas policy).
  The golden scenes `kit-emoji-bundled-light` / `-dark`
  (`reference/src/kit_scenes14_emoji.rs`, `GLAZE_GOLDEN_VARIANT=glaze_bundled_emoji`)
  compare emoji text at 12 to 40 px, an input and the editor with the real
  GPUI loading the same file: they found one rule of cosmic-text the port
  did not follow, a cluster stays on the primary font when that font maps
  it without a notdef (variation selector 16 is default ignorable), so
  `❤️` after Inter text is Inter's monochrome heart in GPUI (ttf
  `Shaper.primaryKeepsCoveredEmoji`, on in `CeramicTextSystem`). The
  COLRv1 build (5.0 MB) is not used: swash 0.2.10, GPUI's rasterizer, only
  reads `COLR` version 0, so GPUI would draw it without color.

- `ttf` (pure Haxe, no Ceramic): `ttf.color.ColorGlyphs` (`Font.color()`)
  renders color glyphs like swash's `ColorOutline(0)` then
  `ColorBitmap(BestFit)` sources: `Sbix`, `Cbdt` (PNG strikes: first strike
  at least as large as the size, scaled with swash's Mitchell filter, Apple
  Color Emoji's 100 font unit drop), `Colr` (version 0 layers, palette 0,
  swash's `blit`), its own `Inflate` and `Png` (every color type and depth,
  interlacing), Apple's `flip` glyphs. `Font.fromSource()` reads only the
  table directory and the small tables of a face (Apple Color Emoji: 742 KB
  of 192 MB, under 1 ms), images are read glyph by glyph.
  `ttf.layout.Morx`: noncontextual, contextual and ligature subtables with
  the default features, used for fonts without `GSUB` like HarfBuzz. The
  shaper prefers fonts with color glyphs for emoji sequences (emoji
  presentation, VS16, skin tones, regional indicators, keycaps) and fonts
  without for text presentation, and groups emoji sequences in one cluster
  like HarfBuzz. Checked against swash 0.2.10 (placements exact, pixels
  within 2 levels) and HarfBuzz 14 (`morx` glyphs and clusters), on node,
  hxcpp and the interpreter.
- `SystemFontFallback`: an emoji class (Apple Color Emoji, Segoe UI Emoji,
  Noto Color Emoji or Twemoji files), loaded lazily through
  `ceramic.Files.getBytesRange()` (new in Ceramic, with `Files.getSize()`).
- `CeramicTextSystem`: Apple Color Emoji and Segoe UI Emoji are known emoji
  fonts (polychrome glyphs, straight alpha BGRA tiles painted by
  `TextPainter.emitEmoji`), the emoji font is loaded for emoji sequences,
  GPUI's glyph 3 hack only applies to Noto Color Emoji.
- Editor: gpui-kit moves the caret and deletes by code point
  (`RopeExt::clip_offset` on char boundaries), not by grapheme; the port does
  the same (`tests.kit.InputEmojiTest`: movement, deletion, selections,
  UTF-16 offsets, hit testing, line height).

## What GPUI does

- macOS: CoreText draws Apple Color Emoji in color (gpui-pre-apple
  `text_system.rs`, color glyph runs as polychrome sprites); ZWJ sequences,
  skin tones, flags and keycaps come from the font's `morx` table through
  CoreText.
- Linux: cosmic-text with swash: `CBDT` (Noto Color Emoji bitmaps) and
  `COLR` layers, polychrome sprites; sequences through `GSUB` ligatures.
- Web: Canvas2D, already ported.

## Formats to support

| Platform | Font | Color data | Sequences |
|---|---|---|---|
| macOS | Apple Color Emoji.ttc (192 MB) | `sbix`: PNG per glyph and size (20, 32, 40, 48, 64, 96, 160 px) | `morx` (AAT), not `GSUB` |
| Windows | Segoe UI Emoji (seguiemj.ttf) | `COLR` v0 (layers of flat colored outlines) + `CPAL`, v1 on Windows 11 | `GSUB` |
| Linux, Android | Noto Color Emoji | `CBDT`/`CBLC` (PNG bitmaps, 136 px) or `COLR` v1 builds | `GSUB` |
| Opt-in bundle | Noto Color Emoji, COLRv0 build or Twemoji COLR | `COLR` | `GSUB` |

The port already has the rendering side: `TextPainter.emitEmoji` emits
color glyph tiles as polychrome sprites (straight alpha, like GPUI's emoji
tiles), used by the web fallback today.

## Steps

1. **`sbix` reading in `ttf`** (macOS first, the owner's platform): parse
   the strike table, pick the strike closest to the rendered size times the
   scale factor (round up), decode the PNG (Ceramic has PNG decoding on every
   backend; a pure Haxe decoder such as `format.png` keeps `ttf` free of
   Ceramic), scale it to the glyph box with the font's `sbix` origin offsets,
   produce a BGRA tile. Metrics from `hmtx` as today. Glyph ids for single
   code points come from `cmap` (format 12 for the astral planes, check it
   is supported).
2. **`morx` ligatures** for Apple Color Emoji: ZWJ sequences (family,
   professions), skin tone modifiers, flags (regional indicator pairs),
   keycaps are `morx` ligature subtables (type 2) and contextual
   substitutions. Implement the subset Apple Color Emoji uses (extended
   state tables, ligature and noncontextual subtables) in the `ttf` shaper,
   applied per emoji grapheme. Without it, a sequence shows as its separate
   parts (still in color), which is acceptable as an intermediate lot.
3. **`COLR` v0 + `CPAL`** (Windows, and a portable bundle): each glyph is a
   list of (outline glyph, palette index) layers; rasterize each layer with
   the existing outline rasterizer and composite them into a BGRA tile.
   `COLR` v1 (gradients, transforms, composite modes) after, only if a
   target needs it (Windows 11 Segoe UI Emoji keeps v0 tables too).
4. **`CBDT`/`CBLC`** (Linux and Android Noto Color Emoji): same PNG path as
   `sbix` with a different index format.
5. **Fallback wiring**: `SystemFontFallback` gains the emoji class
   (currently skipped): emoji graphemes go to the platform emoji font
   (`Apple Color Emoji`, `Segoe UI Emoji`, `Noto Color Emoji`), the face is
   flagged as an emoji font (`isKnownEmojiFont` today only knows
   `NotoColorEmoji`), and the text system produces polychrome glyphs for it
   like the web path. Grapheme segmentation already exists
   (`unicode-segmentation`).
6. **Editor**: emoji in the code editor need correct cursor movement,
   selection and hit testing over multi code point graphemes (already
   grapheme based in the input engine, to verify with ZWJ sequences, skin
   tones and flags), and the line height must not grow (GPUI keeps the line
   height of the primary font). Tests on the editor with emoji text.
7. **Optional bundled emoji font** for identical output everywhere and for
   golden coverage (the reference harness can load the same file).
   DECIDED by the owner 2026-11-02: **Noto Color Emoji**, behind a flag (a
   define of the plugin) that ships the font with the app; without the
   flag, emoji keep coming from the system emoji font (the current
   fallback), and with it the bundled font comes first, the system font
   staying the fallback for what it lacks. The CBDT build
   (`NotoColorEmoji.ttf`, read by `ttf`) unless the COLRv1 build is
   supported by then; license OFL (font) and Apache 2.0 (images), credited
   in NOTICE.md.

## Tests

- `ttf` suite: `sbix` strike selection and PNG decode on a small test font
  (build one with a few glyphs, or use a subset of an open source `sbix`
  font such as the Twemoji `sbix` build), `COLR` layer compositing, `morx`
  ligatures on known sequences, `CBDT` on a Noto subset.
- Port unit tests (native mac, skipped where the system font is missing):
  an emoji string gives polychrome glyphs with non-empty BGRA tiles; a ZWJ
  family is one glyph with `morx`; advances match the font.
- A port-only native capture check (like `run-port-checks.sh` on the web).
- Golden: only with the bundled font of step 7 (the truths come from the
  real GPUI with explicitly loaded fonts).

## Order and size

Steps 1 and 5 together give color emoji on macOS (single code point emoji,
sequences shown as their parts): the first deliverable. Then 6 (editor
behaviour), then 2 (sequences on macOS), then 3 (Windows), then 4 (Linux),
then 7. Each step goes through the usual gate (unit suites node and native,
golden suite unchanged, `ttf` suite on node, cpp and interp).
