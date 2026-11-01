# Color emoji on native targets: plan

Status (2026-11-01): emoji render in color on the web (the Canvas2D fallback
ported from gpui-pre-web). On native targets they are notdef boxes: the
system font fallback finds Apple Color Emoji, but the `ttf` library reads
only outline glyphs (`glyf`, `CFF`, `CFF2`) and emoji fonts store color
bitmaps or color layers. Emoji matter for the code editor (comments,
strings, Markdown), chat and any user text.

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
   golden coverage (the reference harness can load the same file): a
   COLRv0 emoji font as an opt-in asset of the plugin.

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
