// Ported from gpui-pre-web 0.3.10: src/canvas_fallback.rs (`CanvasFontFallback`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.platform;

/**
 * Controls browser-font fallback when loaded fonts lack a glyph or its emoji
 * presentation (`CeramicTextSystem.canvasFontFallback`, web only).
 */
enum abstract CanvasFontFallback(Int) from Int to Int {

    /** Use only fonts loaded into GPUI. */
    var Disabled = 0;

    /** Use Canvas for eligible emoji, including missing text-presentation symbols (the default). */
    var Emoji = 1;

    /** Also allow approximate independent rendering of eligible horizontal CJK text. */
    var EmojiAndCjk = 2;

    /** Whether the policy lets a grapheme fall back on Canvas */
    public function allows(isEmoji:Bool):Bool {
        return switch (cast this:CanvasFontFallback) {
            case Disabled: false;
            case Emoji: isEmoji;
            case EmojiAndCjk: true;
        }
    }

}
