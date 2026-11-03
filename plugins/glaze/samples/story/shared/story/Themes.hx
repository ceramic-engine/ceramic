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
 * `./themes` folder on native targets. The port always uses the embedded
 * themes (like gpui-kit's web build) and persists the settings through
 * `stateStorage` when the app sets one (samples/story: Ceramic's app storage
 * on native targets); without it nothing is read or written, like the web
 * build (tests and golden scenes).
 */
class Themes {

    /**
     * Where the settings are read and written (Rust `STATE_FILE`), set by
     * the app before `Lib.init`. Null: nothing is persisted.
     */
    public static var stateStorage:Null<{read:Void->Null<String>, write:String->Void}> = null;

    /**
     * Rust `serde_json::from_str::<State>(&json).unwrap_or_default()`: the
     * default state when the text is missing or does not parse (`theme` is
     * required, `scrollbar_show` is an alias of `scrollbar_mode`).
     */
    public static function parseState(json:Null<String>):StoryThemeState {
        if (json == null || json.length == 0) return new StoryThemeState();
        try {
            final data:haxe.DynamicAccess<Dynamic> = haxe.Json.parse(json);
            final state = new StoryThemeState();
            final theme = data.get('theme');
            if (!Std.isOfType(theme, String)) return new StoryThemeState();
            state.theme = theme;
            final radius = data.get('radius');
            if (radius != null) {
                if (!Std.isOfType(radius, Float)) return new StoryThemeState();
                state.radius = radius;
            }
            var mode:Dynamic = data.get('scrollbar_mode');
            if (mode == null) mode = data.get('scrollbar_show');
            if (mode != null) {
                state.scrollbarMode = switch mode {
                    case 'Scrolling': Scrolling;
                    case 'Hover': Hover;
                    case 'Always': Always;
                    case _: return new StoryThemeState();
                }
            }
            final fps = data.get('show_fps_monitor');
            if (fps != null) {
                if (!Std.isOfType(fps, Bool)) return new StoryThemeState();
                state.showFpsMonitor = fps;
            }
            return state;
        } catch (_:Dynamic) {
            return new StoryThemeState();
        }
    }

    /**
     * Rust `serde_json::to_string_pretty(&state)`.
     */
    public static function stateJson(state:StoryThemeState):String {
        inline function optional(value:Null<String>):String return value == null ? 'null' : value;
        final radius = state.radius == null ? null : (Math.isFinite(state.radius) && state.radius == Math.ffloor(state.radius) ? '${Std.int(state.radius)}.0' : Std.string(state.radius));
        final mode = state.scrollbarMode == null ? null : haxe.Json.stringify(state.scrollbarMode.toString());
        final fps = state.showFpsMonitor == null ? null : (state.showFpsMonitor ? 'true' : 'false');
        return '{\n'
            + '  "theme": ${haxe.Json.stringify(state.theme)},\n'
            + '  "radius": ${optional(radius)},\n'
            + '  "scrollbar_mode": ${optional(mode)},\n'
            + '  "show_fps_monitor": ${optional(fps)}\n'
            + '}';
    }

    /**
     * Rust `save_state`: writes the settings unless a theme is being
     * previewed (write errors are ignored).
     */
    static function saveState(cx:AppContext):Void {
        final storage = stateStorage;
        if (storage == null) return;
        if (AppState.global(cx).previewingTheme) return;

        final theme = Theme.global(cx);
        final state = new StoryThemeState();
        state.theme = theme.themeName();
        state.radius = theme.radius;
        state.scrollbarMode = theme.scrollbarMode;
        state.showFpsMonitor = AppState.global(cx).showFpsMonitor;
        try {
            storage.write(stateJson(state));
        } catch (_:Dynamic) {}
    }

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

        final storage = stateStorage;
        final state = storage != null ? parseState(try storage.read() catch (_:Dynamic) null) : new StoryThemeState();

        // Rust applies the persisted theme once its `./themes` folder is
        // loaded (`watch_dir`); the port's themes are embedded, so it is
        // applied right away
        if (storage != null) {
            final themeConfig = ThemeRegistry.global(cx).themes().get(state.theme);
            if (themeConfig != null) {
                applyThemeConfig(themeConfig, cx);
                applyPersistedRadius(state, cx);
            }
        }

        if (state.scrollbarMode != null) {
            Theme.setScrollbarMode(state.scrollbarMode, cx);
        }
        applyPersistedRadius(state, cx);
        if (state.showFpsMonitor != null) {
            AppState.globalMut(cx).showFpsMonitor = state.showFpsMonitor;
        }
        cx.refreshWindows();

        // Both globals carry persisted settings, so either changing writes the file.
        if (storage != null) {
            cx.observeGlobal(Theme, saveState).detach();
            cx.observeGlobal(AppState, saveState).detach();
        }

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
