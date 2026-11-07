// Ported from gpui-pre 0.3.10: src/text_system/font_features.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The OpenType features that can be configured for a given font.
 * A list of `(tag, value)` pairs, in order.
 */
class FontFeatures {

    static var _default:FontFeatures = null;

    public final tags:Array<String>;

    public final values:Array<Int>;

    var _key:String = null;

    public function new(?tags:Array<String>, ?values:Array<Int>) {
        this.tags = tags != null ? tags : [];
        this.values = values != null ? values : [];
    }

    /** The default (empty) feature list (Rust `FontFeatures::default()`). */
    public static function defaultValue():FontFeatures {
        if (_default == null)
            _default = new FontFeatures();
        return _default;
    }

    /** Disables `calt`. */
    public static function disableLigatures():FontFeatures {
        return new FontFeatures(['calt'], [0]);
    }

    /** Builds a feature list from `(tag, value)` pairs given as two arrays. */
    public static function fromList(tags:Array<String>, values:Array<Int>):FontFeatures {
        return new FontFeatures(tags.copy(), values.copy());
    }

    /** Number of features. */
    public inline function length():Int {
        return tags.length;
    }

    /**
     * Returns whether the `calt` feature is enabled, or null if it is not set.
     */
    public function isCaltEnabled():Null<Bool> {
        for (i in 0...tags.length) {
            if (tags[i] == 'calt')
                return values[i] == 1;
        }
        return null;
    }

    /** Key identifying the content (used for hashing). */
    public function key():String {
        if (_key == null) {
            final buf = new StringBuf();
            for (i in 0...tags.length) {
                if (i > 0) buf.add(',');
                buf.add(tags[i]);
                buf.add('=');
                buf.add(values[i]);
            }
            _key = buf.toString();
        }
        return _key;
    }

    public function equals(other:FontFeatures):Bool {
        return other != null && (other == this || other.key() == key());
    }

    public function toString():String {
        return 'FontFeatures(${key()})';
    }

    /**
     * Returns true if the tag is a valid feature tag (4 ASCII alphanumeric characters).
     */
    public static function isValidFeatureTag(tag:String):Bool {
        if (tag.length != 4)
            return false;
        for (i in 0...4) {
            if (!gpui.util.Utf8.isAsciiAlphanumeric(StringTools.fastCodeAt(tag, i)))
                return false;
        }
        return true;
    }

}
