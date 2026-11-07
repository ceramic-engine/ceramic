// Ported from gpui-kit 0.8.1: crates/base/src/theme.rs (PlotTheme)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.theme;

import gpui.base.plot.PlotMotion;

/**
 * Global defaults used by `gpui.base.plot`.
 *
 * `motion` defaults to motionless. Styled layers project their own timing;
 * Base never installs a fade or glide of its own.
 */
class PlotTheme {

    var motionValue:PlotMotion = new PlotMotion();

    public function new() {}

    public function withMotion(motion:PlotMotion):PlotTheme {
        final theme = new PlotTheme();
        theme.motionValue = motion;
        return theme;
    }

    public inline function motion():PlotMotion {
        return motionValue;
    }

}
