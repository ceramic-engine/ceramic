// Ported from gpui-kit 0.8.1: crates/component/src/theme/schema.rs (ThemeSet)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.theme;

/**
 * A theme file: a named set of themes.
 */
class ThemeSet {

    /**
     * The name of the theme set.
     */
    public var name:String = '';

    /**
     * The author of the theme.
     */
    public var author:Null<String> = null;

    /**
     * The URL of the theme.
     */
    public var url:Null<String> = null;

    /**
     * The theme list of the theme set.
     */
    public var themes:Array<ThemeConfig> = [];

    public function new() {}

    /**
     * Reads a theme set from a parsed JSON object. Throws when invalid.
     */
    public static function fromJson(json:Dynamic):ThemeSet {

        if (!JsonValue.isObject(json)) {
            throw 'invalid type for theme set, expected a map';
        }
        final set = new ThemeSet();
        final name = JsonValue.optString(json, 'name');
        if (name != null) set.name = name;
        set.author = JsonValue.optString(json, 'author');
        set.url = JsonValue.optString(json, 'url');
        final themes = JsonValue.optArray(json, 'themes');
        if (themes != null) {
            set.themes = [for (theme in themes) ThemeConfig.fromJson(theme)];
        }
        return set;

    }

    /**
     * Parses a theme file (Rust: `serde_json::from_str::<ThemeSet>`). Throws when invalid.
     */
    public static function parse(content:String):ThemeSet {

        return fromJson(haxe.Json.parse(content));

    }

}
