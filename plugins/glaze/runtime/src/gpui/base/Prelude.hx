// Ported from gpui-kit 0.8.1: crates/base/src/styled.rs (h_flex, v_flex, box_shadow), crates/base/src/lib.rs (is_mobile)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.BoxShadow;
import gpui.Div;
import gpui.Hsla;
import gpui.Pixels;

using gpui.base.StyledExt;

/**
 * Free functions of gpui-base, used with `import gpui.base.Prelude.*;`.
 */
class Prelude {

    /**
     * A row that centers its children on the cross axis.
     *
     * See `StyledExt.hFlex` for the cross-axis rule, which is not symmetric
     * with `vFlex`.
     */
    public static function hFlex():Div {
        return gpui.Prelude.div().hFlex();
    }

    /**
     * A column whose children stretch across the cross axis.
     *
     * See `StyledExt.vFlex` for the cross-axis rule, which is not symmetric
     * with `hFlex`.
     */
    public static function vFlex():Div {
        return gpui.Prelude.div().vFlex();
    }

    public static function boxShadow(x:Pixels, y:Pixels, blur:Pixels, spread:Pixels, color:Hsla):BoxShadow {
        final shadow = new BoxShadow(x, y, color);
        shadow.blurRadius = blur;
        shadow.spreadRadius = spread;
        shadow.inset = false;
        return shadow;
    }

    /**
     * Returns whether the application is compiled for iOS or Android.
     *
     * This is a compile-time platform check, not a screen-size or input-device check.
     */
    public static inline function isMobile():Bool {
        #if (ios || android)
        return true;
        #else
        return false;
        #end
    }

}
