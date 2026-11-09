// Ported from vscode src/vs/workbench/services/themes/common/colorThemeData.ts
// (the semantic token styling of a color theme: `getTokenStyle`,
// `resolveScopes`, `getTokenStyleMetadata`, `TokenColorIndex`,
// `readSemanticTokenRule`, `getScopeMatcher`, `nameMatcher`; not in the
// sparse reference clone, read from the workbench bundle of VS Code)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.workbench.services.themes.common;

import cityscape.base.common.Color;
import cityscape.platform.theme.common.ThemeService.ITokenStyle;
import cityscape.platform.theme.common.TokenClassificationRegistry;
import cityscape.workbench.services.themes.common.TextMateScopeMatcher;
import textmate.RawGrammar.RawValue;

/**
 * The token colors of a theme by id (VS Code's `TokenColorIndex`): ids
 * start at 1, colors are normalized (`#RRGGBB`, `#RRGGBBAA` when not
 * opaque, upper case).
 */
class TokenColorIndex {

    var _lastColorId:Int = 0;
    final _id2color:Array<String> = [];
    final _color2id:Map<String, Int> = new Map();

    public function new() {}

    /**
     * Adds a color (a `#rgb`, `#rgba`, `#rrggbb` or `#rrggbbaa` string, or a
     * `Color`) and returns its id (0 for no color or an invalid one).
     */
    public function add(color:Null<Color>):Int {
        return addHex(color != null ? ColorFormatCSS.formatHexA(color, true) : null);
    }

    public function addHex(color:Null<String>):Int {
        final normalized = normalizeColor(color);
        if (normalized == null) {
            return 0;
        }
        final value = _color2id.get(normalized);
        if (value != null) {
            return value;
        }
        final id = ++_lastColorId;
        _color2id.set(normalized, id);
        _id2color[id] = normalized;
        return id;
    }

    /**
     * The id of a color, 0 when it is not in the index.
     */
    public function get(color:Null<Color>):Int {
        final normalized = normalizeColor(color != null ? ColorFormatCSS.formatHexA(color, true) : null);
        if (normalized == null) {
            return 0;
        }
        final value = _color2id.get(normalized);
        return value != null ? value : 0;
    }

    public function asArray():Array<String> {
        return _id2color.copy();
    }

    /**
     * VS Code's `normalizeColor`: `#rgb` and `#rgba` expanded, upper case,
     * an opaque alpha (`FF`) dropped; null for anything else.
     */
    public static function normalizeColor(color:Null<String>):Null<String> {
        if (color == null || color.length == 0) {
            return null;
        }
        final length = color.length;
        if (StringTools.fastCodeAt(color, 0) != '#'.code || (length != 4 && length != 5 && length != 7 && length != 9)) {
            return null;
        }
        final result = new StringBuf();
        result.addChar('#'.code);
        var count = 1;
        var c7 = 0;
        var c8 = 0;
        for (i in 1...length) {
            final upper = toUpperHex(StringTools.fastCodeAt(color, i));
            if (upper == 0) {
                return null;
            }
            final times = (length == 4 || length == 5) ? 2 : 1;
            for (_ in 0...times) {
                count++;
                if (count == 8) {
                    c7 = upper;
                }
                else if (count == 9) {
                    c8 = upper;
                }
                result.addChar(upper);
            }
        }
        final s = result.toString();
        if (count == 9 && c7 == 'F'.code && c8 == 'F'.code) {
            return s.substr(0, 7);
        }
        return s;
    }

    static function toUpperHex(charCode:Int):Int {
        if ((charCode >= '0'.code && charCode <= '9'.code) || (charCode >= 'A'.code && charCode <= 'F'.code)) {
            return charCode;
        }
        if (charCode >= 'a'.code && charCode <= 'f'.code) {
            return charCode - 'a'.code + 'A'.code;
        }
        return 0;
    }

}

/**
 * The semantic token styling of a VS Code color theme: its `tokenColors`
 * (TextMate rules) and its `semanticTokenColors` (semantic rules). A token
 * class takes the style of the best semantic rule, and for the styles no
 * semantic rule sets, the TextMate rules of the scopes vscode's token
 * classification registry probes for it (`type` probes `entity.name.type`
 * then `support.type`...). The user customizations of VS Code
 * (`editor.tokenColorCustomizations`, `editor.semanticTokenColorCustomizations`)
 * are not ported: a theme carries its rules.
 */
class ColorThemeData {

    public final themeTokenColors:Array<Dynamic>;
    public final semanticTokenRules:Array<SemanticTokenRule>;

    var themeTokenScopeMatchers:Null<Array<ScoreMatcher<ProbeScope>>> = null;

    /**
     * `tokenColors`: the TextMate rules (`{scope?, settings: {foreground?,
     * fontStyle?}}`); `semanticTokenColors`: the theme's object of selectors
     * to styles (a color string or `{foreground?, fontStyle?, bold?,
     * italic?, underline?, strikethrough?}`), or null.
     */
    public function new(tokenColors:Null<Array<Dynamic>>, semanticTokenColors:Dynamic) {
        this.themeTokenColors = tokenColors != null ? tokenColors : [];
        this.semanticTokenRules = readSemanticTokenRules(semanticTokenColors);
    }

    /**
     * The style of a token class (`getTokenStyle`), null properties for
     * what neither a semantic rule nor a probed TextMate rule sets.
     * `probeScopes` false (a Cityscape addition) reads the semantic rules
     * only.
     */
    public function getTokenStyle(type:String, modifiers:Array<String>, language:Null<String>, probeScopes:Bool = true):TokenStyle {
        var foreground:Null<Color> = null;
        var bold:Null<Bool> = null;
        var underline:Null<Bool> = null;
        var strikethrough:Null<Bool> = null;
        var italic:Null<Bool> = null;
        var foregroundScore:Float = -1;
        var boldScore:Float = -1;
        var underlineScore:Float = -1;
        var strikethroughScore:Float = -1;
        var italicScore:Float = -1;

        function _processStyle(matchScore:Float, style:TokenStyle):Void {
            if (style.foreground != null && foregroundScore <= matchScore) {
                foregroundScore = matchScore;
                foreground = style.foreground;
            }
            if (style.bold != null && boldScore <= matchScore) {
                boldScore = matchScore;
                bold = style.bold;
            }
            if (style.underline != null && underlineScore <= matchScore) {
                underlineScore = matchScore;
                underline = style.underline;
            }
            if (style.strikethrough != null && strikethroughScore <= matchScore) {
                strikethroughScore = matchScore;
                strikethrough = style.strikethrough;
            }
            if (style.italic != null && italicScore <= matchScore) {
                italicScore = matchScore;
                italic = style.italic;
            }
        }

        for (rule in this.semanticTokenRules) {
            final matchScore = rule.selector.match(type, modifiers, language);
            if (matchScore >= 0) {
                _processStyle(matchScore, rule.style);
            }
        }

        // a property set by a semantic rule cannot be replaced by a default
        var hasUndefinedStyleProperty = false;
        function settle(score:Float):Float {
            if (score == -1) {
                hasUndefinedStyleProperty = true;
                return score;
            }
            return Math.POSITIVE_INFINITY; // Number.MAX_VALUE
        }
        foregroundScore = settle(foregroundScore);
        boldScore = settle(boldScore);
        underlineScore = settle(underlineScore);
        strikethroughScore = settle(strikethroughScore);
        italicScore = settle(italicScore);

        if (hasUndefinedStyleProperty && probeScopes) {
            for (rule in TokenClassificationRegistry.getTokenClassificationRegistry().getTokenStylingDefaultRules()) {
                final matchScore = rule.selector.match(type, modifiers, language);
                if (matchScore >= 0) {
                    final scopesToProbe = rule.defaults.scopesToProbe;
                    if (scopesToProbe != null) {
                        final style = this.resolveScopes(scopesToProbe);
                        if (style != null) {
                            _processStyle(matchScore, style);
                        }
                    }
                    // The per theme type defaults (`rule.defaults[this.type]`)
                    // are not registered by vscode's default registry.
                }
            }
        }
        return new TokenStyle(foreground, bold, underline, strikethrough, italic);
    }

    /**
     * `getTokenStyleMetadata`: the style of a token class with its
     * foreground as a color id given by `colorId` (VS Code's
     * `getTokenColorIndex().get`, 0 for no foreground).
     * `typeWithLanguage` may carry a language (`type:language`).
     */
    public function getTokenStyleMetadata(typeWithLanguage:String, modifiers:Array<String>, defaultLanguage:String, colorId:(color:Null<Color>) -> Int):Null<ITokenStyle> {
        final parsed = TokenClassificationRegistry.parseClassifierString(typeWithLanguage, defaultLanguage);
        final style = this.getTokenStyle(parsed.type, modifiers, parsed.language);
        return {
            foreground: colorId(style.foreground),
            bold: style.bold,
            underline: style.underline,
            strikethrough: style.strikethrough,
            italic: style.italic
        };
    }

    /**
     * The style of the first of `scopes` some TextMate rule of the theme
     * colors (`resolveScopes`): for each property the rule with the best
     * score, the later rule on a tie.
     */
    public function resolveScopes(scopes:Array<ProbeScope>):Null<TokenStyle> {
        if (this.themeTokenScopeMatchers == null) {
            this.themeTokenScopeMatchers = [for (rule in this.themeTokenColors) getScopeMatcher(rule)];
        }
        final matchers = this.themeTokenScopeMatchers;

        for (scope in scopes) {
            var foreground:Null<String> = null;
            var fontStyle:Null<String> = null;
            var foregroundScore = -1;
            var fontStyleScore = -1;

            for (i in 0...matchers.length) {
                final score = matchers[i](scope);
                if (score >= 0) {
                    final settings:Dynamic = RawValue.field(this.themeTokenColors[i], 'settings');
                    final ruleForeground = RawValue.string(RawValue.field(settings, 'foreground'));
                    if (score >= foregroundScore && ruleForeground != null && ruleForeground.length > 0) {
                        foreground = ruleForeground;
                        foregroundScore = score;
                    }
                    final ruleFontStyle = RawValue.string(RawValue.field(settings, 'fontStyle'));
                    if (score >= fontStyleScore && ruleFontStyle != null) {
                        fontStyle = ruleFontStyle;
                        fontStyleScore = score;
                    }
                }
            }
            if (foreground != null || fontStyle != null) {
                return TokenStyle.fromSettings(foreground, fontStyle);
            }
        }
        return null;
    }

    /**
     * Gives the colors of the theme a semantic token may take (the TextMate
     * rules' and the semantic rules', in VS Code's `getTokenColorIndex`
     * order) to `add`, for the token color map.
     */
    public function forEachTokenColor(add:(color:Null<String>) -> Void):Void {
        for (rule in this.themeTokenColors) {
            final settings:Dynamic = RawValue.field(rule, 'settings');
            if (!RawValue.isObject(settings)) {
                continue;
            }
            add(RawValue.string(RawValue.field(settings, 'foreground')));
            add(RawValue.string(RawValue.field(settings, 'background')));
        }
        for (rule in this.semanticTokenRules) {
            final foreground = rule.style.foreground;
            add(foreground != null ? ColorFormatCSS.formatHexA(foreground, true) : null);
        }
    }

    static function noMatch(_:ProbeScope):Int {
        return -1;
    }

    /**
     * The scorer of a TextMate rule (`getScopeMatcher`): the best score of
     * its scope selectors, -1 for a rule without scope or settings.
     */
    public static function getScopeMatcher(rule:Dynamic):ScoreMatcher<ProbeScope> {
        final ruleScope:Dynamic = RawValue.field(rule, 'scope');
        if (!RawValue.truthy(ruleScope) || !RawValue.truthy(RawValue.field(rule, 'settings'))) {
            return noMatch;
        }
        final matchers:Array<ScoreMatcherWithPriority<ProbeScope>> = [];
        if (Std.isOfType(ruleScope, Array)) {
            final scopes:Array<Dynamic> = ruleScope;
            for (rs in scopes) {
                final s = RawValue.string(rs);
                if (s != null) {
                    TextMateScopeMatcher.createMatchers(s, nameMatcher, matchers);
                }
            }
        }
        else {
            final s = RawValue.string(ruleScope);
            if (s != null) {
                TextMateScopeMatcher.createMatchers(s, nameMatcher, matchers);
            }
        }
        if (matchers.length == 0) {
            return noMatch;
        }
        return (scope:ProbeScope) -> {
            var score = matchers[0].matcher(scope);
            for (i in 1...matchers.length) {
                score = Std.int(Math.max(score, matchers[i].matcher(scope)));
            }
            return score;
        };
    }

    static function nameMatcher(identifiers:Array<String>, scopes:ProbeScope):Int {
        if (scopes.length < identifiers.length) {
            return -1;
        }
        var score:Null<Int> = null;
        for (identifier in identifiers) {
            var found = false;
            var i = scopes.length - 1;
            while (i >= 0) {
                if (scopesAreMatching(scopes[i], identifier)) {
                    score = (i + 1) * 0x10000 + identifier.length;
                    found = true;
                    break;
                }
                i--;
            }
            if (!found) {
                return -1;
            }
        }
        return score != null ? score : -1;
    }

    static function scopesAreMatching(thisScopeName:Null<String>, scopeName:String):Bool {
        if (thisScopeName == null || thisScopeName.length == 0) {
            return false;
        }
        if (thisScopeName == scopeName) {
            return true;
        }
        final len = scopeName.length;
        return thisScopeName.length > len && thisScopeName.substr(0, len) == scopeName && StringTools.fastCodeAt(thisScopeName, len) == '.'.code;
    }

    /**
     * A rule of `semanticTokenColors` (`readSemanticTokenRule`): a color
     * string, or an object with `foreground`, `fontStyle`, `bold`,
     * `italic`, `underline`, `strikethrough`.
     */
    public static function readSemanticTokenRule(selectorString:String, settings:Dynamic):Null<SemanticTokenRule> {
        final selector = TokenClassificationRegistry.getTokenClassificationRegistry().parseTokenSelector(selectorString);
        var style:Null<TokenStyle> = null;
        final settingsString = RawValue.string(settings);
        if (settingsString != null) {
            style = TokenStyle.fromSettings(settingsString, null);
        }
        else if (isSemanticTokenColorizationSetting(settings)) {
            style = TokenStyle.fromSettings(
                RawValue.string(RawValue.field(settings, 'foreground')),
                RawValue.string(RawValue.field(settings, 'fontStyle')),
                readBool(settings, 'bold'),
                readBool(settings, 'underline'),
                readBool(settings, 'strikethrough'),
                readBool(settings, 'italic')
            );
        }
        if (style != null) {
            return {selector: selector, style: style};
        }
        return null;
    }

    static function readBool(settings:Dynamic, name:String):Null<Bool> {
        final value:Dynamic = RawValue.field(settings, name);
        return Std.isOfType(value, Bool) ? (value : Bool) : null;
    }

    static function isSemanticTokenColorizationSetting(settings:Dynamic):Bool {
        if (settings == null || !RawValue.isObject(settings)) {
            return false;
        }
        return RawValue.string(RawValue.field(settings, 'foreground')) != null
            || RawValue.string(RawValue.field(settings, 'fontStyle')) != null
            || readBool(settings, 'italic') != null
            || readBool(settings, 'underline') != null
            || readBool(settings, 'strikethrough') != null
            || readBool(settings, 'bold') != null;
    }

    /**
     * The rules of a theme's `semanticTokenColors` object, in its order.
     */
    public static function readSemanticTokenRules(semanticTokenColors:Dynamic):Array<SemanticTokenRule> {
        final rules:Array<SemanticTokenRule> = [];
        if (semanticTokenColors == null || !RawValue.isObject(semanticTokenColors)) {
            return rules;
        }
        for (selector in RawValue.fields(semanticTokenColors)) {
            final rule = readSemanticTokenRule(selector, RawValue.field(semanticTokenColors, selector));
            if (rule != null) {
                rules.push(rule);
            }
        }
        return rules;
    }

}
