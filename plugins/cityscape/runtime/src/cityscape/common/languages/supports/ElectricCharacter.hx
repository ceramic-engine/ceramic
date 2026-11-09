// Ported from vscode src/vs/editor/common/languages/supports/electricCharacter.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages.supports;

import cityscape.base.common.Strings;
import cityscape.common.languages.Supports;
import cityscape.common.languages.supports.RichEditBrackets;

/**
 * Interface used to support electric characters
 * @internal
 */
typedef IElectricAction = {
    // The line will be indented at the same level of the line
    // which contains the matching given bracket type.
    final matchOpenBracket:String;
}

class BracketElectricCharacterSupport {

    final _richEditBrackets:Null<RichEditBrackets>;

    public function new(richEditBrackets:Null<RichEditBrackets>) {
        _richEditBrackets = richEditBrackets;
    }

    public function getElectricCharacters():Array<String> {
        final result:Array<String> = [];

        if (_richEditBrackets != null) {
            for (bracket in _richEditBrackets.brackets) {
                for (close in bracket.close) {
                    final lastChar = close.charAt(close.length - 1);
                    result.push(lastChar);
                }
            }
        }

        // distinct
        final seen = new Map<String, Bool>();
        final distinct:Array<String> = [];
        for (c in result) {
            if (!seen.exists(c)) {
                seen.set(c, true);
                distinct.push(c);
            }
        }
        return distinct;
    }

    public function onElectricCharacter(character:String, context:ScopedLineTokens, column:Int):Null<IElectricAction> {
        if (_richEditBrackets == null || _richEditBrackets.brackets.length == 0) {
            return null;
        }

        final tokenIndex = context.findTokenIndexAtOffset(column - 1);
        if (Supports.ignoreBracketsInToken(context.getStandardTokenType(tokenIndex))) {
            return null;
        }

        final reversedBracketRegex = _richEditBrackets.reversedRegex;
        final text = context.getLineContent().substring(0, column - 1) + character;

        final r = BracketsUtils.findPrevBracketInRange(reversedBracketRegex, 1, text, 0, text.length);
        if (r == null) {
            return null;
        }

        final bracketText = text.substring(r.startColumn - 1, r.endColumn - 1).toLowerCase();

        final isOpen = _richEditBrackets.textIsOpenBracket.get(bracketText);
        if (isOpen == true) {
            return null;
        }

        final textBeforeBracket = context.getActualLineContentBefore(r.startColumn - 1);
        if (!isWhitespaceOnly(textBeforeBracket)) {
            // There is other text on the line before the bracket
            return null;
        }

        return {
            matchOpenBracket: bracketText
        };
    }

    /**
     * `/^\s*$/.test(text)`.
     */
    static function isWhitespaceOnly(text:String):Bool {
        for (i in 0...text.length) {
            if (!Strings.isJsWhitespace(StringTools.fastCodeAt(text, i))) {
                return false;
            }
        }
        return true;
    }

}
