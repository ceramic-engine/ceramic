// Ported from vscode src/vs/editor/common/languages/supports/languageBracketsConfiguration.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages.supports;

import cityscape.base.common.RegExp;
import cityscape.base.common.Strings.RegExpOptions;
import cityscape.common.languages.LanguageConfiguration;
import cityscape.common.languages.supports.RichEditBrackets;

/**
 * Captures all bracket related configurations for a single language.
 * Immutable.
 *
 * Monaco's maps and sets keep the insertion order: the brackets are kept in
 * arrays (in that order) next to the maps used for lookups.
 */
class LanguageBracketsConfiguration {

    final _openingBrackets:Map<String, OpeningBracketKind>;
    final _openingBracketsOrder:Array<OpeningBracketKind>;
    final _closingBrackets:Map<String, ClosingBracketKind>;
    final _closingBracketsOrder:Array<ClosingBracketKind>;

    public final languageId:String;

    public function new(languageId:String, config:LanguageConfiguration) {
        this.languageId = languageId;

        final bracketPairs = config.brackets != null ? filterValidBrackets(config.brackets) : [];

        // The `CachedFunction`s of Monaco
        final openingBrackets = new Map<String, OpeningBracketKind>();
        final openingBracketsOrder:Array<OpeningBracketKind> = [];
        final closingBrackets = new Map<String, ClosingBracketKind>();
        final closingBracketsOrder:Array<ClosingBracketKind> = [];
        final getOpening = (bracket:String) -> {
            var info = openingBrackets.get(bracket);
            if (info == null) {
                info = new OpeningBracketKind(this, bracket, []);
                openingBrackets.set(bracket, info);
                openingBracketsOrder.push(info);
            }
            return info;
        };
        final getClosing = (bracket:String) -> {
            var info = closingBrackets.get(bracket);
            if (info == null) {
                info = new ClosingBracketKind(this, bracket, [], []);
                closingBrackets.set(bracket, info);
                closingBracketsOrder.push(info);
            }
            return info;
        };

        for (pair in bracketPairs) {
            final opening = getOpening(pair[0]);
            final closing = getClosing(pair[1]);

            addToSet(opening.openedBrackets, closing);
            addToSet(closing.openingBrackets, opening);
        }

        // Treat colorized brackets as brackets, and mark them as colorized.
        final colorizedBracketPairs = config.colorizedBracketPairs != null
            ? filterValidBrackets(config.colorizedBracketPairs)
            // If not configured: Take all brackets except `<` ... `>`
            // Many languages set < ... > as bracket pair, even though they also use it as comparison operator.
            // This leads to problems when colorizing this bracket, so we exclude it if not explicitly configured otherwise.
            // https://github.com/microsoft/vscode/issues/132476
            : bracketPairs.filter((p) -> !(p[0] == '<' && p[1] == '>'));
        for (pair in colorizedBracketPairs) {
            final opening = getOpening(pair[0]);
            final closing = getClosing(pair[1]);

            addToSet(opening.openedBrackets, closing);
            addToSet(closing.openingColorizedBrackets, opening);
            addToSet(closing.openingBrackets, opening);
        }

        _openingBrackets = openingBrackets;
        _openingBracketsOrder = openingBracketsOrder;
        _closingBrackets = closingBrackets;
        _closingBracketsOrder = closingBracketsOrder;
    }

    static inline function addToSet<T>(set:Array<T>, value:T):Void {
        if (set.indexOf(value) == -1) {
            set.push(value);
        }
    }

    /**
     * No two brackets have the same bracket text.
     */
    public var openingBrackets(get, never):Array<OpeningBracketKind>;
    function get_openingBrackets():Array<OpeningBracketKind> {
        return _openingBracketsOrder.copy();
    }

    /**
     * No two brackets have the same bracket text.
     */
    public var closingBrackets(get, never):Array<ClosingBracketKind>;
    function get_closingBrackets():Array<ClosingBracketKind> {
        return _closingBracketsOrder.copy();
    }

    public function getOpeningBracketInfo(bracketText:String):Null<OpeningBracketKind> {
        return _openingBrackets.get(bracketText);
    }

    public function getClosingBracketInfo(bracketText:String):Null<ClosingBracketKind> {
        return _closingBrackets.get(bracketText);
    }

    public function getBracketInfo(bracketText:String):Null<BracketKind> {
        final opening = getOpeningBracketInfo(bracketText);
        if (opening != null) {
            return opening;
        }
        return getClosingBracketInfo(bracketText);
    }

    public function getBracketRegExp(?options:RegExpOptions):RegExp {
        final brackets:Array<String> = [];
        for (b in _openingBracketsOrder) {
            brackets.push(b.bracketText);
        }
        for (b in _closingBracketsOrder) {
            brackets.push(b.bracketText);
        }
        return RichEditBrackets.createBracketOrRegExp(brackets, options);
    }

    static function filterValidBrackets(bracketPairs:Array<CharacterPair>):Array<CharacterPair> {
        return bracketPairs.filter((pair) -> pair[0] != '' && pair[1] != '');
    }

}

/**
 * `OpeningBracketKind | ClosingBracketKind`: test `isOpeningBracket` and cast.
 */
typedef BracketKind = BracketKindBase;

class BracketKindBase {

    final config:LanguageBracketsConfiguration;

    public final bracketText:String;

    public final isOpeningBracket:Bool;

    function new(config:LanguageBracketsConfiguration, bracketText:String, isOpeningBracket:Bool) {
        this.config = config;
        this.bracketText = bracketText;
        this.isOpeningBracket = isOpeningBracket;
    }

    public var languageId(get, never):String;
    inline function get_languageId():String {
        return config.languageId;
    }

}

class OpeningBracketKind extends BracketKindBase {

    /**
     * Monaco's `ReadonlySet` (in insertion order).
     */
    public final openedBrackets:Array<ClosingBracketKind>;

    public function new(config:LanguageBracketsConfiguration, bracketText:String, openedBrackets:Array<ClosingBracketKind>) {
        super(config, bracketText, true);
        this.openedBrackets = openedBrackets;
    }

}

class ClosingBracketKind extends BracketKindBase {

    /**
     * Non empty array of all opening brackets this bracket closes.
     * Monaco's `ReadonlySet` (in insertion order).
     */
    public final openingBrackets:Array<OpeningBracketKind>;

    @:allow(cityscape.common.languages.supports.LanguageBracketsConfiguration)
    final openingColorizedBrackets:Array<OpeningBracketKind>;

    public function new(config:LanguageBracketsConfiguration, bracketText:String, openingBrackets:Array<OpeningBracketKind>, openingColorizedBrackets:Array<OpeningBracketKind>) {
        super(config, bracketText, false);
        this.openingBrackets = openingBrackets;
        this.openingColorizedBrackets = openingColorizedBrackets;
    }

    /**
     * Checks if this bracket closes the given other bracket.
     * If the bracket infos come from different configurations, this method will return false.
     */
    public function closes(other:OpeningBracketKind):Bool {
        if (other.config != this.config) {
            return false;
        }
        return openingBrackets.indexOf(other) != -1;
    }

    public function closesColorized(other:OpeningBracketKind):Bool {
        if (other.config != this.config) {
            return false;
        }
        return openingColorizedBrackets.indexOf(other) != -1;
    }

    public function getOpeningBrackets():Array<OpeningBracketKind> {
        return openingBrackets.copy();
    }

}
