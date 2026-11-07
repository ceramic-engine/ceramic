// Ported from gpui-kit 0.8.1: crates/component/src/theme/registry.rs (DEFAULT_THEME, DEFAULT_THEME_COLORS)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.theme;

/**
 * The default light and dark themes of `default-theme.json` (embedded at
 * compile time), resolved over all-zero colors once, on first use.
 */
@:allow(gpui.component.theme)
class DefaultThemeColors {

    static var colors:Null<Map<Int, ThemeColor>> = null;

    static var highlights:Null<Map<Int, Dynamic>> = null;

    /**
     * The content of `default-theme.json`.
     */
    public static function json():String {

        return ThemeMacro.defaultThemeJson();

    }

    /**
     * The theme configs of `default-theme.json`.
     */
    public static function themes():Array<ThemeConfig> {

        return ThemeSet.parse(json()).themes;

    }

    static function init():Void {

        colors = new Map();
        highlights = new Map();
        for (theme in themes()) {
            final themeColor = new ThemeColor();
            themeColor.applyConfigColors(theme, new ThemeColor());
            colors.set(cast theme.mode, themeColor);
            highlights.set(cast theme.mode, theme.highlight);
        }

    }

    /**
     * The default colors of the given mode. Shared: copy before editing.
     */
    public static function get(mode:ThemeMode):ThemeColor {

        if (colors == null) init();
        return colors.get(cast mode);

    }

    /**
     * The raw highlight style of the default theme of the given mode.
     */
    public static function highlight(mode:ThemeMode):Null<Dynamic> {

        if (highlights == null) init();
        return highlights.get(cast mode);

    }

}
