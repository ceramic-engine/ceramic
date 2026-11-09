// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/bracketPairsTree/brackets.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree;

import cityscape.base.common.RegExp;
import cityscape.base.common.Strings;
import cityscape.common.languages.LanguageConfigurationRegistry.ResolvedLanguageConfiguration;
import cityscape.common.languages.supports.LanguageBracketsConfiguration;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Ast;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.SmallImmutableSet;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Tokenizer;

class BracketTokens {

    public static function createFromLanguage(configuration:ResolvedLanguageConfiguration, denseKeyProvider:DenseKeyProvider<String>):BracketTokens {
        function getId(bracketInfo:BracketKind):OpeningBracketId {
            return denseKeyProvider.getKey(bracketInfo.languageId + ':::' + bracketInfo.bracketText);
        }

        final map = new Map<String, Token>();
        final keys:Array<String> = [];
        final set = (key:String, token:Token) -> {
            if (!map.exists(key)) {
                keys.push(key);
            }
            map.set(key, token);
        };
        for (openingBracket in configuration.bracketsNew.openingBrackets) {
            final length = Length.toLength(0, openingBracket.bracketText.length);
            final openingTextId = getId(openingBracket);
            final bracketIds = SmallImmutableSet.getEmpty().add(openingTextId, IdentityKeyProvider.INSTANCE);
            set(openingBracket.bracketText, new Token(
                length,
                TokenKind.OpeningBracket,
                openingTextId,
                bracketIds,
                BracketAstNode.create(length, openingBracket, bracketIds)
            ));
        }

        for (closingBracket in configuration.bracketsNew.closingBrackets) {
            final length = Length.toLength(0, closingBracket.bracketText.length);
            var bracketIds = SmallImmutableSet.getEmpty();
            final closingBrackets = closingBracket.getOpeningBrackets();
            for (bracket in closingBrackets) {
                bracketIds = bracketIds.add(getId(bracket), IdentityKeyProvider.INSTANCE);
            }
            set(closingBracket.bracketText, new Token(
                length,
                TokenKind.ClosingBracket,
                getId(closingBrackets[0]),
                bracketIds,
                BracketAstNode.create(length, closingBracket, bracketIds)
            ));
        }

        return new BracketTokens(map, keys);
    }

    var hasRegExp = false;
    var _regExpGlobal:Null<RegExp> = null;

    final map:Map<String, Token>;

    /**
     * The keys of `map` in insertion order (Monaco's `Map` keeps it).
     */
    final keys:Array<String>;

    public function new(map:Map<String, Token>, keys:Array<String>) {
        this.map = map;
        this.keys = keys;
    }

    public function getRegExpStr():Null<String> {
        if (isEmpty) {
            return null;
        }
        else {
            final keys = this.keys.copy();
            haxe.ds.ArraySort.sort(keys, compareStrings);
            keys.reverse();
            return [for (k in keys) prepareBracketForRegExp(k)].join('|');
        }
    }

    /**
     * Returns null if there is no such regexp (because there are no brackets).
     */
    public var regExpGlobal(get, never):Null<RegExp>;
    function get_regExpGlobal():Null<RegExp> {
        if (!hasRegExp) {
            final regExpStr = getRegExpStr();
            _regExpGlobal = (regExpStr != null && regExpStr.length > 0) ? new RegExp(regExpStr, 'gi') : null;
            hasRegExp = true;
        }
        return _regExpGlobal;
    }

    public function getToken(value:String):Null<Token> {
        return map.get(value.toLowerCase());
    }

    public function findClosingTokenText(openingBracketIds:SmallImmutableSet<OpeningBracketId>):Null<String> {
        for (closingText in keys) {
            final info = map.get(closingText);
            if (info.kind == TokenKind.ClosingBracket && info.bracketIds.intersects(openingBracketIds)) {
                return closingText;
            }
        }
        return null;
    }

    public var isEmpty(get, never):Bool;
    function get_isEmpty():Bool {
        return keys.length == 0;
    }

    /**
     * JavaScript's default `sort` order: UTF-16 code units.
     */
    static function compareStrings(a:String, b:String):Int {
        final len = a.length < b.length ? a.length : b.length;
        for (i in 0...len) {
            final ca = StringTools.fastCodeAt(a, i);
            final cb = StringTools.fastCodeAt(b, i);
            if (ca != cb) {
                return ca - cb;
            }
        }
        return a.length - b.length;
    }

    static function prepareBracketForRegExp(str:String):String {
        var escaped = Strings.escapeRegExpCharacters(str);
        // These bracket pair delimiters start or end with letters
        // see https://github.com/microsoft/vscode/issues/132162 https://github.com/microsoft/vscode/issues/150440
        if (str.length > 0 && isWordOrSpace(StringTools.fastCodeAt(str, 0))) {
            escaped = '\\b' + escaped;
        }
        if (str.length > 0 && isWordOrSpace(StringTools.fastCodeAt(str, str.length - 1))) {
            escaped = escaped + '\\b';
        }
        return escaped;
    }

    /**
     * `[\w ]`.
     */
    static inline function isWordOrSpace(c:Int):Bool {
        return c == ' '.code || RegExp.isAsciiWordChar(c);
    }

}

class LanguageAgnosticBracketTokens {

    final languageIdToBracketTokens = new Map<String, BracketTokens>();

    final denseKeyProvider:DenseKeyProvider<String>;
    final getLanguageConfiguration:(languageId:String) -> ResolvedLanguageConfiguration;

    public function new(
        denseKeyProvider:DenseKeyProvider<String>,
        getLanguageConfiguration:(languageId:String) -> ResolvedLanguageConfiguration
    ) {
        this.denseKeyProvider = denseKeyProvider;
        this.getLanguageConfiguration = getLanguageConfiguration;
    }

    public function didLanguageChange(languageId:String):Bool {
        // Report a change whenever the language configuration updates.
        return languageIdToBracketTokens.exists(languageId);
    }

    public function getSingleLanguageBracketTokens(languageId:String):BracketTokens {
        var singleLanguageBracketTokens = languageIdToBracketTokens.get(languageId);
        if (singleLanguageBracketTokens == null) {
            singleLanguageBracketTokens = BracketTokens.createFromLanguage(getLanguageConfiguration(languageId), denseKeyProvider);
            languageIdToBracketTokens.set(languageId, singleLanguageBracketTokens);
        }
        return singleLanguageBracketTokens;
    }

    public function getToken(value:String, languageId:String):Null<Token> {
        final singleLanguageBracketTokens = getSingleLanguageBracketTokens(languageId);
        return singleLanguageBracketTokens.getToken(value);
    }

}
