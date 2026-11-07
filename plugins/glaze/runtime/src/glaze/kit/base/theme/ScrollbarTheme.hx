// Ported from gpui-kit 0.8.1: crates/base/src/theme.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.theme;

import glaze.kit.base.Scrollbar.ScrollbarMotion;
import glaze.kit.base.Scrollbar.ScrollbarStyles;

/**
 * Global defaults used by `glaze.kit.base.Scrollbar`.
 *
 * `motion` defaults to motionless. Styled layers project their own timing;
 * Base never installs a fade or slide of its own.
 */
class ScrollbarTheme {

    var _mode:ScrollbarMode = Scrolling;

    var _motion:ScrollbarMotion = new ScrollbarMotion();

    var _styles:ScrollbarStyles = new ScrollbarStyles();

    public function new() {}

    public function withMode(mode:ScrollbarMode):ScrollbarTheme {

        _mode = mode;
        return this;

    }

    public function withMotion(motion:ScrollbarMotion):ScrollbarTheme {

        _motion = motion;
        return this;

    }

    public function withStyles(styles:ScrollbarStyles):ScrollbarTheme {

        _styles = styles;
        return this;

    }

    public function mode():ScrollbarMode {

        return _mode;

    }

    public function motion():ScrollbarMotion {

        return _motion;

    }

    public function styles():ScrollbarStyles {

        return _styles;

    }

}
