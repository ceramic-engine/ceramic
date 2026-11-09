// New code for Cityscape (not a port): the Glaze kit theme as a Cityscape
// (Monaco) theme, for editors that should look like the rest of a kit UI.
package cityscape.kit;

import cityscape.Cityscape;
import cityscape.standalone.common.StandaloneTheme.IStandaloneThemeData;
import glaze.Hsla;
import glaze.kit.highlighter.SyntaxColors;
import glaze.kit.highlighter.SyntaxColors.HighlightFontStyle;
import glaze.kit.highlighter.SyntaxColors.ThemeStyle;
import glaze.kit.theme.Theme;

/**
 * A Cityscape theme made of the colors of the Glaze kit theme (the active
 * `glaze.kit.theme.Theme`): the text area takes the kit's foreground, caret,
 * selection, border and editor colors, and the TextMate scopes are colored
 * with the syntax colors of the kit's `highlightTheme`, mapped like the kit's
 * own highlighter maps them (`TextMateBackend.semanticName`).
 *
 * ```haxe
 * // in a render: defines and sets `glaze-kit` when the kit theme changed
 * KitTheme.apply(context, Theme.global(cx));
 * ```
 *
 * The editor background is the kit's editor background
 * (`highlightTheme.style.editorBackground`, else the input background), or
 * transparent with `transparentBackground` (an editor drawn inside a kit frame
 * that paints the background with its rounded corners).
 */
class KitTheme {

    /** The name `apply` defines. */
    public static inline final THEME_NAME = 'glaze-kit';

    /**
     * TextMate scope selectors and the kit highlight name they take, in the
     * order of the kit's `semanticName` (the theme matcher picks the most
     * specific selector, like VS Code).
     */
    static final SCOPES:Array<Array<String>> = [
        ['comment', 'comment'],
        ['comment.block.documentation', 'comment.doc'],
        ['comment.line.documentation', 'comment.doc'],
        ['constant.character.escape', 'string.escape'],
        ['string', 'string'],
        ['string.regexp', 'string.regex'],
        ['constant.numeric', 'number'],
        ['constant.language.boolean', 'boolean'],
        ['constant', 'constant'],
        ['support.constant', 'constant'],
        ['entity.name.constant', 'constant'],
        ['keyword', 'keyword'],
        ['storage.modifier', 'keyword'],
        ['keyword.operator', 'operator'],
        ['keyword.control.import', 'preproc'],
        ['meta.preprocessor', 'preproc'],
        ['storage.type', 'type'],
        ['entity.name.function', 'function'],
        ['support.function', 'function'],
        ['variable.function', 'function'],
        ['entity.name.type', 'type'],
        ['entity.name.class', 'type'],
        ['entity.name.struct', 'type'],
        ['entity.name.enum', 'type'],
        ['entity.name.trait', 'type'],
        ['entity.name.interface', 'type'],
        ['entity.other.inherited-class', 'type'],
        ['support.type', 'type'],
        ['support.class', 'type'],
        ['entity.name.tag', 'tag'],
        ['entity.other.attribute-name', 'attribute'],
        ['entity.name.label', 'label'],
        ['entity.name.section', 'title'],
        ['markup.heading', 'title'],
        ['variable.language', 'variable.special'],
        ['variable.other.member', 'property'],
        ['variable.other.property', 'property'],
        ['support.variable.property', 'property'],
        ['variable', 'variable'],
        ['markup.bold', 'emphasis.strong'],
        ['markup.italic', 'emphasis'],
        ['markup.underline.link', 'link_uri'],
        ['markup.raw', 'text.literal'],
        ['markup.list', 'punctuation.list_marker'],
        ['punctuation', 'punctuation'],
        ['punctuation.section', 'punctuation.bracket'],
        ['punctuation.definition.block', 'punctuation.bracket'],
        ['punctuation.separator', 'punctuation.delimiter'],
        ['punctuation.terminator', 'punctuation.delimiter'],
    ];

    /** The key of the last theme `apply` set, by context. */
    static final applied:haxe.ds.ObjectMap<Cityscape, String> = new haxe.ds.ObjectMap();

    /** `#rrggbbaa` of a kit color. */
    public static function hex(color:Hsla):String {
        return color.toRgb().toHexString();
    }

    /** The kit's editor background (Rust `Theme::editor_background`). */
    public static function editorBackground(theme:Theme):Hsla {
        final color = theme.highlightTheme.style.editorBackground;
        return color != null ? color : theme.inputBackground();
    }

    /**
     * The theme data: base `vs` or `vs-dark` by the kit's mode, the kit's
     * colors, and TextMate rules from the kit's syntax colors.
     */
    public static function themeData(theme:Theme, transparentBackground:Bool = false):IStandaloneThemeData {
        final style = theme.highlightTheme.style;
        final transparent = '#00000000';
        final guide = hex(theme.border.opacity(0.85));
        final colors:haxe.DynamicAccess<String> = {};
        colors.set('editor.background', transparentBackground ? transparent : hex(editorBackground(theme)));
        colors.set('editor.foreground', hex(theme.foreground));
        colors.set('editorCursor.foreground', hex(theme.caret));
        colors.set('editor.selectionBackground', hex(theme.selection));
        colors.set('editor.inactiveSelectionBackground', hex(theme.selection));
        colors.set('editor.lineHighlightBackground', style.editorActiveLine != null ? hex(style.editorActiveLine) : transparent);
        colors.set('editor.lineHighlightBorder', transparent);
        colors.set('editorGutter.background', style.editorGutterBackground != null ? hex(style.editorGutterBackground) : transparent);
        colors.set('editorLineNumber.foreground', hex(theme.mutedForeground));
        colors.set('editorLineNumber.activeForeground', hex(theme.foreground));
        colors.set('editorIndentGuide.background1', guide);
        colors.set('editorIndentGuide.activeBackground1', guide);
        if (style.editorInvisible != null) {
            colors.set('editorWhitespace.foreground', hex(style.editorInvisible));
        }
        // The marker colors stay Monaco's: the kit's status colors are those
        // of gpui-kit without tree-sitter (transparent).

        final tokenColors:Array<Dynamic> = [{settings: {foreground: hex(theme.foreground), background: colors.get('editor.background')}}];
        for (entry in SCOPES) {
            final themeStyle = syntaxStyle(style.syntax, entry[1]);
            if (themeStyle == null) {
                continue;
            }
            final settings:haxe.DynamicAccess<String> = {};
            if (themeStyle.color != null) {
                settings.set('foreground', hex(themeStyle.color));
            }
            final fontStyle:Array<String> = [];
            if (themeStyle.fontStyle == HighlightFontStyle.Italic) fontStyle.push('italic');
            if (themeStyle.fontStyle == HighlightFontStyle.Underline) fontStyle.push('underline');
            if (themeStyle.fontWeight != null && (themeStyle.fontWeight : Int) >= 600) fontStyle.push('bold');
            if (fontStyle.length > 0) {
                settings.set('fontStyle', fontStyle.join(' '));
            }
            tokenColors.push({scope: entry[0], settings: settings});
        }

        return {
            base: theme.isDark() ? 'vs-dark' : 'vs',
            inherit: true,
            rules: [],
            colors: cast colors,
            tokenColors: tokenColors
        };
    }

    /** The kit's style of a highlight name, or of its first part (`string.escape` falls back to `string`). */
    static function syntaxStyle(syntax:SyntaxColors, name:String):Null<ThemeStyle> {
        final style = syntax.get(name);
        if (style != null) {
            return style;
        }
        final dot = name.indexOf('.');
        return dot > 0 ? syntax.get(name.substr(0, dot)) : null;
    }

    /**
     * Defines the kit theme in `context` as `glaze-kit` and makes it the
     * current theme, when it changed since the last call (cheap enough to
     * call from a render: the theme data is compared as JSON).
     */
    public static function apply(context:Cityscape, theme:Theme, transparentBackground:Bool = false):Void {
        final data = themeData(theme, transparentBackground);
        final key = haxe.Json.stringify(data);
        if (applied.get(context) == key) {
            return;
        }
        applied.set(context, key);
        context.themeService.defineTheme(THEME_NAME, data);
        context.themeService.setTheme(THEME_NAME);
    }

}
