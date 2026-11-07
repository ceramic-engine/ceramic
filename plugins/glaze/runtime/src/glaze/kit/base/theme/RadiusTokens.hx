// Ported from gpui-kit 0.8.1: crates/base/src/theme_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.theme;

import glaze.Pixels;

/**
 * The radius scale.
 */
class RadiusTokens {

    public var none:Pixels = 0.;

    public var sm:Pixels = 3.;

    public var md:Pixels = 6.;

    public var lg:Pixels = 8.;

    public var xl:Pixels = 12.;

    public var full:Pixels = 9999.;

    public function new() {}

    public function copy():RadiusTokens {

        final t = new RadiusTokens();
        t.none = none;
        t.sm = sm;
        t.md = md;
        t.lg = lg;
        t.xl = xl;
        t.full = full;
        return t;

    }

    public function equals(other:RadiusTokens):Bool {

        return other != null
            && none == other.none
            && sm == other.sm
            && md == other.md
            && lg == other.lg
            && xl == other.xl
            && full == other.full
        ;

    }

}
