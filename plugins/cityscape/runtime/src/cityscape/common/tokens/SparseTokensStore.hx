// Ported from vscode src/vs/editor/common/tokens/sparseTokensStore.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.tokens;

import cityscape.base.common.Arrays;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages.ILanguageIdCodec;
import cityscape.common.core.Range;
import haxe.io.UInt32Array;

/**
 * Represents sparse tokens in a text model.
 */
class SparseTokensStore {

    var _pieces:Array<SparseMultilineTokens>;

    var _isComplete:Bool;

    final _languageIdCodec:ILanguageIdCodec;

    public function new(languageIdCodec:ILanguageIdCodec) {
        _pieces = [];
        _isComplete = false;
        _languageIdCodec = languageIdCodec;
    }

    public function flush():Void {
        _pieces = [];
        _isComplete = false;
    }

    public function isEmpty():Bool {
        return (_pieces.length == 0);
    }

    public function set(pieces:Null<Array<SparseMultilineTokens>>, isComplete:Bool):Void {
        _pieces = pieces != null ? pieces : [];
        _isComplete = isComplete;
    }

    public function setPartial(_range:Range, pieces:Array<SparseMultilineTokens>):Range {

        var range = _range;
        if (pieces.length > 0) {
            final _firstRange = pieces[0].getRange();
            final _lastRange = pieces[pieces.length - 1].getRange();
            if (_firstRange == null || _lastRange == null) {
                return _range;
            }
            range = _range.plusRange(_firstRange).plusRange(_lastRange);
        }

        // Monaco's `insertPosition: { index: number } | null`: -1 is null.
        var insertPosition = -1;
        var i = 0;
        var len = _pieces.length;
        while (i < len) {
            final piece = _pieces[i];
            if (piece.endLineNumber < range.startLineNumber) {
                // this piece is before the range
                i++;
                continue;
            }

            if (piece.startLineNumber > range.endLineNumber) {
                // this piece is after the range, so mark the spot before this piece
                // as a good insertion position and stop looping
                if (insertPosition == -1) {
                    insertPosition = i;
                }
                break;
            }

            // this piece might intersect with the range
            piece.removeTokens(range);

            if (piece.isEmpty()) {
                // remove the piece if it became empty
                _pieces.splice(i, 1);
                len--;
                continue;
            }

            if (piece.endLineNumber < range.startLineNumber) {
                // after removal, this piece is before the range
                i++;
                continue;
            }

            if (piece.startLineNumber > range.endLineNumber) {
                // after removal, this piece is after the range
                if (insertPosition == -1) {
                    insertPosition = i;
                }
                i++;
                continue;
            }

            // after removal, this piece contains the range
            final split = piece.split(range);
            final a = split.a;
            final b = split.b;
            if (a.isEmpty()) {
                // this piece is actually after the range
                if (insertPosition == -1) {
                    insertPosition = i;
                }
                i++;
                continue;
            }
            if (b.isEmpty()) {
                // this piece is actually before the range
                i++;
                continue;
            }
            _pieces.splice(i, 1);
            _pieces.insert(i, b);
            _pieces.insert(i, a);
            i++;
            len++;

            if (insertPosition == -1) {
                insertPosition = i;
            }
            i++;
        }

        if (insertPosition == -1) {
            insertPosition = _pieces.length;
        }

        if (pieces.length > 0) {
            _pieces = Arrays.arrayInsert(_pieces, insertPosition, pieces);
        }

        return range;
    }

    public function isComplete():Bool {
        return _isComplete;
    }

    public function addSparseTokens(lineNumber:Int, aTokens:LineTokens):LineTokens {
        if (aTokens.getLineContent().length == 0) {
            // Don't do anything for empty lines
            return aTokens;
        }

        final pieces = _pieces;

        if (pieces.length == 0) {
            return aTokens;
        }

        final pieceIndex = SparseTokensStore._findFirstPieceWithLine(pieces, lineNumber);
        final bTokens = pieces[pieceIndex].getLineTokens(lineNumber);

        if (bTokens == null) {
            return aTokens;
        }

        final aLen = aTokens.getCount();
        final bLen = bTokens.getCount();

        var aIndex = 0;
        final result:Array<Int> = [];
        var resultLen = 0;
        var lastEndOffset = 0;

        inline function emitToken(endOffset:Int, metadata:Int):Void {
            if (endOffset != lastEndOffset) {
                lastEndOffset = endOffset;
                result[resultLen++] = endOffset;
                result[resultLen++] = metadata;
            }
        }

        for (bIndex in 0...bLen) {
            final bStartCharacter = bTokens.getStartCharacter(bIndex);
            final bEndCharacter = bTokens.getEndCharacter(bIndex);
            final bMetadata = bTokens.getMetadata(bIndex);

            final bMask:Int = (
                ((bMetadata & MetadataConsts.SEMANTIC_USE_ITALIC) != 0 ? MetadataConsts.ITALIC_MASK : 0)
                | ((bMetadata & MetadataConsts.SEMANTIC_USE_BOLD) != 0 ? MetadataConsts.BOLD_MASK : 0)
                | ((bMetadata & MetadataConsts.SEMANTIC_USE_UNDERLINE) != 0 ? MetadataConsts.UNDERLINE_MASK : 0)
                | ((bMetadata & MetadataConsts.SEMANTIC_USE_STRIKETHROUGH) != 0 ? MetadataConsts.STRIKETHROUGH_MASK : 0)
                | ((bMetadata & MetadataConsts.SEMANTIC_USE_FOREGROUND) != 0 ? MetadataConsts.FOREGROUND_MASK : 0)
                | ((bMetadata & MetadataConsts.SEMANTIC_USE_BACKGROUND) != 0 ? MetadataConsts.BACKGROUND_MASK : 0)
            );
            final aMask:Int = ~bMask;

            // push any token from `a` that is before `b`
            while (aIndex < aLen && aTokens.getEndOffset(aIndex) <= bStartCharacter) {
                emitToken(aTokens.getEndOffset(aIndex), aTokens.getMetadata(aIndex));
                aIndex++;
            }

            // push the token from `a` if it intersects the token from `b`
            if (aIndex < aLen && aTokens.getStartOffset(aIndex) < bStartCharacter) {
                emitToken(bStartCharacter, aTokens.getMetadata(aIndex));
            }

            // skip any tokens from `a` that are contained inside `b`
            while (aIndex < aLen && aTokens.getEndOffset(aIndex) < bEndCharacter) {
                emitToken(aTokens.getEndOffset(aIndex), (aTokens.getMetadata(aIndex) & aMask) | (bMetadata & bMask));
                aIndex++;
            }

            if (aIndex < aLen) {
                emitToken(bEndCharacter, (aTokens.getMetadata(aIndex) & aMask) | (bMetadata & bMask));
                if (aTokens.getEndOffset(aIndex) == bEndCharacter) {
                    // `a` ends exactly at the same spot as `b`!
                    aIndex++;
                }
            }
            else {
                final aMergeIndex = Std.int(Math.min(Math.max(0, aIndex - 1), aLen - 1));

                // push the token from `b`
                emitToken(bEndCharacter, (aTokens.getMetadata(aMergeIndex) & aMask) | (bMetadata & bMask));
            }
        }

        // push the remaining tokens from `a`
        while (aIndex < aLen) {
            emitToken(aTokens.getEndOffset(aIndex), aTokens.getMetadata(aIndex));
            aIndex++;
        }

        return new LineTokens(UInt32Array.fromArray(result), aTokens.getLineContent(), _languageIdCodec);
    }

    static function _findFirstPieceWithLine(pieces:Array<SparseMultilineTokens>, lineNumber:Int):Int {
        var low = 0;
        var high = pieces.length - 1;

        while (low < high) {
            var mid = low + Std.int((high - low) / 2);

            if (pieces[mid].endLineNumber < lineNumber) {
                low = mid + 1;
            }
            else if (pieces[mid].startLineNumber > lineNumber) {
                high = mid - 1;
            }
            else {
                while (mid > low && pieces[mid - 1].startLineNumber <= lineNumber && lineNumber <= pieces[mid - 1].endLineNumber) {
                    mid--;
                }
                return mid;
            }
        }

        return low;
    }

    public function acceptEdit(range:IRange, eolCount:Int, firstLineLength:Int, lastLineLength:Int, firstCharCode:Int):Void {
        for (piece in _pieces) {
            piece.acceptEdit(range, eolCount, firstLineLength, lastLineLength, firstCharCode);
        }
    }

}
