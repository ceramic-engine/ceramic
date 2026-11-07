// Part of the Haxe port of gpui-pre 0.3.10: helpers for the derived `PartialEq`
// of `StyleRefinement` and `TextStyleRefinement` (src/style.rs).
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Equality of the optional fields of style refinements (`Option<T>` with
 * `T: PartialEq`).
 */
class RefinementEq {

    public static function hsla(a:Null<Hsla>, b:Null<Hsla>):Bool {
        return a == null ? b == null : b != null && a.equals(b);
    }

    public static function length(a:Null<Length>, b:Null<Length>):Bool {
        return a == null ? b == null : b != null && LengthTools.equals(a, b);
    }

    public static function definite(a:Null<DefiniteLength>, b:Null<DefiniteLength>):Bool {
        return a == null ? b == null : b != null && DefiniteLengthTools.equals(a, b);
    }

    public static function absolute(a:Null<AbsoluteLength>, b:Null<AbsoluteLength>):Bool {
        return a == null ? b == null : b != null && AbsoluteLengthTools.equals(a, b);
    }

    public static function shadows(a:Null<Array<BoxShadow>>, b:Null<Array<BoxShadow>>):Bool {
        if (a == null || b == null)
            return a == b;
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            if (!a[i].equals(b[i]))
                return false;
        }
        return true;
    }

}
