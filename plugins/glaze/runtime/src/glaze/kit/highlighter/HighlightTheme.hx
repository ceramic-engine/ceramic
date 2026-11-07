// Ported from gpui-kit 0.8.1: crates/component/src/highlighter/wasm_stub.rs (HighlightThemeStyle,
// HighlightTheme), crates/component/src/theme/registry.rs (DEFAULT_THEME_COLORS, highlight part)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.highlighter;

import glaze.HighlightStyle;
import glaze.Hsla;
import glaze.kit.base.input.HighlightStyleResolver;
import glaze.kit.theme.DefaultThemeColors;
import glaze.kit.theme.ThemeMode;
import glaze.kit.highlighter.SyntaxColors.ThemeStyle;

/**
 * The `highlight` section of a theme: editor colors, status colors and the
 * syntax styles.
 *
 * Like `SyntaxColors`, this is the type of gpui-kit's builds without
 * tree-sitter. Its editor fields have no serde rename except the gutter
 * background, so they are read from the keys `editor_background`,
 * `editor_foreground`, `editor_active_line`, `editor_line_number`,
 * `editor_active_line_number`, `editor_invisible` and
 * `editor.gutter.background`; the dotted keys of the bundled themes
 * (`editor.background`...) are ignored, like in gpui-kit.
 */
class HighlightThemeStyle {

    public var editorBackground:Null<Hsla> = null;

    public var editorForeground:Null<Hsla> = null;

    public var editorActiveLine:Null<Hsla> = null;

    public var editorLineNumber:Null<Hsla> = null;

    public var editorActiveLineNumber:Null<Hsla> = null;

    public var editorInvisible:Null<Hsla> = null;

    /**
     * Optional background color for the gutter (line-number column).
     * Falls back to `editorBackground` when unset.
     */
    public var editorGutterBackground:Null<Hsla> = null;

    public var status:StatusColors = new StatusColors();

    public var syntax:SyntaxColors = new SyntaxColors();

    public function new() {}

    public static function defaultValue():HighlightThemeStyle {
        return new HighlightThemeStyle();
    }

    public function clone():HighlightThemeStyle {
        final style = new HighlightThemeStyle();
        style.editorBackground = editorBackground;
        style.editorForeground = editorForeground;
        style.editorActiveLine = editorActiveLine;
        style.editorLineNumber = editorLineNumber;
        style.editorActiveLineNumber = editorActiveLineNumber;
        style.editorInvisible = editorInvisible;
        style.editorGutterBackground = editorGutterBackground;
        style.status = status;
        style.syntax = syntax.clone();
        return style;
    }

    public function equals(other:Null<HighlightThemeStyle>):Bool {
        if (other == null)
            return false;
        inline function eq(a:Null<Hsla>, b:Null<Hsla>):Bool
            return a == null ? b == null : a.equals(b);
        return eq(editorBackground, other.editorBackground) && eq(editorForeground, other.editorForeground)
            && eq(editorActiveLine, other.editorActiveLine) && eq(editorLineNumber, other.editorLineNumber)
            && eq(editorActiveLineNumber, other.editorActiveLineNumber) && eq(editorInvisible, other.editorInvisible)
            && eq(editorGutterBackground, other.editorGutterBackground) && status.equals(other.status) && syntax.equals(other.syntax);
    }

    /** Reads the `highlight` object of a theme config (values serde would reject are read as missing). */
    public static function fromJson(json:Dynamic):HighlightThemeStyle {
        final style = new HighlightThemeStyle();
        if (json == null || Type.typeof(json) != TObject)
            return style;
        function color(key:String):Null<Hsla> {
            final value:Dynamic = Reflect.field(json, key);
            return Std.isOfType(value, String) ? ThemeStyle.parseColor(value) : null;
        }
        style.editorBackground = color("editor_background");
        style.editorForeground = color("editor_foreground");
        style.editorActiveLine = color("editor_active_line");
        style.editorLineNumber = color("editor_line_number");
        style.editorActiveLineNumber = color("editor_active_line_number");
        style.editorInvisible = color("editor_invisible");
        style.editorGutterBackground = color("editor.gutter.background");
        style.syntax = SyntaxColors.fromJson(Reflect.field(json, "syntax"));
        return style;
    }

}

/**
 * Theme for syntax highlighting, from the `highlight` section of a theme
 * file. This JSON is compatible with the Zed theme format.
 *
 * It resolves highlight names (`keyword`, `string.escape`) into styles for
 * the code editor and the code blocks of text views.
 *
 * Rust's `HighlightTheme` has both a `style` field and, through `Deref` to
 * `SyntaxColors`, a `style(name)` method; Haxe cannot have both names, so
 * the method is `highlightStyle(name)` here, and the `HighlightStyleResolver`
 * implementation (Rust `impl HighlightStyleResolver for HighlightTheme`) is
 * the object returned by `resolver()`.
 */
class HighlightTheme {

    static var defaults:Null<Map<Int, HighlightTheme>> = null;

    public var name:String;

    public var appearance:ThemeMode;

    public var style:HighlightThemeStyle;

    var _resolver:Null<HighlightThemeResolver> = null;

    public function new(name:String, appearance:ThemeMode, style:HighlightThemeStyle) {
        this.name = name;
        this.appearance = appearance;
        this.style = style;
    }

    /** The highlight theme of the default dark theme (one shared instance, like the Rust `Arc`). */
    public static function defaultDark():HighlightTheme {
        return defaultFor(Dark);
    }

    /** The highlight theme of the default light theme (one shared instance, like the Rust `Arc`). */
    public static function defaultLight():HighlightTheme {
        return defaultFor(Light);
    }

    static function defaultFor(mode:ThemeMode):HighlightTheme {
        if (defaults == null) {
            defaults = new Map();
            // Rust `DEFAULT_THEME_COLORS`: `style: theme.highlight.unwrap_or_default()`.
            for (theme in DefaultThemeColors.themes()) {
                defaults.set(cast theme.mode, new HighlightTheme(theme.name, theme.mode, HighlightThemeStyle.fromJson(theme.highlight)));
            }
        }
        return defaults.get(cast mode);
    }

    /** Rust `theme.style(name)` (through `Deref`): the style of a highlight name, with the prefix fallback. */
    public function highlightStyle(name:String):Null<HighlightStyle> {
        return style.syntax.style(name);
    }

    public function styleForIndex(index:Int):Null<HighlightStyle> {
        return style.syntax.styleForIndex(index);
    }

    /** This theme as a `HighlightStyleResolver` (always the same object for a theme). */
    public function resolver():HighlightStyleResolver {
        if (_resolver == null)
            _resolver = new HighlightThemeResolver(this);
        return _resolver;
    }

    public function equals(other:Null<HighlightTheme>):Bool {
        return other != null && (other == this || (name == other.name && appearance == other.appearance && style.equals(other.style)));
    }

}

/**
 * Rust `impl HighlightStyleResolver for HighlightTheme`: `self.style.syntax.style(name)`.
 */
class HighlightThemeResolver implements HighlightStyleResolver {

    public final theme:HighlightTheme;

    public function new(theme:HighlightTheme) {
        this.theme = theme;
    }

    public function style(name:String):Null<HighlightStyle> {
        return theme.style.syntax.style(name);
    }

}
