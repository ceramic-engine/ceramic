// Ported from gpui-kit 0.8.1: crates/component/src/highlighter/wasm_stub.rs (FontStyle,
// FontWeightContent, ThemeStyle, SyntaxColors)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.highlighter;

import gpui.FontStyle;
import gpui.FontWeight;
import gpui.HighlightStyle;
import gpui.Hsla;

/**
 * The font style of a syntax style (Rust `highlighter::FontStyle`, renamed:
 * clashes with `gpui.FontStyle`). Serialized lowercase.
 */
enum abstract HighlightFontStyle(Int) {

    var Normal = 0;

    var Italic = 1;

    var Underline = 2;

    /** Rust `From<FontStyle> for gpui::FontStyle`: underline has no font style. */
    public function toFontStyle():FontStyle {
        return switch (cast this : HighlightFontStyle) {
            case Normal: FontStyle.Normal;
            case Italic: FontStyle.Italic;
            case Underline: FontStyle.Normal;
        }
    }

    public static function fromJson(value:Dynamic):Null<HighlightFontStyle> {
        return switch value {
            case "normal": Normal;
            case "italic": Italic;
            case "underline": Underline;
            case _: null;
        }
    }

}

/**
 * A font weight of a syntax style, serialized as its number
 * (Rust `FontWeightContent`, `#[repr(u16)]`).
 */
enum abstract FontWeightContent(Int) to Int {

    var Thin = 100;

    var ExtraLight = 200;

    var Light = 300;

    var Normal = 400;

    var Medium = 500;

    var Semibold = 600;

    var Bold = 700;

    var ExtraBold = 800;

    var Black = 900;

    public function toFontWeight():FontWeight {
        return switch (cast this : FontWeightContent) {
            case Thin: FontWeight.THIN;
            case ExtraLight: FontWeight.EXTRA_LIGHT;
            case Light: FontWeight.LIGHT;
            case Normal: FontWeight.NORMAL;
            case Medium: FontWeight.MEDIUM;
            case Semibold: FontWeight.SEMIBOLD;
            case Bold: FontWeight.BOLD;
            case ExtraBold: FontWeight.EXTRA_BOLD;
            case Black: FontWeight.BLACK;
        }
    }

    /** Only the nine values of the enum are accepted, like `serde_repr`. */
    public static function fromJson(value:Dynamic):Null<FontWeightContent> {
        if (!Std.isOfType(value, Int) && !Std.isOfType(value, Float))
            return null;
        final number:Float = value;
        return switch number {
            case 100: Thin;
            case 200: ExtraLight;
            case 300: Light;
            case 400: Normal;
            case 500: Medium;
            case 600: Semibold;
            case 700: Bold;
            case 800: ExtraBold;
            case 900: Black;
            case _: null;
        }
    }

}

/**
 * The style of a highlight name: color, font style and font weight.
 */
class ThemeStyle {

    public var color:Null<Hsla>;

    public var fontStyle:Null<HighlightFontStyle>;

    public var fontWeight:Null<FontWeightContent>;

    public function new(?color:Hsla, ?fontStyle:HighlightFontStyle, ?fontWeight:FontWeightContent) {
        this.color = color;
        this.fontStyle = fontStyle;
        this.fontWeight = fontWeight;
    }

    /** Rust `From<ThemeStyle> for HighlightStyle`. */
    public function toHighlightStyle():HighlightStyle {
        return new HighlightStyle(color, fontWeight != null ? fontWeight.toFontWeight() : null, fontStyle != null ? fontStyle.toFontStyle() : null);
    }

    public function equals(other:Null<ThemeStyle>):Bool {
        if (other == null)
            return false;
        return (color == null ? other.color == null : color.equals(other.color)) && fontStyle == other.fontStyle && fontWeight == other.fontWeight;
    }

    /**
     * Reads `{"color": "#rrggbb", "font_style": "italic", "font_weight": 700}`.
     * Colors are hex strings like GPUI's `Hsla` deserialization. Values serde
     * would reject are read as missing.
     */
    public static function fromJson(json:Dynamic):Null<ThemeStyle> {
        if (json == null || Std.isOfType(json, String) || Std.isOfType(json, Array) || Reflect.isFunction(json) || Type.typeof(json) != TObject)
            return null;
        final colorValue:Dynamic = Reflect.field(json, "color");
        final color = Std.isOfType(colorValue, String) ? parseColor(colorValue) : null;
        return new ThemeStyle(color, HighlightFontStyle.fromJson(Reflect.field(json, "font_style")), FontWeightContent.fromJson(Reflect.field(json, "font_weight")));
    }

    @:allow(gpui.component.highlighter)
    static function parseColor(value:String):Null<Hsla> {
        final rgba = gpui.Rgba.tryParse(value);
        return rgba != null ? Hsla.fromRgba(rgba) : null;
    }

}

/**
 * The syntax styles of a highlight theme, by highlight name.
 *
 * This is the type of gpui-kit's builds without tree-sitter (its
 * `wasm_stub.rs`, used with the `syntect` highlighter and with no
 * highlighter), the configuration the port follows. Its serde names are those
 * of the Rust fields unless renamed: `comment_doc` is read from the key
 * `comment_doc`, so a theme's `comment.doc` entry is ignored and the name
 * falls back to `comment`, like in gpui-kit.
 */
class SyntaxColors {

    /**
     * Rust `HIGHLIGHT_NAMES`: the highlight names, in the order of
     * `styleForIndex`.
     */
    public static final HIGHLIGHT_NAMES:Array<String> = [
        "attribute",
        "boolean",
        "comment",
        "comment.doc",
        "constant",
        "constructor",
        "embedded",
        "emphasis",
        "emphasis.strong",
        "enum",
        "function",
        "hint",
        "keyword",
        "label",
        "link_text",
        "link_uri",
        "number",
        "operator",
        "predictive",
        "preproc",
        "primary",
        "property",
        "punctuation",
        "punctuation.bracket",
        "punctuation.delimiter",
        "punctuation.list_marker",
        "punctuation.special",
        "string",
        "string.escape",
        "string.regex",
        "string.special",
        "string.special.symbol",
        "tag",
        "tag.doctype",
        "text.code.span",
        "text.literal",
        "title",
        "type",
        "variable",
        "variable.special",
        "variant",
    ];

    /**
     * The JSON key of each highlight name (the serde name of its field), in
     * the order of `HIGHLIGHT_NAMES`.
     */
    static final JSON_KEYS:Array<String> = [
        "attribute",
        "boolean",
        "comment",
        "comment_doc",
        "constant",
        "constructor",
        "embedded",
        "emphasis",
        "emphasis.strong",
        "enum",
        "function",
        "hint",
        "keyword",
        "label",
        "link_text",
        "link_uri",
        "number",
        "operator",
        "predictive",
        "preproc",
        "primary",
        "property",
        "punctuation",
        "punctuation.bracket",
        "punctuation.delimiter",
        "punctuation.list_marker",
        "punctuation.special",
        "string",
        "string.escape",
        "string.regex",
        "string.special",
        "string.special.symbol",
        "tag",
        "tag.doctype",
        "text.code.span",
        "text.literal",
        "title",
        "type",
        "variable",
        "variable.special",
        "variant",
    ];

    static var indexByName:Null<Map<String, Int>> = null;

    /** The style of each highlight name, in the order of `HIGHLIGHT_NAMES`. */
    final styles:Array<Null<ThemeStyle>>;

    public function new() {
        styles = [for (_ in 0...HIGHLIGHT_NAMES.length) null];
    }

    /** The style set for exactly `name` (no fallback), or null. */
    public function get(name:String):Null<ThemeStyle> {
        final index = nameIndex(name);
        return index < 0 ? null : styles[index];
    }

    /** Sets the style of a highlight name; unknown names are ignored. */
    public function set(name:String, style:Null<ThemeStyle>):SyntaxColors {
        final index = nameIndex(name);
        if (index >= 0)
            styles[index] = style;
        return this;
    }

    public function style(name:String):Null<HighlightStyle> {
        if (name.length == 0) {
            return null;
        }

        final themeStyle = get(name);
        final style = themeStyle != null ? themeStyle.toHighlightStyle() : null;

        if (style != null) {
            return style;
        }
        else if (name.indexOf('.') >= 0) {
            // Rust `name.split('.').next()`: the part before the first dot.
            return this.style(name.substr(0, name.indexOf('.')));
        }
        else {
            return null;
        }
    }

    public function styleForIndex(index:Int):Null<HighlightStyle> {
        return index >= 0 && index < HIGHLIGHT_NAMES.length ? style(HIGHLIGHT_NAMES[index]) : null;
    }

    public function clone():SyntaxColors {
        final colors = new SyntaxColors();
        for (i in 0...styles.length)
            colors.styles[i] = styles[i];
        return colors;
    }

    public function equals(other:Null<SyntaxColors>):Bool {
        if (other == null)
            return false;
        for (i in 0...styles.length) {
            final a = styles[i];
            final b = other.styles[i];
            if (a == null ? b != null : !a.equals(b))
                return false;
        }
        return true;
    }

    public static function fromJson(json:Dynamic):SyntaxColors {
        final colors = new SyntaxColors();
        if (json == null || Type.typeof(json) != TObject)
            return colors;
        for (i in 0...JSON_KEYS.length) {
            colors.styles[i] = ThemeStyle.fromJson(Reflect.field(json, JSON_KEYS[i]));
        }
        return colors;
    }

    static function nameIndex(name:String):Int {
        if (indexByName == null) {
            indexByName = new Map();
            for (i in 0...HIGHLIGHT_NAMES.length)
                indexByName.set(HIGHLIGHT_NAMES[i], i);
        }
        final index = indexByName.get(name);
        return index == null ? -1 : index;
    }

}
