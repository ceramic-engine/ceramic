// Ported from vscode src/vs/editor/standalone/common/standaloneTheme.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.standalone.common;

import cityscape.base.common.Color;
import cityscape.base.common.Event;
import cityscape.common.languages.supports.Tokenization.TokenTheme;
import cityscape.platform.theme.common.ThemeService.IColorTheme;

/**
 * One of `'vs'`, `'vs-dark'`, `'hc-black'`, `'hc-light'`.
 */
typedef BuiltinTheme = String;

/**
 * Color id to `#rrggbb` / `#rrggbbaa` color.
 */
typedef IColors = haxe.DynamicAccess<String>;

/**
 * A token theme rule (`{token, foreground?, background?, fontStyle?}`),
 * defined in tokenization.ts.
 */
typedef ITokenThemeRule = cityscape.common.languages.supports.Tokenization.ITokenThemeRule;

typedef IStandaloneThemeData = {
    var base:BuiltinTheme;
    var inherit:Bool;
    var rules:Array<ITokenThemeRule>;
    @:optional var encodedTokensColors:Array<String>;
    var colors:IColors;

    /**
     * Cityscape addition (not in Monaco): the TextMate theme rules, as VS Code
     * `tokenColors` or tmTheme `settings` entries
     * (`{name?, scope?, settings: {foreground?, background?, fontStyle?}}`),
     * used by the TextMate tokenizer. Monaco's own token theme (`rules`) does
     * not read them.
     */
    @:optional var tokenColors:Array<Dynamic>;

    // Semantic tokens (step 7, cs7-rest-sem)

    /**
     * Cityscape addition (not in Monaco): the semantic token rules of a VS
     * Code theme (its `semanticTokenColors`: selectors such as `variable`,
     * `*.readonly`, `type.defaultLibrary:haxe` to a color string or
     * `{foreground?, fontStyle?, bold?, italic?, underline?,
     * strikethrough?}`).
     */
    @:optional var semanticTokenColors:Dynamic;

    /**
     * Cityscape addition (not in Monaco, whose standalone themes never
     * enable it): whether semantic highlighting is on with this theme when
     * `editor.semanticHighlighting.enabled` is `'configuredByTheme'` (the
     * `semanticHighlighting` of a VS Code theme).
     */
    @:optional var semanticHighlighting:Bool;
}

interface IStandaloneTheme extends IColorTheme {

    var tokenTheme(get, never):TokenTheme;

    /**
     * Cityscape addition: the rules of this theme for the TextMate tokenizer,
     * as tmTheme `settings` entries (see `StandaloneTheme.getTextMateSettings`).
     */
    function getTextMateSettings():Array<Dynamic>;

    var themeName(default, null):String;

}

interface IStandaloneThemeService {

    function setTheme(themeName:String):Void;

    function defineTheme(themeName:String, themeData:IStandaloneThemeData):Void;

    function getColorTheme():IStandaloneTheme;

    var onDidColorThemeChange(default, null):Event<IStandaloneTheme>;

    function setColorMapOverride(colorMapOverride:Null<Array<Color>>):Void;

    // TODO: setAutoDetectHighContrast (OS high contrast detection) is not ported.

}
