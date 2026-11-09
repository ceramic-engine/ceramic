// Ported from vscode src/vs/editor/common/languages/supports/characterPair.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages.supports;

import cityscape.common.languages.LanguageConfiguration;

class CharacterPairSupport {

    public static inline final DEFAULT_AUTOCLOSE_BEFORE_LANGUAGE_DEFINED_QUOTES = ';:.,=}])> \n\t';
    public static inline final DEFAULT_AUTOCLOSE_BEFORE_LANGUAGE_DEFINED_BRACKETS = '\'"`;:.,=}])> \n\t';
    public static inline final DEFAULT_AUTOCLOSE_BEFORE_WHITESPACE = ' \n\t';

    final _autoClosingPairs:Array<StandardAutoClosingPairConditional>;
    final _surroundingPairs:Array<IAutoClosingPair>;
    final _autoCloseBeforeForQuotes:String;
    final _autoCloseBeforeForBrackets:String;

    public function new(config:LanguageConfiguration) {
        if (config.autoClosingPairs != null) {
            _autoClosingPairs = [for (el in config.autoClosingPairs) new StandardAutoClosingPairConditional(el)];
        }
        else if (config.brackets != null) {
            _autoClosingPairs = [for (b in config.brackets) new StandardAutoClosingPairConditional({open: b[0], close: b[1]})];
        }
        else {
            _autoClosingPairs = [];
        }

        if (config.__electricCharacterSupport != null && config.__electricCharacterSupport.docComment != null) {
            final docComment = config.__electricCharacterSupport.docComment;
            // IDocComment is legacy, only partially supported
            final close = docComment.close;
            _autoClosingPairs.push(new StandardAutoClosingPairConditional({open: docComment.open, close: (close != null && close.length > 0) ? close : ''}));
        }

        _autoCloseBeforeForQuotes = config.autoCloseBefore != null ? config.autoCloseBefore : CharacterPairSupport.DEFAULT_AUTOCLOSE_BEFORE_LANGUAGE_DEFINED_QUOTES;
        _autoCloseBeforeForBrackets = config.autoCloseBefore != null ? config.autoCloseBefore : CharacterPairSupport.DEFAULT_AUTOCLOSE_BEFORE_LANGUAGE_DEFINED_BRACKETS;

        // Monaco shares the array: the pairs are class instances that have `open` and `close`
        _surroundingPairs = config.surroundingPairs != null ? config.surroundingPairs : cast _autoClosingPairs;
    }

    public function getAutoClosingPairs():Array<StandardAutoClosingPairConditional> {
        return _autoClosingPairs;
    }

    public function getAutoCloseBeforeSet(forQuotes:Bool):String {
        return (forQuotes ? _autoCloseBeforeForQuotes : _autoCloseBeforeForBrackets);
    }

    public function getSurroundingPairs():Array<IAutoClosingPair> {
        return _surroundingPairs;
    }

}
