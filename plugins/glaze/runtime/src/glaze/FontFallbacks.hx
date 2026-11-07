// Ported from gpui-pre 0.3.10: src/text_system/font_fallbacks.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The fallback fonts that can be configured for a given font.
 * Fallback fonts family names are stored here.
 */
class FontFallbacks {

    final fonts:Array<String>;

    var _key:String = null;

    public function new(fonts:Array<String>) {
        this.fonts = fonts;
    }

    /** Get the fallback fonts family names */
    public inline function fallbackList():Array<String> {
        return fonts;
    }

    /** Create a font fallback from a list of strings */
    public static function fromFonts(fonts:Array<String>):FontFallbacks {
        return new FontFallbacks(fonts.copy());
    }

    /** Key identifying the content (used for hashing). */
    public function key():String {
        if (_key == null)
            _key = fonts.join('\x01');
        return _key;
    }

    public function equals(other:FontFallbacks):Bool {
        return other != null && (other == this || other.key() == key());
    }

    public function toString():String {
        return 'FontFallbacks(${fonts.join(', ')})';
    }

}
