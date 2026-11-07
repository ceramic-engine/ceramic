// Ported from gpui-kit 0.8.1: crates/component/src/theme/registry.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.theme;

import glaze.AppContext;

/**
 * The registered themes, held as a global.
 *
 * Load theme files with `ThemeRegistry.globalMut(cx).loadThemesFromStr(json)`:
 * `globalMut` notifies the registry observer installed by `Theme.init`, which
 * reloads the active theme when its config was replaced.
 *
 * Not ported: watching a themes directory (`watch_dir`, `reload`), which
 * depends on the file system. Load the theme files as assets (for example
 * from the plugin's `assets/themes/`) and pass their content to
 * `loadThemesFromStr`.
 */
class ThemeRegistry {

    var _defaultThemes:Map<Int, ThemeConfig> = new Map();

    var _themes:Map<String, ThemeConfig> = new Map();

    /**
     * Whether themes other than the default ones were loaded.
     */
    public var hasCustomThemes(default, null):Bool = false;

    public function new() {}

    @:allow(glaze.kit.theme)
    static function init(cx:AppContext):Void {

        final registry = new ThemeRegistry();
        registry.initDefaultThemes();
        cx.setGlobal(registry, ThemeRegistry);

        // Observe changes to the theme registry to apply changes to the active theme
        cx.observeGlobal(ThemeRegistry, cx -> {
            tracker.Autorun.unobserve();
            final theme = cx.global(Theme);
            final registry = cx.global(ThemeRegistry);
            tracker.Autorun.reobserve();
            final mode = theme.mode;
            final lightTheme = theme.lightTheme.name;
            final darkTheme = theme.darkTheme.name;

            final light = registry.themes().get(lightTheme);
            final dark = registry.themes().get(darkTheme);

            // Rust assigns the configs through `Theme::global_mut`, then calls
            // `Theme::change(mode)`: one edit here, so the installed theme is
            // never mutated in place.
            Theme.edit(cx, true, theme -> {
                if (light != null) theme.lightTheme = light;
                if (dark != null) theme.darkTheme = dark;
                theme.mode = mode;
                return null;
            });
            cx.refreshWindows();
        }).detach();

    }

    public static function global(cx:AppContext):ThemeRegistry {

        return cx.global(ThemeRegistry);

    }

    public static function globalMut(cx:AppContext):ThemeRegistry {

        return cx.globalMut(ThemeRegistry);

    }

    /**
     * The map of themes by name (including default themes).
     */
    public function themes():Map<String, ThemeConfig> {

        return _themes;

    }

    /**
     * The themes sorted: default themes first, then light before dark, then
     * by name (case insensitive).
     */
    public function sortedThemes():Array<ThemeConfig> {

        final themes = [for (theme in _themes) theme];
        themes.sort((a, b) -> {
            if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
            final byMode = a.mode.compare(b.mode);
            if (byMode != 0) return byMode;
            final an = a.name.toLowerCase();
            final bn = b.name.toLowerCase();
            return an < bn ? -1 : (an > bn ? 1 : 0);
        });
        return themes;

    }

    /**
     * The default theme of every mode.
     */
    public function defaultThemes():Map<Int, ThemeConfig> {

        return _defaultThemes;

    }

    public function defaultLightTheme():ThemeConfig {

        return _defaultThemes.get(cast ThemeMode.Light);

    }

    public function defaultDarkTheme():ThemeConfig {

        return _defaultThemes.get(cast ThemeMode.Dark);

    }

    /**
     * Registers the themes of a theme file (JSON). A theme whose name is
     * already registered is ignored. Throws when the content is invalid.
     */
    public function loadThemesFromStr(content:String):Void {

        final themeSet = ThemeSet.parse(content);
        for (theme in themeSet.themes) {
            if (!_themes.exists(theme.name)) {
                _themes.set(theme.name, theme);
                hasCustomThemes = true;
            }
        }

    }

    function initDefaultThemes():Void {

        for (theme in DefaultThemeColors.themes()) {
            if (theme.mode.isDark()) {
                _defaultThemes.set(cast ThemeMode.Dark, theme);
            }
            else {
                _defaultThemes.set(cast ThemeMode.Light, theme);
            }
        }
        _themes = new Map();
        for (theme in _defaultThemes) {
            _themes.set(theme.name, theme);
        }

    }

}
