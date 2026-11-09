// Ported from vscode src/vs/editor/common/tokens/contiguousTokensEditing.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.tokens;

import haxe.io.UInt32Array;

/**
 * Edits the binary tokens of a line (`[endOffset, metadata]*`).
 *
 * Monaco stores a line's tokens as a `Uint32Array` or its `ArrayBuffer` (to
 * save an object); Cityscape always stores the `UInt32Array`.
 * `EMPTY_LINE_TOKENS` is a shared empty array, compared by identity.
 */
class ContiguousTokensEditing {

    public static final EMPTY_LINE_TOKENS:UInt32Array = new UInt32Array(0);

    public static function deleteBeginning(lineTokens:Null<UInt32Array>, toChIndex:Int):Null<UInt32Array> {
        if (lineTokens == null || lineTokens == EMPTY_LINE_TOKENS) {
            return lineTokens;
        }
        return delete(lineTokens, 0, toChIndex);
    }

    public static function deleteEnding(lineTokens:Null<UInt32Array>, fromChIndex:Int):Null<UInt32Array> {
        if (lineTokens == null || lineTokens == EMPTY_LINE_TOKENS) {
            return lineTokens;
        }

        final tokens = lineTokens;
        final lineTextLength:Int = tokens[tokens.length - 2];
        return delete(lineTokens, fromChIndex, lineTextLength);
    }

    public static function delete(lineTokens:Null<UInt32Array>, fromChIndex:Int, toChIndex:Int):Null<UInt32Array> {
        if (lineTokens == null || lineTokens == EMPTY_LINE_TOKENS || fromChIndex == toChIndex) {
            return lineTokens;
        }

        final tokens = lineTokens;
        final tokensCount = (tokens.length >>> 1);

        // special case: deleting everything
        if (fromChIndex == 0 && (tokens[tokens.length - 2] : Int) == toChIndex) {
            return EMPTY_LINE_TOKENS;
        }

        final fromTokenIndex = LineTokens.findIndexInTokensArray(tokens, fromChIndex);
        final fromTokenStartOffset:Int = (fromTokenIndex > 0 ? tokens[(fromTokenIndex - 1) << 1] : 0);
        final fromTokenEndOffset:Int = tokens[fromTokenIndex << 1];

        if (toChIndex < fromTokenEndOffset) {
            // the delete range is inside a single token
            final delta = (toChIndex - fromChIndex);
            for (i in fromTokenIndex...tokensCount) {
                tokens[i << 1] = (tokens[i << 1] : Int) - delta;
            }
            return lineTokens;
        }

        var dest:Int;
        var lastEnd:Int;
        if (fromTokenStartOffset != fromChIndex) {
            tokens[fromTokenIndex << 1] = fromChIndex;
            dest = ((fromTokenIndex + 1) << 1);
            lastEnd = fromChIndex;
        }
        else {
            dest = (fromTokenIndex << 1);
            lastEnd = fromTokenStartOffset;
        }

        final delta = (toChIndex - fromChIndex);
        for (tokenIndex in (fromTokenIndex + 1)...tokensCount) {
            final tokenEndOffset:Int = (tokens[tokenIndex << 1] : Int) - delta;
            if (tokenEndOffset > lastEnd) {
                tokens[dest++] = tokenEndOffset;
                tokens[dest++] = tokens[(tokenIndex << 1) + 1];
                lastEnd = tokenEndOffset;
            }
        }

        if (dest == tokens.length) {
            // nothing to trim
            return lineTokens;
        }

        final tmp = new UInt32Array(dest);
        for (i in 0...dest) {
            tmp[i] = tokens[i];
        }
        return tmp;
    }

    public static function append(lineTokens:Null<UInt32Array>, _otherTokens:Null<UInt32Array>):Null<UInt32Array> {
        if (_otherTokens == EMPTY_LINE_TOKENS) {
            return lineTokens;
        }
        if (lineTokens == EMPTY_LINE_TOKENS) {
            return _otherTokens;
        }
        if (lineTokens == null) {
            return lineTokens;
        }
        if (_otherTokens == null) {
            // cannot determine combined line length...
            return null;
        }
        final myTokens = lineTokens;
        final otherTokens = _otherTokens;
        final otherTokensCount = (otherTokens.length >>> 1);

        final result = new UInt32Array(myTokens.length + otherTokens.length);
        for (i in 0...myTokens.length) {
            result[i] = myTokens[i];
        }
        var dest = myTokens.length;
        final delta:Int = myTokens[myTokens.length - 2];
        for (i in 0...otherTokensCount) {
            result[dest++] = (otherTokens[(i << 1)] : Int) + delta;
            result[dest++] = otherTokens[(i << 1) + 1];
        }
        return result;
    }

    public static function insert(lineTokens:Null<UInt32Array>, chIndex:Int, textLength:Int):Null<UInt32Array> {
        if (lineTokens == null || lineTokens == EMPTY_LINE_TOKENS) {
            // nothing to do
            return lineTokens;
        }

        final tokens = lineTokens;
        final tokensCount = (tokens.length >>> 1);

        var fromTokenIndex = LineTokens.findIndexInTokensArray(tokens, chIndex);
        if (fromTokenIndex > 0) {
            final fromTokenStartOffset:Int = tokens[(fromTokenIndex - 1) << 1];
            if (fromTokenStartOffset == chIndex) {
                fromTokenIndex--;
            }
        }
        for (tokenIndex in fromTokenIndex...tokensCount) {
            tokens[tokenIndex << 1] = (tokens[tokenIndex << 1] : Int) + textLength;
        }
        return lineTokens;
    }

}
