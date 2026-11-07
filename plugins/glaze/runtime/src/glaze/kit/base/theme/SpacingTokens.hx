// Ported from gpui-kit 0.8.1: crates/base/src/theme_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.theme;

import gpui.Pixels;

/**
 * The spacing scale.
 */
class SpacingTokens {

    public var xxs:Pixels = 2.;

    public var xs:Pixels = 4.;

    public var sm:Pixels = 8.;

    public var md:Pixels = 12.;

    public var lg:Pixels = 16.;

    public var xl:Pixels = 24.;

    public var xxl:Pixels = 32.;

    public function new() {}

    public function copy():SpacingTokens {

        final t = new SpacingTokens();
        t.xxs = xxs;
        t.xs = xs;
        t.sm = sm;
        t.md = md;
        t.lg = lg;
        t.xl = xl;
        t.xxl = xxl;
        return t;

    }

    public function equals(other:SpacingTokens):Bool {

        return other != null
            && xxs == other.xxs
            && xs == other.xs
            && sm == other.sm
            && md == other.md
            && lg == other.lg
            && xl == other.xl
            && xxl == other.xxl
        ;

    }

}
