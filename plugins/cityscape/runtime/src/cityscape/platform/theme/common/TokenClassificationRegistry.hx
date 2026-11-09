// Ported from vscode src/vs/platform/theme/common/tokenClassificationRegistry.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common;

import cityscape.base.common.Color;

/**
 * The style of a semantic token class: its foreground and font styles, each
 * null when the style does not set it (Monaco's `undefined`).
 */
class TokenStyle {

    public final foreground:Null<Color>;
    public final bold:Null<Bool>;
    public final underline:Null<Bool>;
    public final strikethrough:Null<Bool>;
    public final italic:Null<Bool>;

    public function new(foreground:Null<Color>, bold:Null<Bool>, underline:Null<Bool>, strikethrough:Null<Bool>, italic:Null<Bool>) {
        this.foreground = foreground;
        this.bold = bold;
        this.underline = underline;
        this.strikethrough = strikethrough;
        this.italic = italic;
    }

    /**
     * `TokenStyle.fromSettings(foreground, fontStyle, bold?, underline?,
     * strikethrough?, italic?)`: a `fontStyle` string (even empty) sets the
     * four font styles, the ones it names to true.
     */
    public static function fromSettings(foreground:Null<String>, fontStyle:Null<String>, ?bold:Null<Bool>, ?underline:Null<Bool>, ?strikethrough:Null<Bool>, ?italic:Null<Bool>):TokenStyle {
        var foregroundColor:Null<Color> = null;
        if (foreground != null) {
            foregroundColor = Color.fromHex(foreground);
        }
        if (fontStyle != null) {
            // `/italic|bold|underline|strikethrough/g` over the string
            bold = fontStyle.indexOf('bold') != -1;
            italic = fontStyle.indexOf('italic') != -1;
            underline = fontStyle.indexOf('underline') != -1;
            strikethrough = fontStyle.indexOf('strikethrough') != -1;
        }
        return new TokenStyle(foregroundColor, bold, underline, strikethrough, italic);
    }

    public static function equals(s1:Null<TokenStyle>, s2:Null<TokenStyle>):Bool {
        if (s1 == s2) {
            return true;
        }
        return s1 != null && s2 != null
            && (s1.foreground != null ? s1.foreground.equals(s2.foreground) : s2.foreground == null)
            && s1.bold == s2.bold
            && s1.underline == s2.underline
            && s1.strikethrough == s2.strikethrough
            && s1.italic == s2.italic;
    }

}

/**
 * A parsed token selector (`(*|type)(.modifier)*(:language)?`): `match`
 * gives the score of a token class (-1 when it does not match).
 */
class TokenSelector {

    public final id:String;

    final _match:(type:String, modifiers:Array<String>, language:Null<String>) -> Int;

    public function new(id:String, match:(type:String, modifiers:Array<String>, language:Null<String>) -> Int) {
        this.id = id;
        this._match = match;
    }

    public function match(type:String, modifiers:Array<String>, language:Null<String>):Int {
        return _match(type, modifiers, language);
    }

}

typedef TokenTypeOrModifierContribution = {
    final num:Int;
    final id:String;
    @:optional final superType:Null<String>;
    final description:String;
    @:optional final deprecationMessage:Null<String>;
}

/**
 * Scopes probed in the TextMate rules of a theme, in order: each one a
 * list of scope names (`[['entity.name.type'], ['support.type']]`).
 */
typedef ProbeScope = Array<String>;

/**
 * The default style of a token class: the TextMate scopes to probe in the
 * theme (`scopesToProbe`). The per theme type defaults of vscode
 * (`light`, `dark`, `hcDark`, `hcLight`) are not registered by the default
 * registry and are not ported.
 */
typedef TokenStyleDefaults = {
    @:optional var scopesToProbe:Null<Array<ProbeScope>>;
}

typedef SemanticTokenDefaultRule = {
    final selector:TokenSelector;
    final defaults:TokenStyleDefaults;
}

typedef SemanticTokenRule = {
    final style:TokenStyle;
    final selector:TokenSelector;
}

/**
 * The result of `parseClassifierString`.
 */
typedef ParsedClassifier = {
    final type:String;
    final modifiers:Array<String>;
    final language:Null<String>;
}

/**
 * The token types and modifiers of semantic highlighting, and their default
 * styles (the TextMate scopes probed when a theme has no semantic rule for
 * a class). Monaco's JSON schema of the token styling is not ported.
 */
class TokenClassificationRegistry {

    static inline final TOKEN_TYPE_WILDCARD = '*';
    static inline final CHAR_LANGUAGE = ':'.code;
    static inline final CHAR_MODIFIER = '.'.code;

    var currentTypeNumber = 0;
    var currentModifierBit = 1;

    final tokenTypeById:Map<String, TokenTypeOrModifierContribution> = new Map();
    final tokenTypeIds:Array<String> = [];
    final tokenModifierById:Map<String, TokenTypeOrModifierContribution> = new Map();
    final tokenModifierIds:Array<String> = [];

    var tokenStylingDefaultRules:Array<SemanticTokenDefaultRule> = [];

    var typeHierarchy:Map<String, Array<String>> = new Map();

    public function new() {}

    /**
     * `^\w+[-_\w+]*$` (`typeAndModifierIdPattern`).
     */
    static function isValidId(id:String):Bool {
        if (id.length == 0 || !isWordChar(StringTools.fastCodeAt(id, 0))) {
            return false;
        }
        for (i in 1...id.length) {
            final c = StringTools.fastCodeAt(id, i);
            if (!isWordChar(c) && c != '-'.code && c != '+'.code) {
                return false;
            }
        }
        return true;
    }

    static inline function isWordChar(c:Int):Bool {
        return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code) || c == '_'.code;
    }

    public function registerTokenType(id:String, description:String, ?superType:String, ?deprecationMessage:String):Void {
        if (!isValidId(id)) {
            throw 'Invalid token type id.';
        }
        if (superType != null && superType.length > 0 && !isValidId(superType)) {
            throw 'Invalid token super type id.';
        }
        final num = this.currentTypeNumber++;
        if (!tokenTypeById.exists(id)) {
            tokenTypeIds.push(id);
        }
        tokenTypeById.set(id, {num: num, id: id, superType: superType, description: description, deprecationMessage: deprecationMessage});
        this.typeHierarchy = new Map();
    }

    public function registerTokenModifier(id:String, description:String, ?deprecationMessage:String):Void {
        if (!isValidId(id)) {
            throw 'Invalid token modifier id.';
        }
        final num = this.currentModifierBit;
        this.currentModifierBit = this.currentModifierBit * 2;
        if (!tokenModifierById.exists(id)) {
            tokenModifierIds.push(id);
        }
        tokenModifierById.set(id, {num: num, id: id, description: description, deprecationMessage: deprecationMessage});
    }

    /**
     * Parses a token selector (`(*|type)(.modifier)*(:language)?`) for
     * `language` (all languages when null).
     */
    public function parseTokenSelector(selectorString:String, ?language:String):TokenSelector {
        final selector = parseClassifierString(selectorString, language);

        if (selector.type.length == 0) {
            return new TokenSelector("$invalid", (_, _, _) -> -1);
        }

        final selectorType = selector.type;
        final selectorModifiers = selector.modifiers;
        final selectorLanguage = selector.language;
        final sortedModifiers = selectorModifiers.copy();
        sortedModifiers.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        final id = [selectorType].concat(sortedModifiers).join('.') + (selectorLanguage != null ? ':' + selectorLanguage : '');

        return new TokenSelector(id, (type:String, modifiers:Array<String>, language:Null<String>) -> {
            var score = 0;
            if (selectorLanguage != null) {
                if (selectorLanguage != language) {
                    return -1;
                }
                score += 10;
            }
            if (selectorType != TOKEN_TYPE_WILDCARD) {
                final hierarchy = this.getTypeHierarchy(type);
                final level = hierarchy.indexOf(selectorType);
                if (level == -1) {
                    return -1;
                }
                score += (100 - level);
            }
            // all selector modifiers must be present
            for (selectorModifier in selectorModifiers) {
                if (modifiers.indexOf(selectorModifier) == -1) {
                    return -1;
                }
            }
            return score + selectorModifiers.length * 100;
        });
    }

    public function registerTokenStyleDefault(selector:TokenSelector, defaults:TokenStyleDefaults):Void {
        this.tokenStylingDefaultRules.push({selector: selector, defaults: defaults});
    }

    public function deregisterTokenStyleDefault(selector:TokenSelector):Void {
        final selectorString = selector.id;
        this.tokenStylingDefaultRules = this.tokenStylingDefaultRules.filter(r -> r.selector.id != selectorString);
    }

    public function deregisterTokenType(id:String):Void {
        tokenTypeById.remove(id);
        tokenTypeIds.remove(id);
        this.typeHierarchy = new Map();
    }

    public function deregisterTokenModifier(id:String):Void {
        tokenModifierById.remove(id);
        tokenModifierIds.remove(id);
    }

    public function getTokenTypes():Array<TokenTypeOrModifierContribution> {
        return [for (id in tokenTypeIds) tokenTypeById.get(id)];
    }

    public function getTokenModifiers():Array<TokenTypeOrModifierContribution> {
        return [for (id in tokenModifierIds) tokenModifierById.get(id)];
    }

    /**
     * The styling rules to use when a theme does not define any styling rules.
     */
    public function getTokenStylingDefaultRules():Array<SemanticTokenDefaultRule> {
        return this.tokenStylingDefaultRules;
    }

    function getTypeHierarchy(typeId:String):Array<String> {
        var hierarchy = this.typeHierarchy.get(typeId);
        if (hierarchy == null) {
            hierarchy = [typeId];
            this.typeHierarchy.set(typeId, hierarchy);
            var type = this.tokenTypeById.get(typeId);
            while (type != null && type.superType != null && type.superType.length > 0) {
                hierarchy.push(type.superType);
                type = this.tokenTypeById.get(type.superType);
            }
        }
        return hierarchy;
    }

    /**
     * Splits `type.modifier1.modifier2:language` (the language is
     * `defaultLanguage` when the string has none).
     */
    public static function parseClassifierString(s:String, defaultLanguage:Null<String>):ParsedClassifier {
        var k = s.length;
        var language:Null<String> = defaultLanguage;
        final modifiers:Array<String> = [];

        var i = k - 1;
        while (i >= 0) {
            final ch = StringTools.fastCodeAt(s, i);
            if (ch == CHAR_LANGUAGE || ch == CHAR_MODIFIER) {
                final segment = s.substring(i + 1, k);
                k = i;
                if (ch == CHAR_LANGUAGE) {
                    language = segment;
                }
                else {
                    modifiers.push(segment);
                }
            }
            i--;
        }
        final type = s.substring(0, k);
        return {type: type, modifiers: modifiers, language: language};
    }

    static var _default:Null<TokenClassificationRegistry> = null;

    /**
     * The registry with vscode's default token types, modifiers and
     * default rules (`getTokenClassificationRegistry`). Created on first
     * use; immutable data shared by the contexts.
     */
    public static function getTokenClassificationRegistry():TokenClassificationRegistry {
        if (_default == null) {
            _default = createDefaultTokenClassificationRegistry();
        }
        return _default;
    }

    static function createDefaultTokenClassificationRegistry():TokenClassificationRegistry {

        final registry = new TokenClassificationRegistry();

        function registerTokenStyleDefault(selectorString:String, scopesToProbe:Array<ProbeScope>):Void {
            final selector = registry.parseTokenSelector(selectorString);
            registry.registerTokenStyleDefault(selector, {scopesToProbe: scopesToProbe});
        }

        function registerTokenType(id:String, description:String, ?scopesToProbe:Array<ProbeScope>, ?superType:String, ?deprecationMessage:String):String {
            registry.registerTokenType(id, description, superType, deprecationMessage);
            // `scopesToProbe` defaults to `[]` (JavaScript also takes the
            // default for an explicit `undefined`, as for `label`): every
            // type gets a default rule
            registerTokenStyleDefault(id, scopesToProbe != null ? scopesToProbe : []);
            return id;
        }

        // default token types

        registerTokenType('comment', "Style for comments.", [['comment']]);
        registerTokenType('string', "Style for strings.", [['string']]);
        registerTokenType('keyword', "Style for keywords.", [['keyword.control']]);
        registerTokenType('number', "Style for numbers.", [['constant.numeric']]);
        registerTokenType('regexp', "Style for expressions.", [['constant.regexp']]);
        registerTokenType('operator', "Style for operators.", [['keyword.operator']]);

        registerTokenType('namespace', "Style for namespaces.", [['entity.name.namespace']]);

        registerTokenType('type', "Style for types.", [['entity.name.type'], ['support.type']]);
        registerTokenType('struct', "Style for structs.", [['entity.name.type.struct']]);
        registerTokenType('class', "Style for classes.", [['entity.name.type.class'], ['support.class']]);
        registerTokenType('interface', "Style for interfaces.", [['entity.name.type.interface']]);
        registerTokenType('enum', "Style for enums.", [['entity.name.type.enum']]);
        registerTokenType('typeParameter', "Style for type parameters.", [['entity.name.type.parameter']]);

        registerTokenType('function', "Style for functions", [['entity.name.function'], ['support.function']]);
        registerTokenType('member', "Style for member functions", [], 'method', 'Deprecated use `method` instead');
        registerTokenType('method', "Style for method (member functions)", [['entity.name.function.member'], ['support.function']]);
        registerTokenType('macro', "Style for macros.", [['entity.name.function.preprocessor']]);

        registerTokenType('variable', "Style for variables.", [['variable.other.readwrite'], ['entity.name.variable']]);
        registerTokenType('parameter', "Style for parameters.", [['variable.parameter']]);
        registerTokenType('property', "Style for properties.", [['variable.other.property']]);
        registerTokenType('enumMember', "Style for enum members.", [['variable.other.enummember']]);
        registerTokenType('event', "Style for events.", [['variable.other.event']]);
        registerTokenType('decorator', "Style for decorators & annotations.", [['entity.name.decorator'], ['entity.name.function']]);

        registerTokenType('label', "Style for labels. ", null);

        // default token modifiers

        registry.registerTokenModifier('declaration', "Style for all symbol declarations.");
        registry.registerTokenModifier('documentation', "Style to use for references in documentation.");
        registry.registerTokenModifier('static', "Style to use for symbols that are static.");
        registry.registerTokenModifier('abstract', "Style to use for symbols that are abstract.");
        registry.registerTokenModifier('deprecated', "Style to use for symbols that are deprecated.");
        registry.registerTokenModifier('modification', "Style to use for write accesses.");
        registry.registerTokenModifier('async', "Style to use for symbols that are async.");
        registry.registerTokenModifier('readonly', "Style to use for symbols that are read-only.");

        registerTokenStyleDefault('variable.readonly', [['variable.other.constant']]);
        registerTokenStyleDefault('property.readonly', [['variable.other.constant.property']]);
        registerTokenStyleDefault('type.defaultLibrary', [['support.type']]);
        registerTokenStyleDefault('class.defaultLibrary', [['support.class']]);
        registerTokenStyleDefault('interface.defaultLibrary', [['support.class']]);
        registerTokenStyleDefault('variable.defaultLibrary', [['support.variable'], ['support.other.variable']]);
        registerTokenStyleDefault('variable.defaultLibrary.readonly', [['support.constant']]);
        registerTokenStyleDefault('property.defaultLibrary', [['support.variable.property']]);
        registerTokenStyleDefault('property.defaultLibrary.readonly', [['support.constant.property']]);
        registerTokenStyleDefault('function.defaultLibrary', [['support.function']]);
        registerTokenStyleDefault('member.defaultLibrary', [['support.function']]);
        return registry;
    }

}
