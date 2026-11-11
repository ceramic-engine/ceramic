// Ported from gpui-kit 0.8.1: crates/base/src/theme.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: deviation DEV-023 (scrollbar appearance). See docs/DEVIATIONS.md.
package glaze.kit.base.theme;

import glaze.kit.base.ScrollbarAppearance;
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

    /**
     * Glaze addition (DEV-023): how scrollbars show, hide and react to hover.
     * Null (Base's default) keeps `motion` in charge, like gpui-kit; the kit
     * theme projects its `scrollbarAppearance` here.
     */
    var _appearance:Null<ScrollbarAppearance> = null;

    public function new() {}

    public function withAppearance(appearance:Null<ScrollbarAppearance>):ScrollbarTheme {

        _appearance = appearance;
        return this;

    }

    public function appearance():Null<ScrollbarAppearance> {

        return _appearance;

    }

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
