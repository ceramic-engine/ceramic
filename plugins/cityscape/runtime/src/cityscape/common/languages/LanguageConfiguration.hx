// Ported from vscode src/vs/editor/common/languages/languageConfiguration.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

import cityscape.base.common.CharCode;
import cityscape.base.common.RegExp;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.languages.Supports.ScopedLineTokens;

/**
 * Describes how comments for a language work.
 */
typedef CommentRule = {
    /**
     * The line comment token, like `// this is a comment`
     */
    @:optional var lineComment:Null<String>;
    /**
     * The block comment character pair, like `/* block comment *&#47;`
     */
    @:optional var blockComment:Null<CharacterPair>;
}

/**
 * The language configuration interface defines the contract between extensions and
 * various editor features, like automatic bracket insertion, automatic indentation etc.
 */
typedef LanguageConfiguration = {
    /**
     * The language's comment settings.
     */
    @:optional var comments:CommentRule;
    /**
     * The language's brackets.
     * This configuration implicitly affects pressing Enter around these brackets.
     */
    @:optional var brackets:Array<CharacterPair>;
    /**
     * The language's word definition.
     * If the language supports Unicode identifiers (e.g. JavaScript), it is preferable
     * to provide a word definition that uses exclusion of known separators.
     */
    @:optional var wordPattern:RegExp;
    /**
     * The language's indentation settings.
     */
    @:optional var indentationRules:IndentationRule;
    /**
     * The language's rules to be evaluated when pressing Enter.
     */
    @:optional var onEnterRules:Array<OnEnterRule>;
    /**
     * The language's auto closing pairs. The 'close' character is automatically inserted with the
     * 'open' character is typed. If not set, the configured brackets will be used.
     */
    @:optional var autoClosingPairs:Array<IAutoClosingPairConditional>;
    /**
     * The language's surrounding pairs. When the 'open' character is typed on a selection, the
     * selected string is surrounded by the open and close characters. If not set, the autoclosing pairs
     * settings will be used.
     */
    @:optional var surroundingPairs:Array<IAutoClosingPair>;
    /**
     * Defines a list of bracket pairs that are colorized depending on their nesting level.
     * If not set, the configured brackets will be used.
     */
    @:optional var colorizedBracketPairs:Array<CharacterPair>;
    /**
     * Defines what characters must be after the cursor for bracket or quote autoclosing to occur when using the \'languageDefined\' autoclosing setting.
     *
     * This is typically the set of characters which can not start an expression, such as whitespace, closing brackets, non-unary operators, etc.
     */
    @:optional var autoCloseBefore:String;
    /**
     * The language's folding rules.
     */
    @:optional var folding:FoldingRules;
    /**
     * **Deprecated** Do not use.
     *
     * @deprecated Will be replaced by a better API soon.
     */
    @:optional var __electricCharacterSupport:{
        @:optional var docComment:IDocComment;
    };
}

/**
 * Describes indentation rules for a language.
 */
typedef IndentationRule = {
    /**
     * If a line matches this pattern, then all the lines after it should be unindented once (until another rule matches).
     */
    var decreaseIndentPattern:RegExp;
    /**
     * If a line matches this pattern, then all the lines after it should be indented once (until another rule matches).
     */
    var increaseIndentPattern:RegExp;
    /**
     * If a line matches this pattern, then **only the next line** after it should be indented once.
     */
    @:optional var indentNextLinePattern:Null<RegExp>;
    /**
     * If a line matches this pattern, then its indentation should not be changed and it should not be evaluated against the other rules.
     */
    @:optional var unIndentedLinePattern:Null<RegExp>;
}

/**
 * Describes language specific folding markers such as '#region' and '#endregion'.
 * The start and end regexes will be tested against the contents of all lines and must be designed efficiently:
 * - the regex should start with '^'
 * - regexp flags (i, g) are ignored
 */
typedef FoldingMarkers = {
    var start:RegExp;
    var end:RegExp;
}

/**
 * Describes folding rules for a language.
 */
typedef FoldingRules = {
    /**
     * Used by the indentation based strategy to decide whether empty lines belong to the previous or the next block.
     * A language adheres to the off-side rule if blocks in that language are expressed by their indentation.
     * If not set, `false` is used and empty lines belong to the previous block.
     */
    @:optional var offSide:Bool;
    /**
     * Region markers used by the language.
     */
    @:optional var markers:FoldingMarkers;
}

/**
 * Describes a rule to be evaluated when pressing Enter.
 */
typedef OnEnterRule = {
    /**
     * This rule will only execute if the text before the cursor matches this regular expression.
     */
    var beforeText:RegExp;
    /**
     * This rule will only execute if the text after the cursor matches this regular expression.
     */
    @:optional var afterText:RegExp;
    /**
     * This rule will only execute if the text above the this line matches this regular expression.
     */
    @:optional var previousLineText:RegExp;
    /**
     * The action to execute.
     */
    var action:EnterAction;
}

/**
 * Definition of documentation comments (e.g. Javadoc/JSdoc)
 */
typedef IDocComment = {
    /**
     * The string that starts a doc comment (e.g. '/**')
     */
    var open:String;
    /**
     * The string that appears on the last line and closes the doc comment (e.g. ' * /').
     */
    @:optional var close:String;
}

/**
 * A tuple of two characters, like a pair of
 * opening and closing brackets (an array of two strings).
 */
typedef CharacterPair = Array<String>;

typedef IAutoClosingPair = {
    final open:String;
    final close:String;
}

typedef IAutoClosingPairConditional = {
    > IAutoClosingPair,
    @:optional final notIn:Array<String>;
}

/**
 * Describes what to do with the indentation when pressing Enter.
 */
enum abstract IndentAction(Int) from Int to Int {
    /**
     * Insert new line and copy the previous line's indentation.
     */
    var None = 0;
    /**
     * Insert new line and indent once (relative to the previous line's indentation).
     */
    var Indent = 1;
    /**
     * Insert two new lines:
     *  - the first one indented which will hold the cursor
     *  - the second one at the same indentation level
     */
    var IndentOutdent = 2;
    /**
     * Insert new line and outdent once (relative to the previous line's indentation).
     */
    var Outdent = 3;
}

/**
 * Describes what to do when pressing Enter.
 */
typedef EnterAction = {
    /**
     * Describe what to do with the indentation.
     */
    var indentAction:IndentAction;
    /**
     * Describes text to be appended after the new line and after the indentation.
     */
    @:optional var appendText:String;
    /**
     * Describes the number of characters to remove from the new line's indentation.
     */
    @:optional var removeText:Null<Int>;
}

/**
 * @internal
 */
typedef CompleteEnterAction = {
    /**
     * Describe what to do with the indentation.
     */
    var indentAction:IndentAction;
    /**
     * Describes text to be appended after the new line and after the indentation.
     */
    var appendText:String;
    /**
     * Describes the number of characters to remove from the new line's indentation.
     */
    var removeText:Int;
    /**
     * The line's indentation minus removeText
     */
    var indentation:String;
}

/**
 * @internal
 */
class StandardAutoClosingPairConditional {

    public final open:String;
    public final close:String;
    final _inString:Bool;
    final _inComment:Bool;
    final _inRegEx:Bool;
    var _neutralCharacter:Null<String> = null;
    var _neutralCharacterSearched:Bool = false;

    public function new(source:IAutoClosingPairConditional) {
        this.open = source.open;
        this.close = source.close;

        // initially allowed in all tokens
        var inString = true;
        var inComment = true;
        var inRegEx = true;

        final notIn = source.notIn;
        if (notIn != null) {
            for (i in 0...notIn.length) {
                switch (notIn[i]) {
                    case 'string':
                        inString = false;
                    case 'comment':
                        inComment = false;
                    case 'regex':
                        inRegEx = false;
                    case _:
                }
            }
        }

        _inString = inString;
        _inComment = inComment;
        _inRegEx = inRegEx;
    }

    public function isOK(standardToken:StandardTokenType):Bool {
        return switch (standardToken) {
            case StandardTokenType.Other: true;
            case StandardTokenType.Comment: _inComment;
            case StandardTokenType.String: _inString;
            case StandardTokenType.RegEx: _inRegEx;
            case _: false;
        }
    }

    public function shouldAutoClose(context:ScopedLineTokens, column:Int):Bool {
        // Always complete on empty line
        if (context.getTokenCount() == 0) {
            return true;
        }

        final tokenIndex = context.findTokenIndexAtOffset(column - 2);
        final standardTokenType = context.getStandardTokenType(tokenIndex);
        return isOK(standardTokenType);
    }

    function _findNeutralCharacterInRange(fromCharCode:Int, toCharCode:Int):Null<String> {
        for (charCode in fromCharCode...toCharCode + 1) {
            final character = std.String.fromCharCode(charCode);
            if (open.indexOf(character) == -1 && close.indexOf(character) == -1) {
                return character;
            }
        }
        return null;
    }

    /**
     * Find a character in the range [0-9a-zA-Z] that does not appear in the open or close
     */
    public function findNeutralCharacter():Null<String> {
        if (!_neutralCharacterSearched) {
            _neutralCharacterSearched = true;
            if (_neutralCharacter == null) {
                _neutralCharacter = _findNeutralCharacterInRange(CharCode.Digit0, CharCode.Digit9);
            }
            if (_neutralCharacter == null) {
                _neutralCharacter = _findNeutralCharacterInRange(CharCode.a, CharCode.z);
            }
            if (_neutralCharacter == null) {
                _neutralCharacter = _findNeutralCharacterInRange(CharCode.A, CharCode.Z);
            }
        }
        return _neutralCharacter;
    }

}

/**
 * @internal
 */
class AutoClosingPairs {
    // it is useful to be able to get pairs using either end of open and close

    /** Key is first character of open */
    public final autoClosingPairsOpenByStart:Map<String, Array<StandardAutoClosingPairConditional>>;
    /** Key is last character of open */
    public final autoClosingPairsOpenByEnd:Map<String, Array<StandardAutoClosingPairConditional>>;
    /** Key is first character of close */
    public final autoClosingPairsCloseByStart:Map<String, Array<StandardAutoClosingPairConditional>>;
    /** Key is last character of close */
    public final autoClosingPairsCloseByEnd:Map<String, Array<StandardAutoClosingPairConditional>>;
    /** Key is close. Only has pairs that are a single character */
    public final autoClosingPairsCloseSingleChar:Map<String, Array<StandardAutoClosingPairConditional>>;

    public function new(autoClosingPairs:Array<StandardAutoClosingPairConditional>) {
        autoClosingPairsOpenByStart = new Map();
        autoClosingPairsOpenByEnd = new Map();
        autoClosingPairsCloseByStart = new Map();
        autoClosingPairsCloseByEnd = new Map();
        autoClosingPairsCloseSingleChar = new Map();
        for (pair in autoClosingPairs) {
            appendEntry(autoClosingPairsOpenByStart, pair.open.charAt(0), pair);
            appendEntry(autoClosingPairsOpenByEnd, pair.open.charAt(pair.open.length - 1), pair);
            appendEntry(autoClosingPairsCloseByStart, pair.close.charAt(0), pair);
            appendEntry(autoClosingPairsCloseByEnd, pair.close.charAt(pair.close.length - 1), pair);
            if (pair.close.length == 1 && pair.open.length == 1) {
                appendEntry(autoClosingPairsCloseSingleChar, pair.close, pair);
            }
        }
    }

    static function appendEntry<V>(target:Map<String, Array<V>>, key:String, value:V):Void {
        final entry = target.get(key);
        if (entry != null) {
            entry.push(value);
        }
        else {
            target.set(key, [value]);
        }
    }

}
