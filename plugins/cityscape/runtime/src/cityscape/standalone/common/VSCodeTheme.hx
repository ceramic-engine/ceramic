// New code for Cityscape (not a port): reads a VS Code color theme (or the
// tmTheme JSON shape used by loreline-monaco) into Monaco's standalone theme data.
package cityscape.standalone.common;

import cityscape.base.common.JsValues;
import cityscape.standalone.common.StandaloneTheme.IColors;
import cityscape.standalone.common.StandaloneTheme.IStandaloneThemeData;
import textmate.RawGrammar.RawValue;

/**
 * Converts VS Code color themes to `IStandaloneThemeData`.
 *
 * Accepted shapes:
 * - a VS Code color theme: `{name?, type?, colors?, tokenColors?}`, `type`
 *   being `'dark'`, `'light'`, `'hc'` / `'hcDark'` or `'hcLight'` (or the
 *   `uiTheme` values `'vs-dark'`, `'vs'`, `'hc-black'`, `'hc-light'`);
 * - a tmTheme converted to JSON: `{name?, colors?, settings: [...]}`.
 *
 * The global settings entry (the one without `scope`) gives editor colors
 * with the mapping of VS Code's themeCompatibility.ts (`background` is
 * `editor.background`, `caret` is `editorCursor.foreground`...), then
 * `colors` is copied over them. The TextMate rules are carried in
 * `tokenColors` for the TextMate tokenizer; `rules` (Monaco's token theme)
 * stays empty and the built-in base theme is inherited. `semanticTokenColors`
 * and `semanticHighlighting` are carried for the semantic tokens.
 */
class VSCodeTheme {

    /**
     * Settings of the global tmTheme entry and the color ids they give, from
     * VS Code's themeCompatibility.ts.
     */
    static final settingToColorIdMapping:Array<Array<String>> = [
        ['background', 'editor.background'],
        ['foreground', 'editor.foreground'],
        ['selection', 'editor.selectionBackground'],
        ['inactiveSelection', 'editor.inactiveSelectionBackground'],
        ['selectionHighlightColor', 'editor.selectionHighlightBackground'],
        ['findMatchHighlight', 'editor.findMatchHighlightBackground'],
        ['currentFindMatchHighlight', 'editor.findMatchBackground'],
        ['hoverHighlight', 'editor.hoverHighlightBackground'],
        ['wordHighlight', 'editor.wordHighlightBackground'],
        ['wordHighlightStrong', 'editor.wordHighlightStrongBackground'],
        ['findRangeHighlight', 'editor.findRangeHighlightBackground'],
        ['lineHighlight', 'editor.lineHighlightBackground'],
        ['rangeHighlight', 'editor.rangeHighlightBackground'],
        ['caret', 'editorCursor.foreground'],
        ['invisibles', 'editorWhitespace.foreground'],
        ['guide', 'editorIndentGuide.background'],
        ['activeGuide', 'editorIndentGuide.activeBackground']
    ];

    /**
     * The built-in base theme of a VS Code theme `type`: `'vs'` for light,
     * `'hc-black'` and `'hc-light'` for high contrast, `'vs-dark'` for dark
     * and anything else.
     */
    public static function baseOfType(type:Any):String {
        if (!JsValues.isString(type)) {
            return 'vs-dark';
        }
        return switch ((type : String)) {
            case 'light' | 'vs': 'vs';
            case 'hc' | 'hcDark' | 'hc-black': 'hc-black';
            case 'hcLight' | 'hc-light': 'hc-light';
            case _: 'vs-dark';
        }
    }

    /**
     * `theme` is an object parsed from JSON: anonymous structures
     * (`haxe.Json.parse`) or the order preserving objects of
     * `textmate.Json.parseJSON` (`textmate.OrderedMap`).
     */
    public static function toStandaloneThemeData(theme:Dynamic):IStandaloneThemeData {
        final colors = new haxe.DynamicAccess<String>();

        var tokenColors:Null<Array<Dynamic>> = null;
        final themeTokenColors:Any = RawValue.field(theme, 'tokenColors');
        final themeSettings:Any = RawValue.field(theme, 'settings');
        if (JsValues.isArray(themeTokenColors)) {
            tokenColors = themeTokenColors;
        }
        else if (JsValues.isArray(themeSettings)) {
            tokenColors = themeSettings;
        }

        // The global settings entries (without scope)
        if (tokenColors != null) {
            for (rule in tokenColors) {
                if (!RawValue.isObject(rule) || JsValues.truthy(RawValue.field(rule, 'scope'))) {
                    continue;
                }
                final settings:Any = RawValue.field(rule, 'settings');
                if (!RawValue.isObject(settings)) {
                    continue;
                }
                for (mapping in settingToColorIdMapping) {
                    final value:Any = RawValue.field(settings, mapping[0]);
                    if (JsValues.isString(value)) {
                        colors.set(mapping[1], value);
                    }
                }
            }
        }

        // Then the theme colors
        final themeColors:Any = RawValue.field(theme, 'colors');
        if (RawValue.isObject(themeColors)) {
            for (key in RawValue.fields(themeColors)) {
                final value:Any = RawValue.field(themeColors, key);
                if (JsValues.isString(value)) {
                    colors.set(key, value);
                }
            }
        }

        final result:IStandaloneThemeData = {
            base: baseOfType(RawValue.field(theme, 'type')),
            inherit: true,
            rules: [],
            colors: (colors : IColors)
        };
        if (tokenColors != null) {
            result.tokenColors = tokenColors;
        }
        // Semantic tokens (step 7, cs7-rest-sem): `semanticTokenColors` and
        // `semanticHighlighting` of a VS Code theme
        final semanticTokenColors:Any = RawValue.field(theme, 'semanticTokenColors');
        if (RawValue.isObject(semanticTokenColors)) {
            result.semanticTokenColors = semanticTokenColors;
        }
        final semanticHighlighting:Dynamic = RawValue.field(theme, 'semanticHighlighting');
        if (Std.isOfType(semanticHighlighting, Bool) && (semanticHighlighting : Bool)) {
            result.semanticHighlighting = true;
        }
        return result;
    }

}
