// Ported from gpui-kit 0.8.1: crates/base/src/theme_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.theme;

import gpui.BoxShadow;
import gpui.Hsla;

/**
 * The elevation shadows. Empty lists by default (no shadow).
 */
class ShadowTokens {

    public var sm:Array<BoxShadow>;

    public var md:Array<BoxShadow>;

    public var lg:Array<BoxShadow>;

    public function new(?sm:Array<BoxShadow>, ?md:Array<BoxShadow>, ?lg:Array<BoxShadow>) {

        this.sm = sm != null ? sm : [];
        this.md = md != null ? md : [];
        this.lg = lg != null ? lg : [];

    }

    public static function elevations(color:Hsla):ShadowTokens {

        return new ShadowTokens(
            [boxShadow(0., 1., 2., 0., color)],
            [boxShadow(0., 4., 8., -2., color)],
            [boxShadow(0., 12., 24., -4., color)]
        );

    }

    static function boxShadow(x:Float, y:Float, blur:Float, spread:Float, color:Hsla):BoxShadow {

        return new BoxShadow(x, y, color).withBlurRadius(blur).withSpreadRadius(spread);

    }

    public function copy():ShadowTokens {

        return new ShadowTokens(sm.copy(), md.copy(), lg.copy());

    }

    static function listEquals(a:Array<BoxShadow>, b:Array<BoxShadow>):Bool {

        if (a.length != b.length) return false;
        for (i in 0...a.length) {
            if (!a[i].equals(b[i])) return false;
        }
        return true;

    }

    public function equals(other:ShadowTokens):Bool {

        return other != null && listEquals(sm, other.sm) && listEquals(md, other.md) && listEquals(lg, other.lg);

    }

}
