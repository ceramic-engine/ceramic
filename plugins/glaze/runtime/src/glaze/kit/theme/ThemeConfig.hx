// Ported from gpui-kit 0.8.1: crates/component/src/theme/schema.rs (ThemeConfig)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.theme;

/**
 * Represents a theme configuration (one theme of a theme file).
 *
 * Shared by reference like Rust's `Rc<ThemeConfig>`: `Theme.lightTheme` and
 * `Theme.darkTheme` are compared by identity. Do not mutate a config once it
 * is registered.
 */
class ThemeConfig {

    /**
     * Whether this theme is the default theme.
     */
    public var isDefault:Bool = false;

    /**
     * The name of the theme.
     */
    public var name:String = '';

    /**
     * The mode of the theme, default is light.
     */
    public var mode:ThemeMode = Light;

    /**
     * The base font size (`font.size`), default is 16.
     */
    public var fontSize:Null<Float> = null;

    /**
     * The base font family (`font.family`), default is system font: `.SystemUIFont`.
     */
    public var fontFamily:Null<String> = null;

    /**
     * The monospace font family (`mono_font.family`), default is platform
     * specific: `Menlo` on macOS, `Consolas` on Windows, `DejaVu Sans Mono` on Linux.
     */
    public var monoFontFamily:Null<String> = null;

    /**
     * The monospace font size (`mono_font.size`), default is 13.
     */
    public var monoFontSize:Null<Float> = null;

    /**
     * The border radius for general elements, default is 6.
     */
    public var radius:Null<Int> = null;

    /**
     * The border radius for large elements like Dialogs and Notifications (`radius.lg`), default is 8.
     */
    public var radiusLg:Null<Int> = null;

    /**
     * Set shadows in the theme, for example the Input and Button, default is true.
     */
    public var shadow:Null<Bool> = null;

    /**
     * The colors of the theme.
     */
    public var colors:ThemeConfigColors = new ThemeConfigColors();

    /**
     * The highlight theme (compatible with the `style` section of a Zed
     * theme), kept as the parsed JSON object until the highlighter is ported.
     */
    public var highlight:Null<Dynamic> = null;

    public function new() {}

    /**
     * Reads a theme config from a parsed JSON object (serde semantics: missing
     * fields take their default, unknown fields are ignored, a value of the
     * wrong type throws).
     */
    public static function fromJson(json:Dynamic):ThemeConfig {

        if (!JsonValue.isObject(json)) {
            throw 'invalid type for theme config, expected a map';
        }
        final config = new ThemeConfig();
        final isDefault = JsonValue.optBool(json, 'is_default');
        if (isDefault != null) config.isDefault = isDefault;
        final name = JsonValue.optString(json, 'name');
        if (name != null) config.name = name;
        final mode = JsonValue.optString(json, 'mode');
        if (mode != null) config.mode = ThemeMode.fromName(mode);
        config.fontSize = JsonValue.optFloat(json, 'font.size');
        config.fontFamily = JsonValue.optString(json, 'font.family');
        config.monoFontFamily = JsonValue.optString(json, 'mono_font.family');
        config.monoFontSize = JsonValue.optFloat(json, 'mono_font.size');
        config.radius = JsonValue.optUInt(json, 'radius');
        config.radiusLg = JsonValue.optUInt(json, 'radius.lg');
        config.shadow = JsonValue.optBool(json, 'shadow');
        config.colors = ThemeConfigColors.fromJson(Reflect.field(json, 'colors'));
        config.highlight = JsonValue.optObject(json, 'highlight');
        return config;

    }

    /**
     * Parses a theme config from a JSON string. Throws when invalid.
     */
    public static function parse(content:String):ThemeConfig {

        return fromJson(haxe.Json.parse(content));

    }

    /**
     * A copy of this config (a new identity, same values).
     */
    public function copy():ThemeConfig {

        final config = new ThemeConfig();
        config.isDefault = isDefault;
        config.name = name;
        config.mode = mode;
        config.fontSize = fontSize;
        config.fontFamily = fontFamily;
        config.monoFontFamily = monoFontFamily;
        config.monoFontSize = monoFontSize;
        config.radius = radius;
        config.radiusLg = radiusLg;
        config.shadow = shadow;
        config.colors = colors;
        config.highlight = highlight;
        return config;

    }

}
