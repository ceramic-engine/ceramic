// Ported from vscode src/vs/editor/standalone/browser/standaloneThemeService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.standalone;

import cityscape.base.common.Color;
import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.RegExp;
import cityscape.common.EncodedTokenAttributes.FontStyle;
import cityscape.common.EncodedTokenAttributes.TokenMetadata;
import cityscape.common.Languages.ITokenizationRegistry;
import cityscape.common.Languages.ITokenizationSupport;
import cityscape.common.languages.supports.Tokenization.ITokenThemeRule;
import cityscape.common.languages.supports.Tokenization.TokenTheme;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ColorUtils.ColorIdentifier;
import cityscape.platform.theme.common.Theme.ColorScheme;
import cityscape.platform.theme.common.ThemeService.ITokenStyle;
import cityscape.standalone.common.StandaloneTheme.BuiltinTheme;
import cityscape.standalone.common.StandaloneTheme.IStandaloneTheme;
import cityscape.standalone.common.StandaloneTheme.IStandaloneThemeData;
import cityscape.standalone.common.StandaloneTheme.IStandaloneThemeService;
import cityscape.standalone.common.Themes;

/**
 * A theme known by a `StandaloneThemeService`: the theme data, its colors
 * (with the registry defaults) and its token theme.
 */
class StandaloneTheme implements IStandaloneTheme {

    public final id:String;
    public var themeName(default, null):String;

    final themeData:IStandaloneThemeData;
    var colors:Null<Map<String, Color>>;
    final defaultColors:Map<String, Null<Color>>;
    var _tokenTheme:Null<TokenTheme>;

    public function new(name:String, standaloneThemeData:IStandaloneThemeData) {
        this.themeData = standaloneThemeData;
        final base = standaloneThemeData.base;
        if (name.length > 0) {
            if (StandaloneThemeService.isBuiltinTheme(name)) {
                this.id = name;
            }
            else {
                this.id = base + ' ' + name;
            }
            this.themeName = name;
        }
        else {
            this.id = base;
            this.themeName = base;
        }
        this.colors = null;
        this.defaultColors = new Map();
        this._tokenTheme = null;
    }

    public var label(get, never):String;

    function get_label():String {
        return this.themeName;
    }

    public var base(get, never):String;

    function get_base():String {
        return this.themeData.base;
    }

    public function notifyBaseUpdated():Void {
        if (this.themeData.inherit) {
            this.colors = null;
            this._tokenTheme = null;
        }
    }

    function getColors():Map<String, Color> {
        if (this.colors == null) {
            final colors = new Map<String, Color>();
            final themeColors = this.themeData.colors;
            if (themeColors != null) {
                for (id in themeColors.keys()) {
                    colors.set(id, Color.fromHex(themeColors.get(id)));
                }
            }
            if (this.themeData.inherit) {
                final baseData = StandaloneThemeService.getBuiltinRules(this.themeData.base);
                for (id in baseData.colors.keys()) {
                    if (!colors.exists(id)) {
                        colors.set(id, Color.fromHex(baseData.colors.get(id)));
                    }
                }
            }
            this.colors = colors;
        }
        return this.colors;
    }

    public function getColor(colorId:ColorIdentifier, ?useDefault:Bool):Null<Color> {
        final color = this.getColors().get(colorId);
        if (color != null) {
            return color;
        }
        if (useDefault != false) {
            return this.getDefault(colorId);
        }
        return null;
    }

    function getDefault(colorId:ColorIdentifier):Null<Color> {
        var color = this.defaultColors.get(colorId);
        if (color != null) {
            return color;
        }
        color = ColorUtils.getColorRegistry().resolveDefaultColor(colorId, this);
        this.defaultColors.set(colorId, color);
        return color;
    }

    public function defines(colorId:ColorIdentifier):Bool {
        return this.getColors().exists(colorId);
    }

    public var type(get, never):ColorScheme;

    function get_type():ColorScheme {
        return switch (this.base) {
            case StandaloneThemeService.VS_LIGHT_THEME_NAME: ColorScheme.LIGHT;
            case StandaloneThemeService.HC_BLACK_THEME_NAME: ColorScheme.HIGH_CONTRAST_DARK;
            case StandaloneThemeService.HC_LIGHT_THEME_NAME: ColorScheme.HIGH_CONTRAST_LIGHT;
            default: ColorScheme.DARK;
        }
    }

    public var tokenTheme(get, never):TokenTheme;

    function get_tokenTheme():TokenTheme {
        if (this._tokenTheme == null) {
            var rules:Array<ITokenThemeRule> = [];
            var encodedTokensColors:Array<String> = [];
            if (this.themeData.inherit) {
                final baseData = StandaloneThemeService.getBuiltinRules(this.themeData.base);
                // Monaco pushes into the base theme's own `rules` array below
                // (the built-in data grows with each derived token theme);
                // Cityscape copies it, the built-in data is shared and immutable.
                rules = baseData.rules.copy();
                if (baseData.encodedTokensColors != null) {
                    encodedTokensColors = baseData.encodedTokensColors;
                }
            }
            // Pick up default colors from `editor.foreground` and `editor.background` if available
            final themeColors = this.themeData.colors;
            final editorForeground:Null<String> = themeColors != null ? themeColors.get('editor.foreground') : null;
            final editorBackground:Null<String> = themeColors != null ? themeColors.get('editor.background') : null;
            if (JsValues.truthy(editorForeground) || JsValues.truthy(editorBackground)) {
                final rule:ITokenThemeRule = {token: ''};
                if (JsValues.truthy(editorForeground)) {
                    rule.foreground = editorForeground;
                }
                if (JsValues.truthy(editorBackground)) {
                    rule.background = editorBackground;
                }
                rules.push(rule);
            }
            rules = rules.concat(this.themeData.rules != null ? this.themeData.rules : []);
            if (this.themeData.encodedTokensColors != null) {
                encodedTokensColors = this.themeData.encodedTokensColors;
            }
            this._tokenTheme = TokenTheme.createFromRawTokenTheme(rules, encodedTokensColors);
        }
        return this._tokenTheme;
    }

    /**
     * Cityscape addition: the rules of this theme for the TextMate tokenizer,
     * as tmTheme `settings` entries.
     *
     * - With `tokenColors` (a VS Code or tmTheme theme): those entries, after
     *   a scope-less entry made of `editor.foreground` and `editor.background`
     *   when they have none (as VS Code does).
     * - Without: Monaco's token rules of the theme (the inherited ones first,
     *   like `tokenTheme`), each `token` used as a scope selector, after the
     *   default colors (`editor.foreground`/`editor.background`, else the
     *   rule with the empty token).
     */
    public function getTextMateSettings():Array<Dynamic> {
        final result:Array<Dynamic> = [];
        final themeColors = this.themeData.colors;
        var editorForeground:Null<String> = themeColors != null ? themeColors.get('editor.foreground') : null;
        var editorBackground:Null<String> = themeColors != null ? themeColors.get('editor.background') : null;
        if (this.themeData.inherit && (editorForeground == null || editorBackground == null)) {
            final baseColors = StandaloneThemeService.getBuiltinRules(this.themeData.base).colors;
            if (editorForeground == null && baseColors != null) {
                editorForeground = baseColors.get('editor.foreground');
            }
            if (editorBackground == null && baseColors != null) {
                editorBackground = baseColors.get('editor.background');
            }
        }
        final tokenColors = this.themeData.tokenColors;
        if (tokenColors != null) {
            var hasDefault = false;
            for (rule in tokenColors) {
                if (textmate.RawGrammar.RawValue.field(rule, 'scope') == null) {
                    hasDefault = true;
                    break;
                }
            }
            if (!hasDefault && (editorForeground != null || editorBackground != null)) {
                result.push({settings: {foreground: editorForeground, background: editorBackground}});
            }
            for (rule in tokenColors) {
                result.push(rule);
            }
            return result;
        }
        var rules:Array<ITokenThemeRule> = [];
        if (this.themeData.inherit) {
            rules = StandaloneThemeService.getBuiltinRules(this.themeData.base).rules.copy();
        }
        rules = rules.concat(this.themeData.rules != null ? this.themeData.rules : []);
        inline function hex(color:Null<String>):Null<String> {
            return (color == null || color.length == 0) ? null : (color.charAt(0) == '#' ? color : '#' + color);
        }
        var defaultForeground = hex(editorForeground);
        var defaultBackground = hex(editorBackground);
        for (rule in rules) {
            if (rule.token == '') {
                if (defaultForeground == null && rule.foreground != null) {
                    defaultForeground = hex(rule.foreground);
                }
                if (defaultBackground == null && rule.background != null) {
                    defaultBackground = hex(rule.background);
                }
            }
        }
        result.push({settings: {foreground: defaultForeground, background: defaultBackground}});
        for (rule in rules) {
            if (rule.token == '') {
                continue;
            }
            result.push({scope: rule.token, settings: {foreground: hex(rule.foreground), background: hex(rule.background), fontStyle: rule.fontStyle}});
        }
        return result;
    }

    public function getTokenStyleMetadata(type:String, modifiers:Array<String>, modelLanguage:String):Null<ITokenStyle> {
        // use theme rules match
        final style = this.tokenTheme._match([type].concat(modifiers).join('.'));
        final metadata = style.metadata;
        final foreground:Int = TokenMetadata.getForeground(metadata);
        final fontStyle:Int = TokenMetadata.getFontStyle(metadata);
        return {
            foreground: foreground,
            italic: (fontStyle & FontStyle.Italic) != 0,
            bold: (fontStyle & FontStyle.Bold) != 0,
            underline: (fontStyle & FontStyle.Underline) != 0,
            strikethrough: (fontStyle & FontStyle.Strikethrough) != 0
        };
    }

    public var tokenColorMap(get, never):Array<String>;

    function get_tokenColorMap():Array<String> {
        return [];
    }

    public var semanticHighlighting(get, never):Bool;

    function get_semanticHighlighting():Bool {
        return false;
    }

}

/**
 * The theme service of a `Cityscape` context: the known themes (the four
 * built-in ones and those given to `defineTheme`), the current theme, and the
 * color map it gives to the context's tokenization registry.
 *
 * Not ported from Monaco: the CSS (theme rules, color variables, token
 * classes `.mtkN`), the icons style sheet, the OS high contrast detection
 * (`setAutoDetectHighContrast`), file and product icon themes.
 */
class StandaloneThemeService extends Disposable implements IStandaloneThemeService {

    public static inline final VS_LIGHT_THEME_NAME = 'vs';
    public static inline final VS_DARK_THEME_NAME = 'vs-dark';
    public static inline final HC_BLACK_THEME_NAME = 'hc-black';
    public static inline final HC_LIGHT_THEME_NAME = 'hc-light';

    public static function isBuiltinTheme(themeName:String):Bool {
        return (
            themeName == VS_LIGHT_THEME_NAME
            || themeName == VS_DARK_THEME_NAME
            || themeName == HC_BLACK_THEME_NAME
            || themeName == HC_LIGHT_THEME_NAME
        );
    }

    public static function getBuiltinRules(builtinTheme:BuiltinTheme):IStandaloneThemeData {
        return switch (builtinTheme) {
            case VS_LIGHT_THEME_NAME: Themes.vs;
            case VS_DARK_THEME_NAME: Themes.vs_dark;
            case HC_BLACK_THEME_NAME: Themes.hc_black;
            case HC_LIGHT_THEME_NAME: Themes.hc_light;
            // Monaco returns undefined (and fails later); the base is checked by `defineTheme`
            case _: throw 'Illegal theme base!';
        }
    }

    static function newBuiltInTheme(builtinTheme:BuiltinTheme):StandaloneTheme {
        final themeData = getBuiltinRules(builtinTheme);
        return new StandaloneTheme(builtinTheme, themeData);
    }

    static var _themeNameRegExp:Null<RegExp> = null;

    final _onColorThemeChange:Emitter<IStandaloneTheme>;
    public var onDidColorThemeChange(default, null):Event<IStandaloneTheme>;

    final _tokenizationRegistry:ITokenizationRegistry<ITokenizationSupport>;
    final _knownThemes:Map<String, StandaloneTheme>;
    var _colorMapOverride:Null<Array<Color>>;
    var _theme:Null<IStandaloneTheme> = null;

    /**
     * `tokenizationRegistry` is the registry of the `Cityscape` context
     * (Monaco uses the global `TokenizationRegistry`): it receives the color
     * map of the current theme.
     */
    public function new(tokenizationRegistry:ITokenizationRegistry<ITokenizationSupport>) {
        super();

        this._onColorThemeChange = this._register(new Emitter<IStandaloneTheme>());
        this.onDidColorThemeChange = this._onColorThemeChange.event;

        this._tokenizationRegistry = tokenizationRegistry;

        this._knownThemes = new Map<String, StandaloneTheme>();
        this._knownThemes.set(VS_LIGHT_THEME_NAME, newBuiltInTheme(VS_LIGHT_THEME_NAME));
        this._knownThemes.set(VS_DARK_THEME_NAME, newBuiltInTheme(VS_DARK_THEME_NAME));
        this._knownThemes.set(HC_BLACK_THEME_NAME, newBuiltInTheme(HC_BLACK_THEME_NAME));
        this._knownThemes.set(HC_LIGHT_THEME_NAME, newBuiltInTheme(HC_LIGHT_THEME_NAME));

        this._colorMapOverride = null;
        this.setTheme(VS_LIGHT_THEME_NAME);
    }

    public function defineTheme(themeName:String, themeData:IStandaloneThemeData):Void {
        if (_themeNameRegExp == null) {
            _themeNameRegExp = new RegExp('^[a-z0-9\\-]+$', 'i');
        }
        if (!_themeNameRegExp.test(themeName)) {
            throw 'Illegal theme name!';
        }
        if (!isBuiltinTheme(themeData.base) && !isBuiltinTheme(themeName)) {
            throw 'Illegal theme base!';
        }
        // set or replace theme
        this._knownThemes.set(themeName, new StandaloneTheme(themeName, themeData));

        if (isBuiltinTheme(themeName)) {
            for (theme in this._knownThemes) {
                if (theme.base == themeName) {
                    theme.notifyBaseUpdated();
                }
            }
        }
        if (this._theme.themeName == themeName) {
            this.setTheme(themeName); // refresh theme
        }
    }

    public function getColorTheme():IStandaloneTheme {
        return this._theme;
    }

    public function setColorMapOverride(colorMapOverride:Null<Array<Color>>):Void {
        this._colorMapOverride = colorMapOverride;
        this._updateThemeOrColorMap();
    }

    public function setTheme(themeName:String):Void {
        var theme:Null<StandaloneTheme>;
        if (this._knownThemes.exists(themeName)) {
            theme = this._knownThemes.get(themeName);
        }
        else {
            theme = this._knownThemes.get(VS_LIGHT_THEME_NAME);
        }
        this._updateActualTheme(theme);
    }

    function _updateActualTheme(desiredTheme:Null<IStandaloneTheme>):Void {
        if (desiredTheme == null || this._theme == desiredTheme) {
            // Nothing to do
            return;
        }
        this._theme = desiredTheme;
        this._updateThemeOrColorMap();
    }

    /**
     * Cityscape addition: gives the token color map of a theme when the
     * theme is applied, before Monaco's token theme (and after an explicit
     * `setColorMapOverride`). The TextMate service of the context sets it:
     * the color map of the TextMate theme then becomes the token color map,
     * once, without a second retokenization.
     */
    public var tokenColorMapProvider:Null<(theme:IStandaloneTheme) -> Null<Array<Color>>> = null;

    /**
     * Cityscape addition: applies the current theme again (after
     * `tokenColorMapProvider` changes).
     */
    public function refreshColorMap():Void {
        this._updateThemeOrColorMap();
    }

    function _updateThemeOrColorMap():Void {
        // Monaco also builds the theme CSS here (theming participants, color
        // variables, token classes): not ported, the view reads the colors.
        var colorMap = this._colorMapOverride;
        if (colorMap == null && this.tokenColorMapProvider != null) {
            colorMap = this.tokenColorMapProvider(this._theme);
        }
        if (colorMap == null) {
            colorMap = this._theme.tokenTheme.getColorMap();
        }

        this._tokenizationRegistry.setColorMap(colorMap);
        this._onColorThemeChange.fire(this._theme);
    }

}
