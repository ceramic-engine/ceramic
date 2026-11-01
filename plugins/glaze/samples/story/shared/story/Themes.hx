// Ported from gpui-kit 0.8.1: crates/story/src/themes.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import gpui.Action;
import gpui.App;
import gpui.AppContext;
import gpui.base.IndexPath;
import gpui.base.theme.ScrollbarMode;
import gpui.component.IconName;
import gpui.component.command.CommandItem;
import gpui.component.theme.Theme;
import gpui.component.theme.ThemeConfig;
import gpui.component.theme.ThemeMode;
import gpui.component.theme.ThemeRegistry;

/**
 * Rust `struct State`: the persisted settings of the gallery.
 */
class StoryThemeState {

    public var theme:String = 'Default Light';

    public var radius:Null<Float> = null;

    public var scrollbarMode:Null<ScrollbarMode> = null;

    public var showFpsMonitor:Null<Bool> = null;

    public function new() {}

}

@:action(namespace = themes, noJson)
class SwitchTheme implements Action {
    public final value:String;
}

@:action(namespace = themes, noJson)
class SwitchThemeMode implements Action {
    public final value:ThemeMode;
}

/**
 * Opens the Command palette to pick a theme.
 */
@:action(namespace = themes) class SelectTheme implements Action {}

/**
 * The themes of the gallery: the embedded theme set, the theme palette
 * entries, and the theme switching actions.
 *
 * Rust persists the settings in `target/state.json` and watches a
 * `./themes` folder on native targets; the port behaves like gpui-kit's web
 * build: embedded themes, default settings, nothing persisted (TODO: a
 * Ceramic persistent storage could keep the state).
 */
class Themes {

    static function applyThemeConfig(themeConfig:ThemeConfig, cx:AppContext):Void {
        Theme.update(cx, theme -> theme.applyConfig(themeConfig));
    }

    public static function beginThemePreview(cx:AppContext):Void {
        AppState.globalMut(cx).previewingTheme = true;
    }

    public static function finishThemePreview(cx:AppContext):Void {
        AppState.globalMut(cx).previewingTheme = false;
    }

    static function applyPersistedRadius(state:StoryThemeState, cx:AppContext):Void {
        final radius = state.radius;
        if (radius == null) return;

        Theme.update(cx, theme -> {
            theme.radius = radius;
            theme.radiusLg = radius > 0. ? radius + 2. : 0.;
        });
    }

    public static function init(cx:AppContext):Void {
        final embedded = EmbeddedThemes.embeddedThemes();
        final registry = ThemeRegistry.globalMut(cx);
        final names = [for (name in embedded.keys()) name];
        names.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        for (name in names) {
            try {
                registry.loadThemesFromStr(embedded.get(name));
            } catch (e:Dynamic) {
                trace('Failed to load embedded theme $name: $e');
            }
        }

        final state = new StoryThemeState();

        if (state.scrollbarMode != null) {
            Theme.setScrollbarMode(state.scrollbarMode, cx);
        }
        applyPersistedRadius(state, cx);
        if (state.showFpsMonitor != null) {
            AppState.globalMut(cx).showFpsMonitor = state.showFpsMonitor;
        }
        cx.refreshWindows();

        cx.onAction(SwitchTheme, (switchTheme, cx) -> {
            final themeName = switchTheme.value;
            final themeConfig = ThemeRegistry.global(cx).themes().get(themeName);
            if (themeConfig != null) {
                applyThemeConfig(themeConfig, cx);
            }
            cx.refreshWindows();
        });
        cx.onAction(SwitchThemeMode, (switchMode, cx) -> {
            Theme.change(switchMode.value, null, cx);
            cx.refreshWindows();
        });
    }

    /**
     * Apply the named theme without going through `SwitchTheme`.
     *
     * The palette calls this as the highlight moves, so the theme under the
     * cursor is previewed on the whole window; cancelling puts the previous
     * one back.
     */
    public static function applyTheme(name:String, cx:AppContext):Void {
        final themeConfig = ThemeRegistry.global(cx).themes().get(name);
        if (themeConfig == null) return;

        applyThemeConfig(themeConfig, cx);
        cx.refreshWindows();
    }

    /**
     * The palette entries for the `SelectTheme` Command palette: every
     * registered theme, grouped by mode, with the active one checked.
     */
    public static function themeEntries(cx:AppContext):Array<CommandEntry> {
        final activeName = Theme.global(cx).themeName();
        final themes = ThemeRegistry.global(cx).sortedThemes();

        return [for (pair in [{mode: ThemeMode.Light, heading: 'Light'}, {mode: ThemeMode.Dark, heading: 'Dark'}]) {
            final group = new CommandGroup().label(pair.heading);
            for (theme in themes) {
                if (theme.mode == pair.mode) group.item(themeItem(theme, activeName));
            }
            CommandEntry.Group(group);
        }];
    }

    public static function themeNameAt(index:IndexPath, cx:AppContext):Null<String> {
        final modes = [ThemeMode.Light, ThemeMode.Dark];
        if (index.section >= modes.length) return null;
        final mode = modes[index.section];
        final matching = [for (theme in ThemeRegistry.global(cx).sortedThemes()) if (theme.mode == mode) theme];
        return index.row < matching.length ? matching[index.row].name : null;
    }

    static function themeItem(theme:ThemeConfig, activeName:String):CommandItem {
        final name = theme.name;

        return new CommandItem()
            .label(name)
            .icon(IconName.Palette)
            .checked(name == activeName)
            .keywords([theme.mode.name()])
            .action(new SwitchTheme(name));
    }

}
