// Ported from vscode src/vs/editor/common/languages/supports/tokenization.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages.supports;

import cityscape.base.common.Color;
import cityscape.base.common.JsValues;
import cityscape.base.common.RegExp;
import cityscape.common.EncodedTokenAttributes.ColorId;
import cityscape.common.EncodedTokenAttributes.FontStyle;
import cityscape.common.EncodedTokenAttributes.LanguageId;
import cityscape.common.EncodedTokenAttributes.MetadataConsts;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;

typedef ITokenThemeRule = {
    var token:String;
    @:optional var foreground:String;
    @:optional var background:String;
    @:optional var fontStyle:String;
}

class ParsedTokenThemeRule {

    public final token:String;
    public final index:Int;

    /**
     * -1 if not set. An or mask of `FontStyle` otherwise.
     */
    public final fontStyle:FontStyle;
    public final foreground:Null<String>;
    public final background:Null<String>;

    public function new(token:String, index:Int, fontStyle:Int, foreground:Null<String>, background:Null<String>) {
        this.token = token;
        this.index = index;
        this.fontStyle = fontStyle;
        this.foreground = foreground;
        this.background = background;
    }

}

/**
 * Module functions of tokenization.ts.
 */
class Tokenization {

    /**
     * Parse a raw theme into rules.
     */
    public static function parseTokenTheme(source:Null<Array<ITokenThemeRule>>):Array<ParsedTokenThemeRule> {
        if (source == null || !JsValues.isArray(source)) {
            return [];
        }
        final result:Array<ParsedTokenThemeRule> = [];
        var resultLen = 0;
        for (i in 0...source.length) {
            final entry = source[i];

            var fontStyle:Int = FontStyle.NotSet;
            if (JsValues.isString(entry.fontStyle)) {
                fontStyle = FontStyle.None;

                final segments = entry.fontStyle.split(' ');
                for (j in 0...segments.length) {
                    final segment = segments[j];
                    switch (segment) {
                        case 'italic':
                            fontStyle = fontStyle | FontStyle.Italic;
                        case 'bold':
                            fontStyle = fontStyle | FontStyle.Bold;
                        case 'underline':
                            fontStyle = fontStyle | FontStyle.Underline;
                        case 'strikethrough':
                            fontStyle = fontStyle | FontStyle.Strikethrough;
                        case _:
                    }
                }
            }

            var foreground:Null<String> = null;
            if (JsValues.isString(entry.foreground)) {
                foreground = entry.foreground;
            }

            var background:Null<String> = null;
            if (JsValues.isString(entry.background)) {
                background = entry.background;
            }

            result[resultLen++] = new ParsedTokenThemeRule(
                JsValues.truthy(entry.token) ? entry.token : '',
                i,
                fontStyle,
                foreground,
                background
            );
        }

        return result;
    }

    /**
     * Resolve rules (i.e. inheritance).
     */
    static function resolveParsedTokenThemeRules(parsedThemeRules:Array<ParsedTokenThemeRule>, customTokenColors:Array<String>):TokenTheme {

        // Sort rules lexicographically, and then by index if necessary
        haxe.ds.ArraySort.sort(parsedThemeRules, (a, b) -> {
            final r = strcmp(a.token, b.token);
            if (r != 0) {
                return r;
            }
            return a.index - b.index;
        });

        // Determine defaults
        var defaultFontStyle:Int = FontStyle.None;
        var defaultForeground = '000000';
        var defaultBackground = 'ffffff';
        while (parsedThemeRules.length >= 1 && parsedThemeRules[0].token == '') {
            final incomingDefaults = parsedThemeRules.shift();
            if (incomingDefaults.fontStyle != FontStyle.NotSet) {
                defaultFontStyle = incomingDefaults.fontStyle;
            }
            if (incomingDefaults.foreground != null) {
                defaultForeground = incomingDefaults.foreground;
            }
            if (incomingDefaults.background != null) {
                defaultBackground = incomingDefaults.background;
            }
        }
        final colorMap = new ColorMap();

        // start with token colors from custom token themes
        for (color in customTokenColors) {
            colorMap.getId(color);
        }

        final foregroundColorId = colorMap.getId(defaultForeground);
        final backgroundColorId = colorMap.getId(defaultBackground);

        final defaults = new ThemeTrieElementRule(defaultFontStyle, foregroundColorId, backgroundColorId);
        final root = new ThemeTrieElement(defaults);
        for (i in 0...parsedThemeRules.length) {
            final rule = parsedThemeRules[i];
            root.insert(rule.token, rule.fontStyle, colorMap.getId(rule.foreground), colorMap.getId(rule.background));
        }

        return new TokenTheme(colorMap, root);
    }

    static var _standardTokenTypeRegExp:Null<RegExp> = null;

    public static function toStandardTokenType(tokenType:String):StandardTokenType {
        if (_standardTokenTypeRegExp == null) {
            _standardTokenTypeRegExp = new RegExp('\\b(comment|string|regex|regexp)\\b');
        }
        final m = _standardTokenTypeRegExp.exec(tokenType);
        if (m == null) {
            return StandardTokenType.Other;
        }
        switch (m[1]) {
            case 'comment':
                return StandardTokenType.Comment;
            case 'string':
                return StandardTokenType.String;
            case 'regex':
                return StandardTokenType.RegEx;
            case 'regexp':
                return StandardTokenType.RegEx;
            case _:
        }
        throw 'Unexpected match for standard token type!';
    }

    public static function strcmp(a:String, b:String):Int {
        if (a < b) {
            return -1;
        }
        if (a > b) {
            return 1;
        }
        return 0;
    }

    public static function generateTokensCSSForColorMap(colorMap:Array<Color>):String {
        final rules:Array<String> = [];
        final len = colorMap.length;
        if (len > 1) {
            // `rules[0]` is a hole in Monaco, joined as an empty string
            rules[0] = '';
        }
        for (i in 1...len) {
            final color = colorMap[i];
            rules[i] = '.mtk' + i + ' { color: ' + Std.string(color) + '; }';
        }
        rules.push('.mtki { font-style: italic; }');
        rules.push('.mtkb { font-weight: bold; }');
        rules.push('.mtku { text-decoration: underline; text-underline-position: under; }');
        rules.push('.mtks { text-decoration: line-through; }');
        rules.push('.mtks.mtku { text-decoration: underline line-through; text-underline-position: under; }');
        return rules.join('\n');
    }

    @:allow(cityscape.common.languages.supports)
    static function createTokenTheme(source:Array<ParsedTokenThemeRule>, customTokenColors:Array<String>):TokenTheme {
        return resolveParsedTokenThemeRules(source, customTokenColors);
    }

}

class ColorMap {

    static var _colorRegExp:Null<RegExp> = null;

    var _lastColorId:Int;
    final _id2color:Array<Color>;
    final _color2id:Map<String, ColorId>;

    public function new() {
        this._lastColorId = 0;
        this._id2color = [];
        this._color2id = new Map<String, ColorId>();
    }

    public function getId(color:Null<String>):ColorId {
        if (color == null) {
            return 0;
        }
        if (_colorRegExp == null) {
            _colorRegExp = new RegExp('^#?([0-9A-Fa-f]{6})([0-9A-Fa-f]{2})?$');
        }
        final match = _colorRegExp.exec(color);
        if (match == null) {
            throw 'Illegal value for token color: ' + color;
        }
        final key = match[1].toUpperCase();
        var value = this._color2id.get(key);
        if (value != null) {
            return value;
        }
        value = ++this._lastColorId;
        this._color2id.set(key, value);
        this._id2color[value] = Color.fromHex('#' + key);
        return value;
    }

    public function getColorMap():Array<Color> {
        return this._id2color.copy();
    }

}

class TokenTheme {

    public static function createFromRawTokenTheme(source:Array<ITokenThemeRule>, customTokenColors:Array<String>):TokenTheme {
        return createFromParsedTokenTheme(Tokenization.parseTokenTheme(source), customTokenColors);
    }

    public static function createFromParsedTokenTheme(source:Array<ParsedTokenThemeRule>, customTokenColors:Array<String>):TokenTheme {
        return Tokenization.createTokenTheme(source, customTokenColors);
    }

    final _colorMap:ColorMap;
    final _root:ThemeTrieElement;
    final _cache:Map<String, Int>;

    public function new(colorMap:ColorMap, root:ThemeTrieElement) {
        this._colorMap = colorMap;
        this._root = root;
        this._cache = new Map<String, Int>();
    }

    public function getColorMap():Array<Color> {
        return this._colorMap.getColorMap();
    }

    /**
     * used for testing purposes
     */
    public function getThemeTrieElement():ExternalThemeTrieElement {
        return this._root.toExternalThemeTrieElement();
    }

    public function _match(token:String):ThemeTrieElementRule {
        return this._root.match(token);
    }

    public function match(languageId:LanguageId, token:String):Int {
        // The cache contains the metadata without the language bits set.
        var result = this._cache.get(token);
        if (result == null) {
            final rule = this._match(token);
            final standardToken:Int = Tokenization.toStandardTokenType(token);
            result = (
                rule.metadata
                | (standardToken << MetadataConsts.TOKEN_TYPE_OFFSET)
            );
            this._cache.set(token, result);
        }

        return (
            result
            | ((languageId : Int) << MetadataConsts.LANGUAGEID_OFFSET)
        );
    }

}

class ThemeTrieElementRule {

    var _fontStyle:FontStyle;
    var _foreground:ColorId;
    var _background:ColorId;
    public var metadata:Int;

    public function new(fontStyle:FontStyle, foreground:ColorId, background:ColorId) {
        this._fontStyle = fontStyle;
        this._foreground = foreground;
        this._background = background;
        this.metadata = (
            ((this._fontStyle : Int) << MetadataConsts.FONT_STYLE_OFFSET)
            | ((this._foreground : Int) << MetadataConsts.FOREGROUND_OFFSET)
            | ((this._background : Int) << MetadataConsts.BACKGROUND_OFFSET)
        );
    }

    public function clone():ThemeTrieElementRule {
        return new ThemeTrieElementRule(this._fontStyle, this._foreground, this._background);
    }

    public function acceptOverwrite(fontStyle:FontStyle, foreground:ColorId, background:ColorId):Void {
        if (fontStyle != FontStyle.NotSet) {
            this._fontStyle = fontStyle;
        }
        if (foreground != ColorId.None) {
            this._foreground = foreground;
        }
        if (background != ColorId.None) {
            this._background = background;
        }
        this.metadata = (
            ((this._fontStyle : Int) << MetadataConsts.FONT_STYLE_OFFSET)
            | ((this._foreground : Int) << MetadataConsts.FOREGROUND_OFFSET)
            | ((this._background : Int) << MetadataConsts.BACKGROUND_OFFSET)
        );
    }

}

class ExternalThemeTrieElement {

    public final mainRule:ThemeTrieElementRule;
    public final children:Map<String, ExternalThemeTrieElement>;

    /**
     * `children` is a `Map` or an object literal (`{'var': ...}`), like in
     * Monaco.
     */
    public function new(mainRule:ThemeTrieElementRule, ?children:haxe.extern.EitherType<Map<String, ExternalThemeTrieElement>, haxe.DynamicAccess<ExternalThemeTrieElement>>) {
        this.mainRule = mainRule;
        if (children == null) {
            this.children = new Map<String, ExternalThemeTrieElement>();
        }
        else if (Std.isOfType(children, haxe.Constraints.IMap)) {
            this.children = (cast children : Map<String, ExternalThemeTrieElement>);
        }
        else {
            this.children = new Map<String, ExternalThemeTrieElement>();
            final object:haxe.DynamicAccess<ExternalThemeTrieElement> = cast children;
            for (key in object.keys()) {
                this.children.set(key, object.get(key));
            }
        }
    }

}

class ThemeTrieElement {

    final _mainRule:ThemeTrieElementRule;
    final _children:Map<String, ThemeTrieElement>;

    public function new(mainRule:ThemeTrieElementRule) {
        this._mainRule = mainRule;
        this._children = new Map<String, ThemeTrieElement>();
    }

    /**
     * used for testing purposes
     */
    public function toExternalThemeTrieElement():ExternalThemeTrieElement {
        final children = new Map<String, ExternalThemeTrieElement>();
        for (index => element in this._children) {
            children.set(index, element.toExternalThemeTrieElement());
        }
        return new ExternalThemeTrieElement(this._mainRule, children);
    }

    public function match(token:String):ThemeTrieElementRule {
        if (token == '') {
            return this._mainRule;
        }

        final dotIndex = token.indexOf('.');
        var head:String;
        var tail:String;
        if (dotIndex == -1) {
            head = token;
            tail = '';
        }
        else {
            head = token.substring(0, dotIndex);
            tail = token.substring(dotIndex + 1);
        }

        final child = this._children.get(head);
        if (child != null) {
            return child.match(tail);
        }

        return this._mainRule;
    }

    public function insert(token:String, fontStyle:FontStyle, foreground:ColorId, background:ColorId):Void {
        if (token == '') {
            // Merge into the main rule
            this._mainRule.acceptOverwrite(fontStyle, foreground, background);
            return;
        }

        final dotIndex = token.indexOf('.');
        var head:String;
        var tail:String;
        if (dotIndex == -1) {
            head = token;
            tail = '';
        }
        else {
            head = token.substring(0, dotIndex);
            tail = token.substring(dotIndex + 1);
        }

        var child = this._children.get(head);
        if (child == null) {
            child = new ThemeTrieElement(this._mainRule.clone());
            this._children.set(head, child);
        }

        child.insert(tail, fontStyle, foreground, background);
    }

}
