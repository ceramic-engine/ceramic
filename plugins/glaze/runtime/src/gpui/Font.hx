// Ported from gpui-pre 0.3.10: src/text_system.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The configuration details for identifying a specific font.
 *
 * Fonts are compared by value with `equals()`, and `key()` returns a string
 * that identifies them in maps (Rust derives `Hash` / `Eq`).
 */
class Font {

    /**
     * The font family name.
     *
     * The special name ".SystemUIFont" is used to identify the system UI font, which varies based on platform.
     */
    public var family:String;

    /** The font features to use. */
    public var features:FontFeatures;

    /** The fallbacks fonts to use. */
    public var fallbacks:Null<FontFallbacks>;

    /** The font weight. */
    public var weight:FontWeight;

    /** The font style. */
    public var style:FontStyle;

    public function new(family:String, ?features:FontFeatures, ?fallbacks:FontFallbacks, ?weight:FontWeight, ?style:FontStyle) {
        this.family = family;
        this.features = features != null ? features : FontFeatures.defaultValue();
        this.fallbacks = fallbacks;
        this.weight = weight != null ? weight : FontWeight.NORMAL;
        this.style = style != null ? style : FontStyle.Normal;
    }

    /** Get a `Font` for a given name (Rust `font()`). */
    public static inline function of(family:String):Font {
        return new Font(family);
    }

    /** The default font (`.SystemUIFont`). */
    public static inline function defaultValue():Font {
        return new Font('.SystemUIFont');
    }

    /** Returns a copy of this font, set to be bold */
    public function bold():Font {
        final result = clone();
        result.weight = FontWeight.BOLD;
        return result;
    }

    /** Returns a copy of this font, set to be italic */
    public function italic():Font {
        final result = clone();
        result.style = FontStyle.Italic;
        return result;
    }

    public function clone():Font {
        return new Font(family, features, fallbacks, weight, style);
    }

    /**
     * A string identifying this font descriptor (family, features,
     * fallbacks, weight and style).
     */
    public function key():String {
        return family + '\x00' + features.key() + '\x00' + (fallbacks != null ? fallbacks.key() : '-') + '\x00' + (weight:Float) + '\x00' + (cast style:Int);
    }

    public function equals(other:Font):Bool {
        return other != null && family == other.family && features.equals(other.features)
            && (fallbacks == null ? other.fallbacks == null : fallbacks.equals(other.fallbacks))
            && (weight:Float) == (other.weight:Float) && style == other.style;
    }

    public function toString():String {
        return 'Font($family, weight=${(weight:Float)}, style=${(cast style:Int)}, features=${features.key()}${fallbacks != null ? ', fallbacks=' + fallbacks.fallbackList().join(',') : ''})';
    }

    /**
     * Maps well-known virtual font names to their concrete equivalents.
     */
    public static function fontNameWithFallbacks(name:String, system:String):String {
        // Note: the "Zed Plex" fonts were deprecated as we are not allowed to use "Plex"
        // in a derived font name. They are essentially indistinguishable from IBM Plex/Lilex,
        // and so retained here for backward compatibility.
        return switch name {
            case '.SystemUIFont': system;
            case '.ZedSans' | 'Zed Plex Sans': 'IBM Plex Sans';
            case '.ZedMono' | 'Zed Plex Mono': 'Lilex';
            case _: name;
        }
    }

}
