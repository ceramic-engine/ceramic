// Ported from gpui-kit 0.8.1: crates/base/src/theme.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.theme;

import glaze.AppContext;

/**
 * Application-wide defaults for Base behavior modules, held as a global.
 *
 * Construct with `new Theme()` and assign fields. The styled layer
 * (`glaze.kit.theme.Theme`) projects itself onto it with `syncBase`.
 * `plot` (`PlotTheme`) and `cursorBlink` (`CursorBlink`) come with their
 * modules.
 */
class Theme {

    public var appearance:ThemeAppearance = Light;

    public var tokens:SemanticThemeTokens = new SemanticThemeTokens();

    public var scrollbar:ScrollbarTheme = new ScrollbarTheme();

    public var resizable:ResizableTheme = new ResizableTheme();

    /**
     * Global defaults used by `glaze.kit.base.plot` (motionless by default).
     */
    public var plot:PlotTheme = new PlotTheme();

    /**
     * Application-wide caret blink behavior.
     */
    public var cursorBlink:glaze.kit.base.input.CursorBlink = glaze.kit.base.input.CursorBlink.defaultValue();

    public function new() {}

    /**
     * The global Base theme, or the default one when none is set. Reading it
     * in render subscribes the view to theme changes.
     */
    public static function global(cx:AppContext):Theme {

        final theme = cx.tryGlobal(Theme);
        return theme != null ? theme : new Theme();

    }

    /**
     * The global Base theme for in place edits, created when missing.
     */
    public static function globalMut(cx:AppContext):Theme {

        if (!cx.hasGlobal(Theme)) {
            cx.setGlobal(new Theme(), Theme);
        }
        return cx.globalMut(Theme);

    }

}
