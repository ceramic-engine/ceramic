// Ported from vscode src/vs/editor/common/model/pieceTreeTextBuffer/pieceTreeBase.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.pieceTreeTextBuffer;

import cityscape.base.common.CharCode;
import cityscape.base.common.RegExp.RegExpExecArray;
import cityscape.base.common.Strings;
import cityscape.common.Model.FindMatch;
import cityscape.common.Model.ITextSnapshot;
import cityscape.common.Model.SearchData;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModelSearch;
import cityscape.common.model.pieceTreeTextBuffer.RbTreeBase;

class LineStarts {

    public final lineStarts:Array<Int>;

    public final cr:Int;

    public final lf:Int;

    public final crlf:Int;

    public final isBasicASCII:Bool;

    public function new(lineStarts:Array<Int>, cr:Int, lf:Int, crlf:Int, isBasicASCII:Bool) {
        this.lineStarts = lineStarts;
        this.cr = cr;
        this.lf = lf;
        this.crlf = crlf;
        this.isBasicASCII = isBasicASCII;
    }

}

class NodePosition {

    /**
     * Piece Index
     */
    public var node:TreeNode;

    /**
     * remainder in current piece.
     */
    public var remainder:Int;

    /**
     * node start offset in document.
     */
    public var nodeStartOffset:Int;

    public function new(node:TreeNode, remainder:Int, nodeStartOffset:Int) {
        this.node = node;
        this.remainder = remainder;
        this.nodeStartOffset = nodeStartOffset;
    }

}

class BufferCursor {

    /**
     * Line number in current buffer
     */
    public var line:Int;

    /**
     * Column number in current buffer
     */
    public var column:Int;

    public function new(line:Int, column:Int) {
        this.line = line;
        this.column = column;
    }

}

class Piece {

    public final bufferIndex:Int;

    public final start:BufferCursor;

    public final end:BufferCursor;

    public final length:Int;

    public final lineFeedCnt:Int;

    public function new(bufferIndex:Int, start:BufferCursor, end:BufferCursor, lineFeedCnt:Int, length:Int) {
        this.bufferIndex = bufferIndex;
        this.start = start;
        this.end = end;
        this.lineFeedCnt = lineFeedCnt;
        this.length = length;
    }

}

class StringBuffer {

    public var buffer:String;

    /**
     * Monaco uses typed arrays (`Uint16Array`/`Uint32Array`) for the read
     * only buffers and a plain array for the change buffer; `Array<Int>`
     * here (unboxed on hxcpp).
     */
    public var lineStarts:Null<Array<Int>>;

    public function new(buffer:String, lineStarts:Null<Array<Int>>) {
        this.buffer = buffer;
        this.lineStarts = lineStarts;
    }

}

/**
 * Readonly snapshot for piece tree.
 * In a real multiple thread environment, to make snapshot reading always work correctly, we need to
 * 1. Make TreeNode.piece immutable, then reading and writing can run in parallel.
 * 2. TreeNode/Buffers normalization should not happen during snapshot reading.
 */
class PieceTreeSnapshot implements ITextSnapshot {

    final _pieces:Array<Piece>;

    var _index:Int;

    final _tree:PieceTreeBase;

    final _BOM:String;

    public function new(tree:PieceTreeBase, BOM:String) {
        this._pieces = [];
        this._tree = tree;
        this._BOM = BOM;
        this._index = 0;
        if (tree.root != tree.SENTINEL) {
            tree.iterate(tree.root, node -> {
                if (node != tree.SENTINEL) {
                    this._pieces.push(node.piece);
                }
                return true;
            });
        }
    }

    public function read():Null<String> {
        if (this._pieces.length == 0) {
            if (this._index == 0) {
                this._index++;
                return this._BOM;
            }
            else {
                return null;
            }
        }

        if (this._index > this._pieces.length - 1) {
            return null;
        }

        if (this._index == 0) {
            return this._BOM + this._tree.getPieceContent(this._pieces[this._index++]);
        }
        return this._tree.getPieceContent(this._pieces[this._index++]);
    }

}

/**
 * An entry of the search cache. Monaco allocates one per cache update;
 * here the entries are reused (the cache holds one entry).
 */
class CacheEntry {

    public var node:TreeNode;

    public var nodeStartOffset:Int;

    /**
     * 0 when unknown (Monaco: `undefined`).
     */
    public var nodeStartLineNumber:Int;

    public function new(node:TreeNode, nodeStartOffset:Int, nodeStartLineNumber:Int) {
        this.node = node;
        this.nodeStartOffset = nodeStartOffset;
        this.nodeStartLineNumber = nodeStartLineNumber;
    }

}

class PieceTreeSearchCache {

    final _limit:Int;

    final _cache:Array<CacheEntry>;

    public function new(limit:Int) {
        this._limit = limit;
        this._cache = [];
    }

    public function get(offset:Int):Null<CacheEntry> {
        var i = this._cache.length - 1;
        while (i >= 0) {
            final nodePos = this._cache[i];
            if (nodePos.nodeStartOffset <= offset && nodePos.nodeStartOffset + nodePos.node.piece.length >= offset) {
                return nodePos;
            }
            i--;
        }
        return null;
    }

    public function get2(lineNumber:Int):Null<CacheEntry> {
        var i = this._cache.length - 1;
        while (i >= 0) {
            final nodePos = this._cache[i];
            if (nodePos.nodeStartLineNumber != 0 && nodePos.nodeStartLineNumber < lineNumber && nodePos.nodeStartLineNumber + nodePos.node.piece.lineFeedCnt >= lineNumber) {
                return nodePos;
            }
            i--;
        }
        return null;
    }

    public function set(node:TreeNode, nodeStartOffset:Int, nodeStartLineNumber:Int):Void {
        if (this._cache.length >= this._limit) {
            // Reuse the oldest entry (Monaco shifts it out and pushes a new one)
            final entry = this._cache.shift();
            entry.node = node;
            entry.nodeStartOffset = nodeStartOffset;
            entry.nodeStartLineNumber = nodeStartLineNumber;
            this._cache.push(entry);
            return;
        }
        this._cache.push(new CacheEntry(node, nodeStartOffset, nodeStartLineNumber));
    }

    public function validate(offset:Int):Void {
        // Same result as Monaco's (which rebuilds the array when an entry is
        // invalid), filtered in place
        final tmp = this._cache;
        var j = 0;
        for (i in 0...tmp.length) {
            final nodePos = tmp[i];
            if (nodePos.node.parent == null || nodePos.nodeStartOffset >= offset) {
                continue;
            }
            tmp[j++] = nodePos;
        }
        if (j != tmp.length) {
            tmp.resize(j);
        }
    }

}

class PieceTreeBase {

    static inline final AverageBufferSize = 65535;

    /**
     * The sentinel of this tree (Monaco shares one between all the trees,
     * see `TreeNode`).
     */
    public final SENTINEL:TreeNode;

    public var root:TreeNode;

    /**
     * 0 is change buffer, others are readonly original buffer.
     *
     * Cityscape: the change buffer is `_buffers[_changeBufferIndex]` (0 at
     * first). Appending to a Haxe string copies it on hxcpp (JavaScript
     * strings are ropes), so once the change buffer reaches
     * `ChangeBufferLimit` characters a new empty one is pushed and becomes
     * the change buffer (the previous one is read only from then on, like the
     * original buffers). The text and the line breaks are the same; only the
     * cost of typing stays bounded.
     */
    var _buffers:Array<StringBuffer>;

    var _changeBufferIndex:Int;

    static inline final ChangeBufferLimit = 16384;

    var _lineCnt:Int;

    var _length:Int;

    var _EOL:String;

    var _EOLLength:Int;

    var _EOLNormalized:Bool;

    var _lastChangeBufferPos:BufferCursor;

    var _searchCache:PieceTreeSearchCache;

    var _lastVisitedLineNumber:Int;

    var _lastVisitedLineValue:String;

    /**
     * Scratch position of `getLineCharCode` (no allocation per call).
     */
    final _tmpNodePosition:NodePosition;

    /**
     * `eol` is `'\r\n'` or `'\n'`.
     */
    public function new(chunks:Array<StringBuffer>, eol:String, eolNormalized:Bool) {
        this.SENTINEL = RbTreeBase.createSentinel();
        this._tmpNodePosition = new NodePosition(null, 0, 0);
        this.create(chunks, eol, eolNormalized);
    }

    // #region module functions

    public static function createLineStartsFast(str:String, readonly:Bool = true):Array<Int> {
        final r:Array<Int> = [0];
        var rLength = 1;

        var i = 0;
        final len = str.length;
        while (i < len) {
            final chr = StringTools.fastCodeAt(str, i);

            if (chr == CharCode.CarriageReturn) {
                if (i + 1 < len && StringTools.fastCodeAt(str, i + 1) == CharCode.LineFeed) {
                    // \r\n... case
                    r[rLength++] = i + 2;
                    i++; // skip \n
                }
                else {
                    // \r... case
                    r[rLength++] = i + 1;
                }
            }
            else if (chr == CharCode.LineFeed) {
                r[rLength++] = i + 1;
            }
            i++;
        }
        return r;
    }

    public static function createLineStarts(r:Array<Int>, str:String):LineStarts {
        r.resize(0);
        r[0] = 0;
        var rLength = 1;
        var cr = 0, lf = 0, crlf = 0;
        var isBasicASCII = true;
        var i = 0;
        final len = str.length;
        while (i < len) {
            final chr = StringTools.fastCodeAt(str, i);

            if (chr == CharCode.CarriageReturn) {
                if (i + 1 < len && StringTools.fastCodeAt(str, i + 1) == CharCode.LineFeed) {
                    // \r\n... case
                    crlf++;
                    r[rLength++] = i + 2;
                    i++; // skip \n
                }
                else {
                    cr++;
                    // \r... case
                    r[rLength++] = i + 1;
                }
            }
            else if (chr == CharCode.LineFeed) {
                lf++;
                r[rLength++] = i + 1;
            }
            else {
                if (isBasicASCII) {
                    if (chr != CharCode.Tab && (chr < 32 || chr > 126)) {
                        isBasicASCII = false;
                    }
                }
            }
            i++;
        }
        final result = new LineStarts(r.copy(), cr, lf, crlf, isBasicASCII);
        r.resize(0);

        return result;
    }

    // #endregion

    public function create(chunks:Array<StringBuffer>, eol:String, eolNormalized:Bool):Void {
        this._buffers = [
            new StringBuffer('', [0])
        ];
        this._changeBufferIndex = 0;
        this._lastChangeBufferPos = new BufferCursor(0, 0);
        this.root = SENTINEL;
        this._lineCnt = 1;
        this._length = 0;
        this._EOL = eol;
        this._EOLLength = eol.length;
        this._EOLNormalized = eolNormalized;

        var lastNode:Null<TreeNode> = null;
        for (i in 0...chunks.length) {
            if (chunks[i].buffer.length > 0) {
                if (chunks[i].lineStarts == null) {
                    chunks[i].lineStarts = createLineStartsFast(chunks[i].buffer);
                }

                final lineStarts = chunks[i].lineStarts;
                final piece = new Piece(
                    i + 1,
                    new BufferCursor(0, 0),
                    new BufferCursor(lineStarts.length - 1, chunks[i].buffer.length - lineStarts[lineStarts.length - 1]),
                    lineStarts.length - 1,
                    chunks[i].buffer.length
                );
                this._buffers.push(chunks[i]);
                lastNode = this.rbInsertRight(lastNode, piece);
            }
        }

        this._searchCache = new PieceTreeSearchCache(1);
        this._lastVisitedLineNumber = 0;
        this._lastVisitedLineValue = '';
        this.computeBufferMetadata();
    }

    public function normalizeEOL(eol:String):Void {
        final averageBufferSize = AverageBufferSize;
        final min = averageBufferSize - Math.floor(averageBufferSize / 3);
        final max = min * 2;

        var tempChunk = new StringBuf();
        var tempChunkLen = 0;
        final chunks:Array<StringBuffer> = [];

        this.iterate(this.root, node -> {
            final str = this.getNodeContent(node);
            final len = str.length;
            if (tempChunkLen <= min || tempChunkLen + len < max) {
                tempChunk.add(str);
                tempChunkLen += len;
                return true;
            }

            // flush anyways
            final text = Strings.replaceLineBreaks(tempChunk.toString(), eol);
            chunks.push(new StringBuffer(text, createLineStartsFast(text)));
            tempChunk = new StringBuf();
            tempChunk.add(str);
            tempChunkLen = len;
            return true;
        });

        if (tempChunkLen > 0) {
            final text = Strings.replaceLineBreaks(tempChunk.toString(), eol);
            chunks.push(new StringBuffer(text, createLineStartsFast(text)));
        }

        this.create(chunks, eol, true);
    }

    // #region Buffer API

    public function getEOL():String {
        return this._EOL;
    }

    public function setEOL(newEOL:String):Void {
        this._EOL = newEOL;
        this._EOLLength = this._EOL.length;
        this.normalizeEOL(newEOL);
    }

    public function createSnapshot(BOM:String):ITextSnapshot {
        return new PieceTreeSnapshot(this, BOM);
    }

    public function equal(other:PieceTreeBase):Bool {
        if (this.getLength() != other.getLength()) {
            return false;
        }
        if (this.getLineCount() != other.getLineCount()) {
            return false;
        }

        var offset = 0;
        final ret = this.iterate(this.root, node -> {
            if (node == SENTINEL) {
                return true;
            }
            final str = this.getNodeContent(node);
            final len = str.length;
            final startPosition = other.nodeAt(offset);
            final endPosition = other.nodeAt(offset + len);
            final val = other.getValueInRange2(startPosition, endPosition);

            offset += len;
            return str == val;
        });

        return ret;
    }

    public function getOffsetAt(lineNumber:Int, column:Int):Int {
        var leftLen = 0; // inorder

        var x = this.root;

        while (x != SENTINEL) {
            if (x.left != SENTINEL && x.lf_left + 1 >= lineNumber) {
                x = x.left;
            }
            else if (x.lf_left + x.piece.lineFeedCnt + 1 >= lineNumber) {
                leftLen += x.size_left;
                // lineNumber >= 2
                final accumualtedValInCurrentIndex = this.getAccumulatedValue(x, lineNumber - x.lf_left - 2);
                return leftLen += accumualtedValInCurrentIndex + column - 1;
            }
            else {
                lineNumber -= x.lf_left + x.piece.lineFeedCnt;
                leftLen += x.size_left + x.piece.length;
                x = x.right;
            }
        }

        return leftLen;
    }

    public function getPositionAt(offset:Int):Position {
        offset = Std.int(Math.max(0, offset));

        var x = this.root;
        var lfCnt = 0;
        final originalOffset = offset;

        while (x != SENTINEL) {
            if (x.size_left != 0 && x.size_left >= offset) {
                x = x.left;
            }
            else if (x.size_left + x.piece.length >= offset) {
                this.getIndexOf(x, offset - x.size_left);
                final outIndex = this._indexOfIndex;
                final outRemainder = this._indexOfRemainder;

                lfCnt += x.lf_left + outIndex;

                if (outIndex == 0) {
                    final lineStartOffset = this.getOffsetAt(lfCnt + 1, 1);
                    final column = originalOffset - lineStartOffset;
                    return new Position(lfCnt + 1, column + 1);
                }

                return new Position(lfCnt + 1, outRemainder + 1);
            }
            else {
                offset -= x.size_left + x.piece.length;
                lfCnt += x.lf_left + x.piece.lineFeedCnt;

                if (x.right == SENTINEL) {
                    // last node
                    final lineStartOffset = this.getOffsetAt(lfCnt + 1, 1);
                    final column = originalOffset - offset - lineStartOffset;
                    return new Position(lfCnt + 1, column + 1);
                }
                else {
                    x = x.right;
                }
            }
        }

        return new Position(1, 1);
    }

    /**
     * `eol` is null (keep the buffer's line breaks), `'\r\n'` or `'\n'`.
     */
    public function getValueInRange(range:Range, ?eol:String):String {
        if (range.startLineNumber == range.endLineNumber && range.startColumn == range.endColumn) {
            return '';
        }

        final startPosition = this.nodeAt2(range.startLineNumber, range.startColumn);
        final endPosition = this.nodeAt2(range.endLineNumber, range.endColumn);

        final value = this.getValueInRange2(startPosition, endPosition);
        if (eol != null && eol.length > 0) {
            if (eol != this._EOL || !this._EOLNormalized) {
                return Strings.replaceLineBreaks(value, eol);
            }

            if (eol == this.getEOL() && this._EOLNormalized) {
                return value;
            }
            return Strings.replaceLineBreaks(value, eol);
        }
        return value;
    }

    public function getValueInRange2(startPosition:NodePosition, endPosition:NodePosition):String {
        if (startPosition.node == endPosition.node) {
            final node = startPosition.node;
            final buffer = this._buffers[node.piece.bufferIndex].buffer;
            final startOffset = this.offsetInBuffer(node.piece.bufferIndex, node.piece.start);
            return buffer.substring(startOffset + startPosition.remainder, startOffset + endPosition.remainder);
        }

        var x = startPosition.node;
        final buffer = this._buffers[x.piece.bufferIndex].buffer;
        final startOffset = this.offsetInBuffer(x.piece.bufferIndex, x.piece.start);
        final ret = new StringBuf();
        ret.add(buffer.substring(startOffset + startPosition.remainder, startOffset + x.piece.length));

        x = x.next(SENTINEL);
        while (x != SENTINEL) {
            final buffer = this._buffers[x.piece.bufferIndex].buffer;
            final startOffset = this.offsetInBuffer(x.piece.bufferIndex, x.piece.start);

            if (x == endPosition.node) {
                ret.add(buffer.substring(startOffset, startOffset + endPosition.remainder));
                break;
            }
            else {
                ret.add(buffer.substr(startOffset, x.piece.length));
            }

            x = x.next(SENTINEL);
        }

        return ret.toString();
    }

    public function getLinesContent():Array<String> {
        final lines:Array<String> = [];
        var linesLength = 0;
        var currentLine = '';
        var danglingCR = false;

        this.iterate(this.root, node -> {
            if (node == SENTINEL) {
                return true;
            }

            final piece = node.piece;
            var pieceLength = piece.length;
            if (pieceLength == 0) {
                return true;
            }

            final buffer = this._buffers[piece.bufferIndex].buffer;
            final lineStarts = this._buffers[piece.bufferIndex].lineStarts;

            final pieceStartLine = piece.start.line;
            final pieceEndLine = piece.end.line;
            var pieceStartOffset = lineStarts[pieceStartLine] + piece.start.column;

            if (danglingCR) {
                if (charCodeAt(buffer, pieceStartOffset) == CharCode.LineFeed) {
                    // pretend the \n was in the previous piece..
                    pieceStartOffset++;
                    pieceLength--;
                }
                lines[linesLength++] = currentLine;
                currentLine = '';
                danglingCR = false;
                if (pieceLength == 0) {
                    return true;
                }
            }

            if (pieceStartLine == pieceEndLine) {
                // this piece has no new lines
                if (!this._EOLNormalized && charCodeAt(buffer, pieceStartOffset + pieceLength - 1) == CharCode.CarriageReturn) {
                    danglingCR = true;
                    currentLine += buffer.substr(pieceStartOffset, pieceLength - 1);
                }
                else {
                    currentLine += buffer.substr(pieceStartOffset, pieceLength);
                }
                return true;
            }

            // add the text before the first line start in this piece
            currentLine += (
                this._EOLNormalized
                    ? buffer.substring(pieceStartOffset, Std.int(Math.max(pieceStartOffset, lineStarts[pieceStartLine + 1] - this._EOLLength)))
                    : Strings.removeTrailingLineBreak(buffer.substring(pieceStartOffset, lineStarts[pieceStartLine + 1]))
            );
            lines[linesLength++] = currentLine;

            for (line in pieceStartLine + 1...pieceEndLine) {
                currentLine = (
                    this._EOLNormalized
                        ? buffer.substring(lineStarts[line], lineStarts[line + 1] - this._EOLLength)
                        : Strings.removeTrailingLineBreak(buffer.substring(lineStarts[line], lineStarts[line + 1]))
                );
                lines[linesLength++] = currentLine;
            }

            if (!this._EOLNormalized && charCodeAt(buffer, lineStarts[pieceEndLine] + piece.end.column - 1) == CharCode.CarriageReturn) {
                danglingCR = true;
                if (piece.end.column == 0) {
                    // The last line ended with a \r, let's undo the push, it will be pushed by next iteration
                    linesLength--;
                }
                else {
                    currentLine = buffer.substr(lineStarts[pieceEndLine], piece.end.column - 1);
                }
            }
            else {
                currentLine = buffer.substr(lineStarts[pieceEndLine], piece.end.column);
            }

            return true;
        });

        if (danglingCR) {
            lines[linesLength++] = currentLine;
            currentLine = '';
        }

        lines[linesLength++] = currentLine;
        return lines;
    }

    /**
     * `charCodeAt` with JavaScript's out of range result (`NaN`, which
     * compares false with every code): -1 here.
     */
    static inline function charCodeAt(str:String, index:Int):Int {
        return (index >= 0 && index < str.length) ? StringTools.fastCodeAt(str, index) : -1;
    }

    public function getLength():Int {
        return this._length;
    }

    public function getLineCount():Int {
        return this._lineCnt;
    }

    public function getLineContent(lineNumber:Int):String {
        if (this._lastVisitedLineNumber == lineNumber) {
            return this._lastVisitedLineValue;
        }

        this._lastVisitedLineNumber = lineNumber;

        if (lineNumber == this._lineCnt) {
            this._lastVisitedLineValue = this.getLineRawContent(lineNumber);
        }
        else if (this._EOLNormalized) {
            this._lastVisitedLineValue = this.getLineRawContent(lineNumber, this._EOLLength);
        }
        else {
            this._lastVisitedLineValue = Strings.removeTrailingLineBreak(this.getLineRawContent(lineNumber));
        }

        return this._lastVisitedLineValue;
    }

    function _getCharCode(nodePos:NodePosition):Int {
        if (nodePos.remainder == nodePos.node.piece.length) {
            // the char we want to fetch is at the head of next node.
            final matchingNode = nodePos.node.next(SENTINEL);
            if (matchingNode == SENTINEL) {
                // Monaco reads the piece of the sentinel here (and throws)
                return 0;
            }

            final buffer = this._buffers[matchingNode.piece.bufferIndex];
            final startOffset = this.offsetInBuffer(matchingNode.piece.bufferIndex, matchingNode.piece.start);
            return charCodeAt(buffer.buffer, startOffset);
        }
        else {
            final buffer = this._buffers[nodePos.node.piece.bufferIndex];
            final startOffset = this.offsetInBuffer(nodePos.node.piece.bufferIndex, nodePos.node.piece.start);
            final targetOffset = startOffset + nodePos.remainder;

            return charCodeAt(buffer.buffer, targetOffset);
        }
    }

    public function getLineCharCode(lineNumber:Int, index:Int):Int {
        final nodePos = this.nodeAt2(lineNumber, index + 1, this._tmpNodePosition);
        final result = this._getCharCode(nodePos);
        nodePos.node = null;
        return result;
    }

    public function getLineLength(lineNumber:Int):Int {
        if (lineNumber == this.getLineCount()) {
            final startOffset = this.getOffsetAt(lineNumber, 1);
            return this.getLength() - startOffset;
        }
        return this.getOffsetAt(lineNumber + 1, 1) - this.getOffsetAt(lineNumber, 1) - this._EOLLength;
    }

    public function getCharCode(offset:Int):Int {
        final nodePos = this.nodeAt(offset);
        return this._getCharCode(nodePos);
    }

    public function getNearestChunk(offset:Int):String {
        final nodePos = this.nodeAt(offset);
        if (nodePos.remainder == nodePos.node.piece.length) {
            // the offset is at the head of next node.
            final matchingNode = nodePos.node.next(SENTINEL);
            if (matchingNode == null || matchingNode == SENTINEL) {
                return '';
            }

            final buffer = this._buffers[matchingNode.piece.bufferIndex];
            final startOffset = this.offsetInBuffer(matchingNode.piece.bufferIndex, matchingNode.piece.start);
            return buffer.buffer.substring(startOffset, startOffset + matchingNode.piece.length);
        }
        else {
            final buffer = this._buffers[nodePos.node.piece.bufferIndex];
            final startOffset = this.offsetInBuffer(nodePos.node.piece.bufferIndex, nodePos.node.piece.start);
            final targetOffset = startOffset + nodePos.remainder;
            final targetEnd = startOffset + nodePos.node.piece.length;
            return buffer.buffer.substring(targetOffset, targetEnd);
        }
    }

    public function findMatchesInNode(node:TreeNode, searcher:Searcher, startLineNumber:Int, startColumn:Int, startCursor:BufferCursor, endCursor:BufferCursor, searchData:SearchData, captureMatches:Bool, limitResultCount:Int, resultLen:Int, result:Array<FindMatch>):Int {
        final buffer = this._buffers[node.piece.bufferIndex];
        final startOffsetInBuffer = this.offsetInBuffer(node.piece.bufferIndex, node.piece.start);
        final start = this.offsetInBuffer(node.piece.bufferIndex, startCursor);
        final end = this.offsetInBuffer(node.piece.bufferIndex, endCursor);

        var m:Null<RegExpExecArray>;
        // Reset regex to search from the beginning
        final ret = new BufferCursor(0, 0);
        var searchText:String;
        var offsetInBufferDelta:Int;

        if (searcher._wordSeparators != null) {
            searchText = buffer.buffer.substring(start, end);
            offsetInBufferDelta = start;
            searcher.reset(0);
        }
        else {
            searchText = buffer.buffer;
            offsetInBufferDelta = 0;
            searcher.reset(start);
        }

        do {
            m = searcher.next(searchText);

            if (m != null) {
                if (m.index + offsetInBufferDelta >= end) {
                    return resultLen;
                }
                this.positionInBuffer(node, m.index + offsetInBufferDelta - startOffsetInBuffer, ret);
                final lineFeedCnt = this.getLineFeedCnt(node.piece.bufferIndex, startCursor, ret);
                final retStartColumn = ret.line == startCursor.line ? ret.column - startCursor.column + startColumn : ret.column + 1;
                final retEndColumn = retStartColumn + m[0].length;
                result[resultLen++] = TextModelSearch.createFindMatch(new Range(startLineNumber + lineFeedCnt, retStartColumn, startLineNumber + lineFeedCnt, retEndColumn), m, captureMatches);

                if (m.index + offsetInBufferDelta + m[0].length >= end) {
                    return resultLen;
                }
                if (resultLen >= limitResultCount) {
                    return resultLen;
                }
            }
        } while (m != null);

        return resultLen;
    }

    public function findMatchesLineByLine(searchRange:Range, searchData:SearchData, captureMatches:Bool, limitResultCount:Int):Array<FindMatch> {
        final result:Array<FindMatch> = [];
        var resultLen = 0;
        final searcher = new Searcher(searchData.wordSeparators, searchData.regex);

        var startPosition = this.nodeAt2(searchRange.startLineNumber, searchRange.startColumn);
        if (startPosition == null) {
            return [];
        }
        final endPosition = this.nodeAt2(searchRange.endLineNumber, searchRange.endColumn);
        if (endPosition == null) {
            return [];
        }
        var start = this.positionInBuffer(startPosition.node, startPosition.remainder);
        final end = this.positionInBuffer(endPosition.node, endPosition.remainder);

        if (startPosition.node == endPosition.node) {
            this.findMatchesInNode(startPosition.node, searcher, searchRange.startLineNumber, searchRange.startColumn, start, end, searchData, captureMatches, limitResultCount, resultLen, result);
            return result;
        }

        var startLineNumber = searchRange.startLineNumber;

        var currentNode = startPosition.node;
        while (currentNode != endPosition.node) {
            final lineBreakCnt = this.getLineFeedCnt(currentNode.piece.bufferIndex, start, currentNode.piece.end);

            if (lineBreakCnt >= 1) {
                // last line break position
                final lineStarts = this._buffers[currentNode.piece.bufferIndex].lineStarts;
                final startOffsetInBuffer = this.offsetInBuffer(currentNode.piece.bufferIndex, currentNode.piece.start);
                final nextLineStartOffset = lineStarts[start.line + lineBreakCnt];
                final startColumn = startLineNumber == searchRange.startLineNumber ? searchRange.startColumn : 1;
                resultLen = this.findMatchesInNode(currentNode, searcher, startLineNumber, startColumn, start, this.positionInBuffer(currentNode, nextLineStartOffset - startOffsetInBuffer), searchData, captureMatches, limitResultCount, resultLen, result);

                if (resultLen >= limitResultCount) {
                    return result;
                }

                startLineNumber += lineBreakCnt;
            }

            final startColumn = startLineNumber == searchRange.startLineNumber ? searchRange.startColumn - 1 : 0;
            // search for the remaining content
            if (startLineNumber == searchRange.endLineNumber) {
                final text = jsSubstring(this.getLineContent(startLineNumber), startColumn, searchRange.endColumn - 1);
                resultLen = this._findMatchesInLine(searchData, searcher, text, searchRange.endLineNumber, startColumn, resultLen, result, captureMatches, limitResultCount);
                return result;
            }

            resultLen = this._findMatchesInLine(searchData, searcher, this.getLineContent(startLineNumber).substr(startColumn), startLineNumber, startColumn, resultLen, result, captureMatches, limitResultCount);

            if (resultLen >= limitResultCount) {
                return result;
            }

            startLineNumber++;
            startPosition = this.nodeAt2(startLineNumber, 1);
            currentNode = startPosition.node;
            start = this.positionInBuffer(startPosition.node, startPosition.remainder);
        }

        if (startLineNumber == searchRange.endLineNumber) {
            final startColumn = startLineNumber == searchRange.startLineNumber ? searchRange.startColumn - 1 : 0;
            final text = jsSubstring(this.getLineContent(startLineNumber), startColumn, searchRange.endColumn - 1);
            resultLen = this._findMatchesInLine(searchData, searcher, text, searchRange.endLineNumber, startColumn, resultLen, result, captureMatches, limitResultCount);
            return result;
        }

        final startColumn = startLineNumber == searchRange.startLineNumber ? searchRange.startColumn : 1;
        resultLen = this.findMatchesInNode(endPosition.node, searcher, startLineNumber, startColumn, start, end, searchData, captureMatches, limitResultCount, resultLen, result);
        return result;
    }

    /**
     * JavaScript's `substring` (arguments clamped, swapped when reversed).
     */
    static function jsSubstring(str:String, start:Int, end:Int):String {
        final len = str.length;
        if (start < 0) start = 0;
        if (end < 0) end = 0;
        if (start > len) start = len;
        if (end > len) end = len;
        if (start > end) {
            final t = start;
            start = end;
            end = t;
        }
        return str.substring(start, end);
    }

    function _findMatchesInLine(searchData:SearchData, searcher:Searcher, text:String, lineNumber:Int, deltaOffset:Int, resultLen:Int, result:Array<FindMatch>, captureMatches:Bool, limitResultCount:Int):Int {
        final wordSeparators = searchData.wordSeparators;
        if (!captureMatches && searchData.simpleSearch != null && searchData.simpleSearch.length > 0) {
            final searchString = searchData.simpleSearch;
            final searchStringLen = searchString.length;
            final textLength = text.length;

            var lastMatchIndex = -searchStringLen;
            while ((lastMatchIndex = text.indexOf(searchString, lastMatchIndex + searchStringLen)) != -1) {
                if (wordSeparators == null || TextModelSearch.isValidMatch(wordSeparators, text, textLength, lastMatchIndex, searchStringLen)) {
                    result[resultLen++] = new FindMatch(new Range(lineNumber, lastMatchIndex + 1 + deltaOffset, lineNumber, lastMatchIndex + 1 + searchStringLen + deltaOffset), null);
                    if (resultLen >= limitResultCount) {
                        return resultLen;
                    }
                }
            }
            return resultLen;
        }

        var m:Null<RegExpExecArray>;
        // Reset regex to search from the beginning
        searcher.reset(0);
        do {
            m = searcher.next(text);
            if (m != null) {
                result[resultLen++] = TextModelSearch.createFindMatch(new Range(lineNumber, m.index + 1 + deltaOffset, lineNumber, m.index + 1 + m[0].length + deltaOffset), m, captureMatches);
                if (resultLen >= limitResultCount) {
                    return resultLen;
                }
            }
        } while (m != null);
        return resultLen;
    }

    // #endregion

    // #region Piece Table

    public function insert(offset:Int, value:String, eolNormalized:Bool = false):Void {
        this._EOLNormalized = this._EOLNormalized && eolNormalized;
        this._lastVisitedLineNumber = 0;
        this._lastVisitedLineValue = '';

        if (this.root != SENTINEL) {
            final nodePosition = this.nodeAt(offset);
            final node = nodePosition.node;
            final remainder = nodePosition.remainder;
            final nodeStartOffset = nodePosition.nodeStartOffset;
            final piece = node.piece;
            final bufferIndex = piece.bufferIndex;
            final insertPosInBuffer = this.positionInBuffer(node, remainder);
            if (node.piece.bufferIndex == this._changeBufferIndex
                && piece.end.line == this._lastChangeBufferPos.line
                && piece.end.column == this._lastChangeBufferPos.column
                && (nodeStartOffset + piece.length == offset)
                && value.length < AverageBufferSize
                // Cityscape: a full change buffer is not appended to (see `_buffers`)
                && this._buffers[this._changeBufferIndex].buffer.length < ChangeBufferLimit
            ) {
                // changed buffer
                this.appendToNode(node, value);
                this.computeBufferMetadata();
                return;
            }

            if (nodeStartOffset == offset) {
                this.insertContentToNodeLeft(value, node);
                this._searchCache.validate(offset);
            }
            else if (nodeStartOffset + node.piece.length > offset) {
                // we are inserting into the middle of a node.
                final nodesToDel:Array<TreeNode> = [];
                var newRightPiece = new Piece(
                    piece.bufferIndex,
                    insertPosInBuffer,
                    piece.end,
                    this.getLineFeedCnt(piece.bufferIndex, insertPosInBuffer, piece.end),
                    this.offsetInBuffer(bufferIndex, piece.end) - this.offsetInBuffer(bufferIndex, insertPosInBuffer)
                );

                if (this.shouldCheckCRLF() && this.endWithCRString(value)) {
                    final headOfRight = this.nodeCharCodeAt(node, remainder);

                    if (headOfRight == 10 /** \n */) {
                        final newStart = new BufferCursor(newRightPiece.start.line + 1, 0);
                        newRightPiece = new Piece(
                            newRightPiece.bufferIndex,
                            newStart,
                            newRightPiece.end,
                            this.getLineFeedCnt(newRightPiece.bufferIndex, newStart, newRightPiece.end),
                            newRightPiece.length - 1
                        );

                        value += '\n';
                    }
                }

                // reuse node for content before insertion point.
                if (this.shouldCheckCRLF() && this.startWithLFString(value)) {
                    final tailOfLeft = this.nodeCharCodeAt(node, remainder - 1);
                    if (tailOfLeft == 13 /** \r */) {
                        final previousPos = this.positionInBuffer(node, remainder - 1);
                        this.deleteNodeTail(node, previousPos);
                        value = '\r' + value;

                        if (node.piece.length == 0) {
                            nodesToDel.push(node);
                        }
                    }
                    else {
                        this.deleteNodeTail(node, insertPosInBuffer);
                    }
                }
                else {
                    this.deleteNodeTail(node, insertPosInBuffer);
                }

                final newPieces = this.createNewPieces(value);
                if (newRightPiece.length > 0) {
                    this.rbInsertRight(node, newRightPiece);
                }

                var tmpNode = node;
                for (k in 0...newPieces.length) {
                    tmpNode = this.rbInsertRight(tmpNode, newPieces[k]);
                }
                this.deleteNodes(nodesToDel);
            }
            else {
                this.insertContentToNodeRight(value, node);
            }
        }
        else {
            // insert new node
            final pieces = this.createNewPieces(value);
            var node = this.rbInsertLeft(null, pieces[0]);

            for (k in 1...pieces.length) {
                node = this.rbInsertRight(node, pieces[k]);
            }
        }

        // todo, this is too brutal. Total line feed count should be updated the same way as lf_left.
        this.computeBufferMetadata();
    }

    public function delete(offset:Int, cnt:Int):Void {
        this._lastVisitedLineNumber = 0;
        this._lastVisitedLineValue = '';

        if (cnt <= 0 || this.root == SENTINEL) {
            return;
        }

        final startPosition = this.nodeAt(offset);
        final endPosition = this.nodeAt(offset + cnt);
        final startNode = startPosition.node;
        final endNode = endPosition.node;

        if (startNode == endNode) {
            final startSplitPosInBuffer = this.positionInBuffer(startNode, startPosition.remainder);
            final endSplitPosInBuffer = this.positionInBuffer(startNode, endPosition.remainder);

            if (startPosition.nodeStartOffset == offset) {
                if (cnt == startNode.piece.length) { // delete node
                    final next = startNode.next(SENTINEL);
                    RbTreeBase.rbDelete(this, startNode);
                    this.validateCRLFWithPrevNode(next);
                    this.computeBufferMetadata();
                    return;
                }
                this.deleteNodeHead(startNode, endSplitPosInBuffer);
                this._searchCache.validate(offset);
                this.validateCRLFWithPrevNode(startNode);
                this.computeBufferMetadata();
                return;
            }

            if (startPosition.nodeStartOffset + startNode.piece.length == offset + cnt) {
                this.deleteNodeTail(startNode, startSplitPosInBuffer);
                this.validateCRLFWithNextNode(startNode);
                this.computeBufferMetadata();
                return;
            }

            // delete content in the middle, this node will be splitted to nodes
            this.shrinkNode(startNode, startSplitPosInBuffer, endSplitPosInBuffer);
            this.computeBufferMetadata();
            return;
        }

        final nodesToDel:Array<TreeNode> = [];

        final startSplitPosInBuffer = this.positionInBuffer(startNode, startPosition.remainder);
        this.deleteNodeTail(startNode, startSplitPosInBuffer);
        this._searchCache.validate(offset);
        if (startNode.piece.length == 0) {
            nodesToDel.push(startNode);
        }

        // update last touched node
        final endSplitPosInBuffer = this.positionInBuffer(endNode, endPosition.remainder);
        this.deleteNodeHead(endNode, endSplitPosInBuffer);
        if (endNode.piece.length == 0) {
            nodesToDel.push(endNode);
        }

        // delete nodes in between
        final secondNode = startNode.next(SENTINEL);
        var node = secondNode;
        while (node != SENTINEL && node != endNode) {
            nodesToDel.push(node);
            node = node.next(SENTINEL);
        }

        final prev = startNode.piece.length == 0 ? startNode.prev(SENTINEL) : startNode;
        this.deleteNodes(nodesToDel);
        this.validateCRLFWithNextNode(prev);
        this.computeBufferMetadata();
    }

    function insertContentToNodeLeft(value:String, node:TreeNode):Void {
        // we are inserting content to the beginning of node
        final nodesToDel:Array<TreeNode> = [];
        if (this.shouldCheckCRLF() && this.endWithCRString(value) && this.startWithLF(node)) {
            // move `\n` to new node.

            final piece = node.piece;
            final newStart = new BufferCursor(piece.start.line + 1, 0);
            final nPiece = new Piece(
                piece.bufferIndex,
                newStart,
                piece.end,
                this.getLineFeedCnt(piece.bufferIndex, newStart, piece.end),
                piece.length - 1
            );

            node.piece = nPiece;

            value += '\n';
            RbTreeBase.updateTreeMetadata(this, node, -1, -1);

            if (node.piece.length == 0) {
                nodesToDel.push(node);
            }
        }

        final newPieces = this.createNewPieces(value);
        var newNode = this.rbInsertLeft(node, newPieces[newPieces.length - 1]);
        var k = newPieces.length - 2;
        while (k >= 0) {
            newNode = this.rbInsertLeft(newNode, newPieces[k]);
            k--;
        }
        this.validateCRLFWithPrevNode(newNode);
        this.deleteNodes(nodesToDel);
    }

    function insertContentToNodeRight(value:String, node:TreeNode):Void {
        // we are inserting to the right of this node.
        if (this.adjustCarriageReturnFromNext(value, node)) {
            // move \n to the new node.
            value += '\n';
        }

        final newPieces = this.createNewPieces(value);
        final newNode = this.rbInsertRight(node, newPieces[0]);
        var tmpNode = newNode;

        for (k in 1...newPieces.length) {
            tmpNode = this.rbInsertRight(tmpNode, newPieces[k]);
        }

        this.validateCRLFWithPrevNode(newNode);
    }

    /**
     * The position in the buffer of `remainder` in `node`. Fills and
     * returns `ret` when given (Monaco's overload that returns null then).
     */
    function positionInBuffer(node:TreeNode, remainder:Int, ?ret:BufferCursor):BufferCursor {
        final piece = node.piece;
        final bufferIndex = node.piece.bufferIndex;
        final lineStarts = this._buffers[bufferIndex].lineStarts;

        final startOffset = lineStarts[piece.start.line] + piece.start.column;

        final offset = startOffset + remainder;

        // binary search offset between startOffset and endOffset
        var low = piece.start.line;
        var high = piece.end.line;

        var mid:Int = 0;
        var midStop:Int = 0;
        var midStart:Int = 0;

        while (low <= high) {
            mid = low + ((high - low) >> 1);
            midStart = lineStarts[mid];

            if (mid == high) {
                break;
            }

            midStop = lineStarts[mid + 1];

            if (offset < midStart) {
                high = mid - 1;
            }
            else if (offset >= midStop) {
                low = mid + 1;
            }
            else {
                break;
            }
        }

        if (ret != null) {
            ret.line = mid;
            ret.column = offset - midStart;
            return ret;
        }

        return new BufferCursor(mid, offset - midStart);
    }

    function getLineFeedCnt(bufferIndex:Int, start:BufferCursor, end:BufferCursor):Int {
        // we don't need to worry about start: abc\r|\n, or abc|\r, or abc|\n, or abc|\r\n doesn't change the fact that, there is one line break after start.
        // now let's take care of end: abc\r|\n, if end is in between \r and \n, we need to add line feed count by 1
        if (end.column == 0) {
            return end.line - start.line;
        }

        final lineStarts = this._buffers[bufferIndex].lineStarts;
        if (end.line == lineStarts.length - 1) { // it means, there is no \n after end, otherwise, there will be one more lineStart.
            return end.line - start.line;
        }

        final nextLineStartOffset = lineStarts[end.line + 1];
        final endOffset = lineStarts[end.line] + end.column;
        if (nextLineStartOffset > endOffset + 1) { // there are more than 1 character after end, which means it can't be \n
            return end.line - start.line;
        }
        // endOffset + 1 === nextLineStartOffset
        // character at endOffset is \n, so we check the character before first
        // if character at endOffset is \r, end.column is 0 and we can't get here.
        final previousCharOffset = endOffset - 1; // end.column > 0 so it's okay.
        final buffer = this._buffers[bufferIndex].buffer;

        if (charCodeAt(buffer, previousCharOffset) == 13) {
            return end.line - start.line + 1;
        }
        else {
            return end.line - start.line;
        }
    }

    inline function offsetInBuffer(bufferIndex:Int, cursor:BufferCursor):Int {
        final lineStarts = this._buffers[bufferIndex].lineStarts;
        return lineStarts[cursor.line] + cursor.column;
    }

    function deleteNodes(nodes:Array<TreeNode>):Void {
        for (i in 0...nodes.length) {
            RbTreeBase.rbDelete(this, nodes[i]);
        }
    }

    function createNewPieces(text:String):Array<Piece> {
        if (text.length > AverageBufferSize) {
            // the content is large, operations like substring, charCode becomes slow
            // so here we split it into smaller chunks, just like what we did for CR/LF normalization
            final newPieces:Array<Piece> = [];
            while (text.length > AverageBufferSize) {
                final lastChar = StringTools.fastCodeAt(text, AverageBufferSize - 1);
                var splitText;
                if (lastChar == CharCode.CarriageReturn || (lastChar >= 0xD800 && lastChar <= 0xDBFF)) {
                    // last character is \r or a high surrogate => keep it back
                    splitText = text.substring(0, AverageBufferSize - 1);
                    text = text.substring(AverageBufferSize - 1);
                }
                else {
                    splitText = text.substring(0, AverageBufferSize);
                    text = text.substring(AverageBufferSize);
                }

                final lineStarts = createLineStartsFast(splitText);
                newPieces.push(new Piece(
                    this._buffers.length, /* buffer index */
                    new BufferCursor(0, 0),
                    new BufferCursor(lineStarts.length - 1, splitText.length - lineStarts[lineStarts.length - 1]),
                    lineStarts.length - 1,
                    splitText.length
                ));
                this._buffers.push(new StringBuffer(splitText, lineStarts));
            }

            final lineStarts = createLineStartsFast(text);
            newPieces.push(new Piece(
                this._buffers.length, /* buffer index */
                new BufferCursor(0, 0),
                new BufferCursor(lineStarts.length - 1, text.length - lineStarts[lineStarts.length - 1]),
                lineStarts.length - 1,
                text.length
            ));
            this._buffers.push(new StringBuffer(text, lineStarts));

            return newPieces;
        }

        if (this._buffers[this._changeBufferIndex].buffer.length >= ChangeBufferLimit) {
            // Start a new change buffer (see `_buffers`)
            this._buffers.push(new StringBuffer('', [0]));
            this._changeBufferIndex = this._buffers.length - 1;
            this._lastChangeBufferPos = new BufferCursor(0, 0);
        }
        final changeBufferIndex = this._changeBufferIndex;
        final changeBuffer = this._buffers[changeBufferIndex];
        var startOffset = changeBuffer.buffer.length;
        final lineStarts = createLineStartsFast(text, false);

        var start = this._lastChangeBufferPos;
        final changeLineStarts = changeBuffer.lineStarts;
        if (changeLineStarts[changeLineStarts.length - 1] == startOffset
            && startOffset != 0
            && this.startWithLFString(text)
            && this.endWithCRString(changeBuffer.buffer) // todo, we can check this._lastChangeBufferPos's column as it's the last one
        ) {
            this._lastChangeBufferPos = new BufferCursor(this._lastChangeBufferPos.line, this._lastChangeBufferPos.column + 1);
            start = this._lastChangeBufferPos;

            // `lineStarts[i] += startOffset + 1` and
            // `concat(lineStarts.slice(1))`: appended in place
            for (i in 1...lineStarts.length) {
                changeLineStarts.push(lineStarts[i] + startOffset + 1);
            }
            changeBuffer.buffer += '_' + text;
            startOffset += 1;
        }
        else {
            for (i in 1...lineStarts.length) {
                changeLineStarts.push(lineStarts[i] + startOffset);
            }
            changeBuffer.buffer += text;
        }

        final endOffset = changeBuffer.buffer.length;
        final endIndex = changeLineStarts.length - 1;
        final endColumn = endOffset - changeLineStarts[endIndex];
        final endPos = new BufferCursor(endIndex, endColumn);
        final newPiece = new Piece(
            changeBufferIndex, /** todo@peng */
            start,
            endPos,
            this.getLineFeedCnt(changeBufferIndex, start, endPos),
            endOffset - startOffset
        );
        this._lastChangeBufferPos = endPos;
        return [newPiece];
    }

    public function getLinesRawContent():String {
        return this.getContentOfSubTree(this.root);
    }

    public function getLineRawContent(lineNumber:Int, endOffset:Int = 0):String {
        var x = this.root;

        var ret = '';
        final cache = this._searchCache.get2(lineNumber);
        if (cache != null) {
            x = cache.node;
            final prevAccumulatedValue = this.getAccumulatedValue(x, lineNumber - cache.nodeStartLineNumber - 1);
            final buffer = this._buffers[x.piece.bufferIndex].buffer;
            final startOffset = this.offsetInBuffer(x.piece.bufferIndex, x.piece.start);
            if (cache.nodeStartLineNumber + x.piece.lineFeedCnt == lineNumber) {
                ret = buffer.substring(startOffset + prevAccumulatedValue, startOffset + x.piece.length);
            }
            else {
                final accumulatedValue = this.getAccumulatedValue(x, lineNumber - cache.nodeStartLineNumber);
                return buffer.substring(startOffset + prevAccumulatedValue, startOffset + accumulatedValue - endOffset);
            }
        }
        else {
            var nodeStartOffset = 0;
            final originalLineNumber = lineNumber;
            while (x != SENTINEL) {
                if (x.left != SENTINEL && x.lf_left >= lineNumber - 1) {
                    x = x.left;
                }
                else if (x.lf_left + x.piece.lineFeedCnt > lineNumber - 1) {
                    final prevAccumulatedValue = this.getAccumulatedValue(x, lineNumber - x.lf_left - 2);
                    final accumulatedValue = this.getAccumulatedValue(x, lineNumber - x.lf_left - 1);
                    final buffer = this._buffers[x.piece.bufferIndex].buffer;
                    final startOffset = this.offsetInBuffer(x.piece.bufferIndex, x.piece.start);
                    nodeStartOffset += x.size_left;
                    this._searchCache.set(x, nodeStartOffset, originalLineNumber - (lineNumber - 1 - x.lf_left));

                    return buffer.substring(startOffset + prevAccumulatedValue, startOffset + accumulatedValue - endOffset);
                }
                else if (x.lf_left + x.piece.lineFeedCnt == lineNumber - 1) {
                    final prevAccumulatedValue = this.getAccumulatedValue(x, lineNumber - x.lf_left - 2);
                    final buffer = this._buffers[x.piece.bufferIndex].buffer;
                    final startOffset = this.offsetInBuffer(x.piece.bufferIndex, x.piece.start);

                    ret = buffer.substring(startOffset + prevAccumulatedValue, startOffset + x.piece.length);
                    break;
                }
                else {
                    lineNumber -= x.lf_left + x.piece.lineFeedCnt;
                    nodeStartOffset += x.size_left + x.piece.length;
                    x = x.right;
                }
            }
        }

        // search in order, to find the node contains end column
        x = x.next(SENTINEL);
        while (x != SENTINEL) {
            final buffer = this._buffers[x.piece.bufferIndex].buffer;

            if (x.piece.lineFeedCnt > 0) {
                final accumulatedValue = this.getAccumulatedValue(x, 0);
                final startOffset = this.offsetInBuffer(x.piece.bufferIndex, x.piece.start);

                ret += buffer.substring(startOffset, startOffset + accumulatedValue - endOffset);
                return ret;
            }
            else {
                final startOffset = this.offsetInBuffer(x.piece.bufferIndex, x.piece.start);
                ret += buffer.substr(startOffset, x.piece.length);
            }

            x = x.next(SENTINEL);
        }

        return ret;
    }

    function computeBufferMetadata():Void {
        var x = this.root;

        var lfCnt = 1;
        var len = 0;

        while (x != SENTINEL) {
            lfCnt += x.lf_left + x.piece.lineFeedCnt;
            len += x.size_left + x.piece.length;
            x = x.right;
        }

        this._lineCnt = lfCnt;
        this._length = len;
        this._searchCache.validate(this._length);
    }

    // #region node operations

    /**
     * Monaco returns `{ index, remainder }`; the result goes to
     * `_indexOfIndex` and `_indexOfRemainder` here (no allocation).
     */
    var _indexOfIndex:Int = 0;

    var _indexOfRemainder:Int = 0;

    final _tmpCursor:BufferCursor = new BufferCursor(0, 0);

    function getIndexOf(node:TreeNode, accumulatedValue:Int):Void {
        final piece = node.piece;
        final pos = this.positionInBuffer(node, accumulatedValue, this._tmpCursor);
        final lineCnt = pos.line - piece.start.line;

        if (this.offsetInBuffer(piece.bufferIndex, piece.end) - this.offsetInBuffer(piece.bufferIndex, piece.start) == accumulatedValue) {
            // we are checking the end of this node, so a CRLF check is necessary.
            final realLineCnt = this.getLineFeedCnt(node.piece.bufferIndex, piece.start, pos);
            if (realLineCnt != lineCnt) {
                // aha yes, CRLF
                this._indexOfIndex = realLineCnt;
                this._indexOfRemainder = 0;
                return;
            }
        }

        this._indexOfIndex = lineCnt;
        this._indexOfRemainder = pos.column;
    }

    function getAccumulatedValue(node:TreeNode, index:Int):Int {
        if (index < 0) {
            return 0;
        }
        final piece = node.piece;
        final lineStarts = this._buffers[piece.bufferIndex].lineStarts;
        final expectedLineStartIndex = piece.start.line + index + 1;
        if (expectedLineStartIndex > piece.end.line) {
            return lineStarts[piece.end.line] + piece.end.column - lineStarts[piece.start.line] - piece.start.column;
        }
        else {
            return lineStarts[expectedLineStartIndex] - lineStarts[piece.start.line] - piece.start.column;
        }
    }

    function deleteNodeTail(node:TreeNode, pos:BufferCursor):Void {
        final piece = node.piece;
        final originalLFCnt = piece.lineFeedCnt;
        final originalEndOffset = this.offsetInBuffer(piece.bufferIndex, piece.end);

        final newEnd = pos;
        final newEndOffset = this.offsetInBuffer(piece.bufferIndex, newEnd);
        final newLineFeedCnt = this.getLineFeedCnt(piece.bufferIndex, piece.start, newEnd);

        final lf_delta = newLineFeedCnt - originalLFCnt;
        final size_delta = newEndOffset - originalEndOffset;
        final newLength = piece.length + size_delta;

        node.piece = new Piece(
            piece.bufferIndex,
            piece.start,
            newEnd,
            newLineFeedCnt,
            newLength
        );

        RbTreeBase.updateTreeMetadata(this, node, size_delta, lf_delta);
    }

    function deleteNodeHead(node:TreeNode, pos:BufferCursor):Void {
        final piece = node.piece;
        final originalLFCnt = piece.lineFeedCnt;
        final originalStartOffset = this.offsetInBuffer(piece.bufferIndex, piece.start);

        final newStart = pos;
        final newLineFeedCnt = this.getLineFeedCnt(piece.bufferIndex, newStart, piece.end);
        final newStartOffset = this.offsetInBuffer(piece.bufferIndex, newStart);
        final lf_delta = newLineFeedCnt - originalLFCnt;
        final size_delta = originalStartOffset - newStartOffset;
        final newLength = piece.length + size_delta;
        node.piece = new Piece(
            piece.bufferIndex,
            newStart,
            piece.end,
            newLineFeedCnt,
            newLength
        );

        RbTreeBase.updateTreeMetadata(this, node, size_delta, lf_delta);
    }

    function shrinkNode(node:TreeNode, start:BufferCursor, end:BufferCursor):Void {
        final piece = node.piece;
        final originalStartPos = piece.start;
        final originalEndPos = piece.end;

        // old piece, originalStartPos, start
        final oldLength = piece.length;
        final oldLFCnt = piece.lineFeedCnt;
        final newEnd = start;
        final newLineFeedCnt = this.getLineFeedCnt(piece.bufferIndex, piece.start, newEnd);
        final newLength = this.offsetInBuffer(piece.bufferIndex, start) - this.offsetInBuffer(piece.bufferIndex, originalStartPos);

        node.piece = new Piece(
            piece.bufferIndex,
            piece.start,
            newEnd,
            newLineFeedCnt,
            newLength
        );

        RbTreeBase.updateTreeMetadata(this, node, newLength - oldLength, newLineFeedCnt - oldLFCnt);

        // new right piece, end, originalEndPos
        final newPiece = new Piece(
            piece.bufferIndex,
            end,
            originalEndPos,
            this.getLineFeedCnt(piece.bufferIndex, end, originalEndPos),
            this.offsetInBuffer(piece.bufferIndex, originalEndPos) - this.offsetInBuffer(piece.bufferIndex, end)
        );

        final newNode = this.rbInsertRight(node, newPiece);
        this.validateCRLFWithPrevNode(newNode);
    }

    function appendToNode(node:TreeNode, value:String):Void {
        if (this.adjustCarriageReturnFromNext(value, node)) {
            value += '\n';
        }

        final hitCRLF = this.shouldCheckCRLF() && this.startWithLFString(value) && this.endWithCR(node);
        final changeBuffer = this._buffers[this._changeBufferIndex];
        final startOffset = changeBuffer.buffer.length;
        changeBuffer.buffer += value;
        final lineStarts = createLineStartsFast(value, false);
        final changeLineStarts = changeBuffer.lineStarts;
        if (hitCRLF) {
            final prevStartOffset = changeLineStarts[changeLineStarts.length - 2];
            changeLineStarts.pop();
            // _lastChangeBufferPos is already wrong
            this._lastChangeBufferPos = new BufferCursor(this._lastChangeBufferPos.line - 1, startOffset - prevStartOffset);
        }

        // `lineStarts[i] += startOffset` and `concat(lineStarts.slice(1))`:
        // appended in place
        for (i in 1...lineStarts.length) {
            changeLineStarts.push(lineStarts[i] + startOffset);
        }
        final endIndex = changeLineStarts.length - 1;
        final endColumn = changeBuffer.buffer.length - changeLineStarts[endIndex];
        final newEnd = new BufferCursor(endIndex, endColumn);
        final newLength = node.piece.length + value.length;
        final oldLineFeedCnt = node.piece.lineFeedCnt;
        final newLineFeedCnt = this.getLineFeedCnt(this._changeBufferIndex, node.piece.start, newEnd);
        final lf_delta = newLineFeedCnt - oldLineFeedCnt;

        node.piece = new Piece(
            node.piece.bufferIndex,
            node.piece.start,
            newEnd,
            newLineFeedCnt,
            newLength
        );

        this._lastChangeBufferPos = newEnd;
        RbTreeBase.updateTreeMetadata(this, node, value.length, lf_delta);
    }

    function nodeAt(offset:Int):NodePosition {
        var x = this.root;
        final cache = this._searchCache.get(offset);
        if (cache != null) {
            return new NodePosition(cache.node, offset - cache.nodeStartOffset, cache.nodeStartOffset);
        }

        var nodeStartOffset = 0;

        while (x != SENTINEL) {
            if (x.size_left > offset) {
                x = x.left;
            }
            else if (x.size_left + x.piece.length >= offset) {
                nodeStartOffset += x.size_left;
                final ret = new NodePosition(x, offset - x.size_left, nodeStartOffset);
                this._searchCache.set(x, nodeStartOffset, 0);
                return ret;
            }
            else {
                offset -= x.size_left + x.piece.length;
                nodeStartOffset += x.size_left + x.piece.length;
                x = x.right;
            }
        }

        return null;
    }

    /**
     * Fills and returns `out` when given (no allocation).
     */
    function nodeAt2(lineNumber:Int, column:Int, ?out:NodePosition):NodePosition {
        var x = this.root;
        var nodeStartOffset = 0;

        while (x != SENTINEL) {
            if (x.left != SENTINEL && x.lf_left >= lineNumber - 1) {
                x = x.left;
            }
            else if (x.lf_left + x.piece.lineFeedCnt > lineNumber - 1) {
                final prevAccumualtedValue = this.getAccumulatedValue(x, lineNumber - x.lf_left - 2);
                final accumulatedValue = this.getAccumulatedValue(x, lineNumber - x.lf_left - 1);
                nodeStartOffset += x.size_left;

                return makeNodePosition(out, x, Std.int(Math.min(prevAccumualtedValue + column - 1, accumulatedValue)), nodeStartOffset);
            }
            else if (x.lf_left + x.piece.lineFeedCnt == lineNumber - 1) {
                final prevAccumualtedValue = this.getAccumulatedValue(x, lineNumber - x.lf_left - 2);
                if (prevAccumualtedValue + column - 1 <= x.piece.length) {
                    return makeNodePosition(out, x, prevAccumualtedValue + column - 1, nodeStartOffset);
                }
                else {
                    column -= x.piece.length - prevAccumualtedValue;
                    break;
                }
            }
            else {
                lineNumber -= x.lf_left + x.piece.lineFeedCnt;
                nodeStartOffset += x.size_left + x.piece.length;
                x = x.right;
            }
        }

        // search in order, to find the node contains position.column
        x = x.next(SENTINEL);
        while (x != SENTINEL) {

            if (x.piece.lineFeedCnt > 0) {
                final accumulatedValue = this.getAccumulatedValue(x, 0);
                final nodeStartOffset = this.offsetOfNode(x);
                return makeNodePosition(out, x, Std.int(Math.min(column - 1, accumulatedValue)), nodeStartOffset);
            }
            else {
                if (x.piece.length >= column - 1) {
                    final nodeStartOffset = this.offsetOfNode(x);
                    return makeNodePosition(out, x, column - 1, nodeStartOffset);
                }
                else {
                    column -= x.piece.length;
                }
            }

            x = x.next(SENTINEL);
        }

        return null;
    }

    static inline function makeNodePosition(out:Null<NodePosition>, node:TreeNode, remainder:Int, nodeStartOffset:Int):NodePosition {
        if (out != null) {
            out.node = node;
            out.remainder = remainder;
            out.nodeStartOffset = nodeStartOffset;
            return out;
        }
        return new NodePosition(node, remainder, nodeStartOffset);
    }

    function nodeCharCodeAt(node:TreeNode, offset:Int):Int {
        if (node.piece.lineFeedCnt < 1) {
            return -1;
        }
        final buffer = this._buffers[node.piece.bufferIndex];
        final newOffset = this.offsetInBuffer(node.piece.bufferIndex, node.piece.start) + offset;
        return charCodeAt(buffer.buffer, newOffset);
    }

    function offsetOfNode(node:Null<TreeNode>):Int {
        if (node == null) {
            return 0;
        }
        var pos = node.size_left;
        while (node != this.root) {
            if (node.parent.right == node) {
                pos += node.parent.size_left + node.parent.piece.length;
            }

            node = node.parent;
        }

        return pos;
    }

    // #endregion

    // #region CRLF

    inline function shouldCheckCRLF():Bool {
        return !(this._EOLNormalized && this._EOL == '\n');
    }

    /**
     * `startWithLF(val: string)`.
     */
    inline function startWithLFString(val:String):Bool {
        return val.length > 0 && StringTools.fastCodeAt(val, 0) == 10;
    }

    /**
     * `startWithLF(val: TreeNode)`.
     */
    function startWithLF(val:TreeNode):Bool {
        if (val == SENTINEL || val.piece.lineFeedCnt == 0) {
            return false;
        }

        final piece = val.piece;
        final lineStarts = this._buffers[piece.bufferIndex].lineStarts;
        final line = piece.start.line;
        final startOffset = lineStarts[line] + piece.start.column;
        if (line == lineStarts.length - 1) {
            // last line, so there is no line feed at the end of this line
            return false;
        }
        final nextLineOffset = lineStarts[line + 1];
        if (nextLineOffset > startOffset + 1) {
            return false;
        }
        return charCodeAt(this._buffers[piece.bufferIndex].buffer, startOffset) == 10;
    }

    /**
     * `endWithCR(val: string)`.
     */
    inline function endWithCRString(val:String):Bool {
        return val.length > 0 && StringTools.fastCodeAt(val, val.length - 1) == 13;
    }

    /**
     * `endWithCR(val: TreeNode)`.
     */
    function endWithCR(val:TreeNode):Bool {
        if (val == SENTINEL || val.piece.lineFeedCnt == 0) {
            return false;
        }

        return this.nodeCharCodeAt(val, val.piece.length - 1) == 13;
    }

    function validateCRLFWithPrevNode(nextNode:TreeNode):Void {
        if (this.shouldCheckCRLF() && this.startWithLF(nextNode)) {
            final node = nextNode.prev(SENTINEL);
            if (this.endWithCR(node)) {
                this.fixCRLF(node, nextNode);
            }
        }
    }

    function validateCRLFWithNextNode(node:TreeNode):Void {
        if (this.shouldCheckCRLF() && this.endWithCR(node)) {
            final nextNode = node.next(SENTINEL);
            if (this.startWithLF(nextNode)) {
                this.fixCRLF(node, nextNode);
            }
        }
    }

    function fixCRLF(prev:TreeNode, next:TreeNode):Void {
        final nodesToDel:Array<TreeNode> = [];
        // update node
        final lineStarts = this._buffers[prev.piece.bufferIndex].lineStarts;
        var newEnd:BufferCursor;
        if (prev.piece.end.column == 0) {
            // it means, last line ends with \r, not \r\n
            newEnd = new BufferCursor(prev.piece.end.line - 1, lineStarts[prev.piece.end.line] - lineStarts[prev.piece.end.line - 1] - 1);
        }
        else {
            // \r\n
            newEnd = new BufferCursor(prev.piece.end.line, prev.piece.end.column - 1);
        }

        final prevNewLength = prev.piece.length - 1;
        final prevNewLFCnt = prev.piece.lineFeedCnt - 1;
        prev.piece = new Piece(
            prev.piece.bufferIndex,
            prev.piece.start,
            newEnd,
            prevNewLFCnt,
            prevNewLength
        );

        RbTreeBase.updateTreeMetadata(this, prev, - 1, -1);
        if (prev.piece.length == 0) {
            nodesToDel.push(prev);
        }

        // update nextNode
        final newStart = new BufferCursor(next.piece.start.line + 1, 0);
        final newLength = next.piece.length - 1;
        final newLineFeedCnt = this.getLineFeedCnt(next.piece.bufferIndex, newStart, next.piece.end);
        next.piece = new Piece(
            next.piece.bufferIndex,
            newStart,
            next.piece.end,
            newLineFeedCnt,
            newLength
        );

        RbTreeBase.updateTreeMetadata(this, next, - 1, -1);
        if (next.piece.length == 0) {
            nodesToDel.push(next);
        }

        // create new piece which contains \r\n
        final pieces = this.createNewPieces('\r\n');
        this.rbInsertRight(prev, pieces[0]);
        // delete empty nodes

        for (i in 0...nodesToDel.length) {
            RbTreeBase.rbDelete(this, nodesToDel[i]);
        }
    }

    function adjustCarriageReturnFromNext(value:String, node:TreeNode):Bool {
        if (this.shouldCheckCRLF() && this.endWithCRString(value)) {
            final nextNode = node.next(SENTINEL);
            if (this.startWithLF(nextNode)) {
                // move `\n` forward
                value += '\n';

                if (nextNode.piece.length == 1) {
                    RbTreeBase.rbDelete(this, nextNode);
                }
                else {

                    final piece = nextNode.piece;
                    final newStart = new BufferCursor(piece.start.line + 1, 0);
                    final newLength = piece.length - 1;
                    final newLineFeedCnt = this.getLineFeedCnt(piece.bufferIndex, newStart, piece.end);
                    nextNode.piece = new Piece(
                        piece.bufferIndex,
                        newStart,
                        piece.end,
                        newLineFeedCnt,
                        newLength
                    );

                    RbTreeBase.updateTreeMetadata(this, nextNode, -1, -1);
                }
                return true;
            }
        }

        return false;
    }

    // #endregion

    // #endregion

    // #region Tree operations

    public function iterate(node:TreeNode, callback:(node:TreeNode) -> Bool):Bool {
        if (node == SENTINEL) {
            return callback(SENTINEL);
        }

        final leftRet = this.iterate(node.left, callback);
        if (!leftRet) {
            return leftRet;
        }

        return callback(node) && this.iterate(node.right, callback);
    }

    function getNodeContent(node:TreeNode):String {
        if (node == SENTINEL) {
            return '';
        }
        final buffer = this._buffers[node.piece.bufferIndex];
        final piece = node.piece;
        final startOffset = this.offsetInBuffer(piece.bufferIndex, piece.start);
        final endOffset = this.offsetInBuffer(piece.bufferIndex, piece.end);
        final currentContent = buffer.buffer.substring(startOffset, endOffset);
        return currentContent;
    }

    public function getPieceContent(piece:Piece):String {
        final buffer = this._buffers[piece.bufferIndex];
        final startOffset = this.offsetInBuffer(piece.bufferIndex, piece.start);
        final endOffset = this.offsetInBuffer(piece.bufferIndex, piece.end);
        final currentContent = buffer.buffer.substring(startOffset, endOffset);
        return currentContent;
    }

    /**
     *      node              node
     *     /  \              /  \
     *    a   b    <----   a    b
     *                         /
     *                        z
     */
    function rbInsertRight(node:Null<TreeNode>, p:Piece):TreeNode {
        final z = new TreeNode(p, NodeColor.Red);
        z.left = SENTINEL;
        z.right = SENTINEL;
        z.parent = SENTINEL;
        z.size_left = 0;
        z.lf_left = 0;

        final x = this.root;
        if (x == SENTINEL) {
            this.root = z;
            z.color = NodeColor.Black;
        }
        else if (node.right == SENTINEL) {
            node.right = z;
            z.parent = node;
        }
        else {
            final nextNode = RbTreeBase.leftest(node.right, SENTINEL);
            nextNode.left = z;
            z.parent = nextNode;
        }

        RbTreeBase.fixInsert(this, z);
        return z;
    }

    /**
     *      node              node
     *     /  \              /  \
     *    a   b     ---->   a    b
     *                       \
     *                        z
     */
    function rbInsertLeft(node:Null<TreeNode>, p:Piece):TreeNode {
        final z = new TreeNode(p, NodeColor.Red);
        z.left = SENTINEL;
        z.right = SENTINEL;
        z.parent = SENTINEL;
        z.size_left = 0;
        z.lf_left = 0;

        if (this.root == SENTINEL) {
            this.root = z;
            z.color = NodeColor.Black;
        }
        else if (node.left == SENTINEL) {
            node.left = z;
            z.parent = node;
        }
        else {
            final prevNode = RbTreeBase.righttest(node.left, SENTINEL); // a
            prevNode.right = z;
            z.parent = prevNode;
        }

        RbTreeBase.fixInsert(this, z);
        return z;
    }

    function getContentOfSubTree(node:TreeNode):String {
        final str = new StringBuf();

        this.iterate(node, node -> {
            str.add(this.getNodeContent(node));
            return true;
        });

        return str.toString();
    }

    // #endregion

}
