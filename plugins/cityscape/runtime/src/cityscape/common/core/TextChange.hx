// Ported from vscode src/vs/editor/common/core/textChange.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import haxe.io.Bytes;

/**
 * A change of the text buffer, by offsets (undo/redo elements).
 */
class TextChange {

    public var oldLength(get, never):Int;
    inline function get_oldLength():Int {
        return this.oldText.length;
    }

    public var oldEnd(get, never):Int;
    inline function get_oldEnd():Int {
        return this.oldPosition + this.oldText.length;
    }

    public var newLength(get, never):Int;
    inline function get_newLength():Int {
        return this.newText.length;
    }

    public var newEnd(get, never):Int;
    inline function get_newEnd():Int {
        return this.newPosition + this.newText.length;
    }

    public final oldPosition:Int;

    public final oldText:String;

    public final newPosition:Int;

    public final newText:String;

    public function new(oldPosition:Int, oldText:String, newPosition:Int, newText:String) {
        this.oldPosition = oldPosition;
        this.oldText = oldText;
        this.newPosition = newPosition;
        this.newText = newText;
    }

    static function escapeNewLine(str:String):String {
        return StringTools.replace(StringTools.replace(str, '\n', '\\n'), '\r', '\\r');
    }

    public function toString():String {
        if (this.oldText.length == 0) {
            return '(insert@${this.oldPosition} "${escapeNewLine(this.newText)}")';
        }
        if (this.newText.length == 0) {
            return '(delete@${this.oldPosition} "${escapeNewLine(this.oldText)}")';
        }
        return '(replace@${this.oldPosition} "${escapeNewLine(this.oldText)}" with "${escapeNewLine(this.newText)}")';
    }

    static inline function _writeStringSize(str:String):Int {
        return (
            4 + 2 * str.length
        );
    }

    static function _writeString(b:Bytes, str:String, offset:Int):Int {
        final len = str.length;
        BufferUtils.writeUInt32BE(b, len, offset);
        offset += 4;
        for (i in 0...len) {
            BufferUtils.writeUInt16LE(b, StringTools.fastCodeAt(str, i), offset);
            offset += 2;
        }
        return offset;
    }

    static function _readString(b:Bytes, offset:Int):String {
        final len = BufferUtils.readUInt32BE(b, offset);
        offset += 4;
        return BufferUtils.decodeUTF16LE(b, offset, len);
    }

    public function writeSize():Int {
        return (
            4 // oldPosition
            + 4 // newPosition
            + TextChange._writeStringSize(this.oldText)
            + TextChange._writeStringSize(this.newText)
        );
    }

    public function write(b:Bytes, offset:Int):Int {
        BufferUtils.writeUInt32BE(b, this.oldPosition, offset);
        offset += 4;
        BufferUtils.writeUInt32BE(b, this.newPosition, offset);
        offset += 4;
        offset = TextChange._writeString(b, this.oldText, offset);
        offset = TextChange._writeString(b, this.newText, offset);
        return offset;
    }

    public static function read(b:Bytes, offset:Int, dest:Array<TextChange>):Int {
        final oldPosition = BufferUtils.readUInt32BE(b, offset);
        offset += 4;
        final newPosition = BufferUtils.readUInt32BE(b, offset);
        offset += 4;
        final oldText = TextChange._readString(b, offset);
        offset += TextChange._writeStringSize(oldText);
        final newText = TextChange._readString(b, offset);
        offset += TextChange._writeStringSize(newText);
        dest.push(new TextChange(oldPosition, oldText, newPosition, newText));
        return offset;
    }

    public static function compressConsecutiveTextChanges(prevEdits:Null<Array<TextChange>>, currEdits:Array<TextChange>):Array<TextChange> {
        if (prevEdits == null || prevEdits.length == 0) {
            return currEdits;
        }
        final compressor = new TextChangeCompressor(prevEdits, currEdits);
        return compressor.compress();
    }

}

/**
 * The byte functions of buffer.ts and stringBuilder.ts that the edit stack
 * serialization uses.
 */
class BufferUtils {

    public static inline function writeUInt32BE(destination:Bytes, value:Int, offset:Int):Void {
        destination.set(offset + 3, value);
        value = value >>> 8;
        destination.set(offset + 2, value);
        value = value >>> 8;
        destination.set(offset + 1, value);
        value = value >>> 8;
        destination.set(offset, value);
    }

    public static inline function readUInt32BE(source:Bytes, offset:Int):Int {
        // The values written are positive Int32 (offsets and lengths)
        return (
            (source.get(offset) << 24)
            | (source.get(offset + 1) << 16)
            | (source.get(offset + 2) << 8)
            | source.get(offset + 3)
        );
    }

    public static inline function writeUInt16LE(destination:Bytes, value:Int, offset:Int):Void {
        destination.set(offset + 0, value & 0xFF);
        destination.set(offset + 1, (value >>> 8) & 0xFF);
    }

    public static inline function readUInt16LE(source:Bytes, offset:Int):Int {
        return (
            ((source.get(offset + 0) << 0) >>> 0) |
            ((source.get(offset + 1) << 8) >>> 0)
        );
    }

    public static inline function writeUInt8(destination:Bytes, value:Int, offset:Int):Void {
        destination.set(offset, value);
    }

    public static inline function readUInt8(source:Bytes, offset:Int):Int {
        return source.get(offset);
    }

    /**
     * `len` UTF-16 code units, little endian, from `offset`.
     */
    public static function decodeUTF16LE(source:Bytes, offset:Int, len:Int):String {
        final result = new StringBuf();
        var i = 0;
        while (i < len) {
            final chr = readUInt16LE(source, offset);
            offset += 2;
            i++;
            // Join the surrogate pairs (`StringBuf.addChar` takes code points)
            if (chr >= 0xD800 && chr <= 0xDBFF && i < len) {
                final next = readUInt16LE(source, offset);
                if (next >= 0xDC00 && next <= 0xDFFF) {
                    offset += 2;
                    i++;
                    result.addChar(((chr - 0xD800) << 10) + (next - 0xDC00) + 0x10000);
                    continue;
                }
            }
            result.addChar(chr);
        }
        return result.toString();
    }

}

class TextChangeCompressor {

    final _prevEdits:Array<TextChange>;
    final _currEdits:Array<TextChange>;

    final _result:Array<TextChange>;
    var _resultLen:Int;

    final _prevLen:Int;
    var _prevDeltaOffset:Int;

    final _currLen:Int;
    var _currDeltaOffset:Int;

    public function new(prevEdits:Array<TextChange>, currEdits:Array<TextChange>) {
        this._prevEdits = prevEdits;
        this._currEdits = currEdits;

        this._result = [];
        this._resultLen = 0;

        this._prevLen = this._prevEdits.length;
        this._prevDeltaOffset = 0;

        this._currLen = this._currEdits.length;
        this._currDeltaOffset = 0;
    }

    public function compress():Array<TextChange> {
        var prevIndex = 0;
        var currIndex = 0;

        var prevEdit = this._getPrev(prevIndex);
        var currEdit = this._getCurr(currIndex);

        while (prevIndex < this._prevLen || currIndex < this._currLen) {

            if (prevEdit == null) {
                this._acceptCurr(currEdit);
                currEdit = this._getCurr(++currIndex);
                continue;
            }

            if (currEdit == null) {
                this._acceptPrev(prevEdit);
                prevEdit = this._getPrev(++prevIndex);
                continue;
            }

            if (currEdit.oldEnd <= prevEdit.newPosition) {
                this._acceptCurr(currEdit);
                currEdit = this._getCurr(++currIndex);
                continue;
            }

            if (prevEdit.newEnd <= currEdit.oldPosition) {
                this._acceptPrev(prevEdit);
                prevEdit = this._getPrev(++prevIndex);
                continue;
            }

            if (currEdit.oldPosition < prevEdit.newPosition) {
                final e = TextChangeCompressor._splitCurr(currEdit, prevEdit.newPosition - currEdit.oldPosition);
                this._acceptCurr(e[0]);
                currEdit = e[1];
                continue;
            }

            if (prevEdit.newPosition < currEdit.oldPosition) {
                final e = TextChangeCompressor._splitPrev(prevEdit, currEdit.oldPosition - prevEdit.newPosition);
                this._acceptPrev(e[0]);
                prevEdit = e[1];
                continue;
            }

            // At this point, currEdit.oldPosition === prevEdit.newPosition

            var mergePrev:TextChange;
            var mergeCurr:TextChange;

            if (currEdit.oldEnd == prevEdit.newEnd) {
                mergePrev = prevEdit;
                mergeCurr = currEdit;
                prevEdit = this._getPrev(++prevIndex);
                currEdit = this._getCurr(++currIndex);
            }
            else if (currEdit.oldEnd < prevEdit.newEnd) {
                final e = TextChangeCompressor._splitPrev(prevEdit, currEdit.oldLength);
                mergePrev = e[0];
                mergeCurr = currEdit;
                prevEdit = e[1];
                currEdit = this._getCurr(++currIndex);
            }
            else {
                final e = TextChangeCompressor._splitCurr(currEdit, prevEdit.newLength);
                mergePrev = prevEdit;
                mergeCurr = e[0];
                prevEdit = this._getPrev(++prevIndex);
                currEdit = e[1];
            }

            this._result[this._resultLen++] = new TextChange(
                mergePrev.oldPosition,
                mergePrev.oldText,
                mergeCurr.newPosition,
                mergeCurr.newText
            );
            this._prevDeltaOffset += mergePrev.newLength - mergePrev.oldLength;
            this._currDeltaOffset += mergeCurr.newLength - mergeCurr.oldLength;
        }

        final merged = TextChangeCompressor._merge(this._result);
        final cleaned = TextChangeCompressor._removeNoOps(merged);
        return cleaned;
    }

    function _acceptCurr(currEdit:TextChange):Void {
        this._result[this._resultLen++] = TextChangeCompressor._rebaseCurr(this._prevDeltaOffset, currEdit);
        this._currDeltaOffset += currEdit.newLength - currEdit.oldLength;
    }

    function _getCurr(currIndex:Int):Null<TextChange> {
        return (currIndex < this._currLen ? this._currEdits[currIndex] : null);
    }

    function _acceptPrev(prevEdit:TextChange):Void {
        this._result[this._resultLen++] = TextChangeCompressor._rebasePrev(this._currDeltaOffset, prevEdit);
        this._prevDeltaOffset += prevEdit.newLength - prevEdit.oldLength;
    }

    function _getPrev(prevIndex:Int):Null<TextChange> {
        return (prevIndex < this._prevLen ? this._prevEdits[prevIndex] : null);
    }

    static function _rebaseCurr(prevDeltaOffset:Int, currEdit:TextChange):TextChange {
        return new TextChange(
            currEdit.oldPosition - prevDeltaOffset,
            currEdit.oldText,
            currEdit.newPosition,
            currEdit.newText
        );
    }

    static function _rebasePrev(currDeltaOffset:Int, prevEdit:TextChange):TextChange {
        return new TextChange(
            prevEdit.oldPosition,
            prevEdit.oldText,
            prevEdit.newPosition + currDeltaOffset,
            prevEdit.newText
        );
    }

    static function _splitPrev(edit:TextChange, offset:Int):Array<TextChange> {
        final preText = edit.newText.substr(0, offset);
        final postText = edit.newText.substr(offset);

        return [
            new TextChange(
                edit.oldPosition,
                edit.oldText,
                edit.newPosition,
                preText
            ),
            new TextChange(
                edit.oldEnd,
                '',
                edit.newPosition + offset,
                postText
            )
        ];
    }

    static function _splitCurr(edit:TextChange, offset:Int):Array<TextChange> {
        final preText = edit.oldText.substr(0, offset);
        final postText = edit.oldText.substr(offset);

        return [
            new TextChange(
                edit.oldPosition,
                preText,
                edit.newPosition,
                edit.newText
            ),
            new TextChange(
                edit.oldPosition + offset,
                postText,
                edit.newEnd,
                ''
            )
        ];
    }

    static function _merge(edits:Array<TextChange>):Array<TextChange> {
        if (edits.length == 0) {
            return edits;
        }

        final result:Array<TextChange> = [];
        var resultLen = 0;

        var prev = edits[0];
        for (i in 1...edits.length) {
            final curr = edits[i];

            if (prev.oldEnd == curr.oldPosition) {
                // Merge into `prev`
                prev = new TextChange(
                    prev.oldPosition,
                    prev.oldText + curr.oldText,
                    prev.newPosition,
                    prev.newText + curr.newText
                );
            }
            else {
                result[resultLen++] = prev;
                prev = curr;
            }
        }
        result[resultLen++] = prev;

        return result;
    }

    static function _removeNoOps(edits:Array<TextChange>):Array<TextChange> {
        if (edits.length == 0) {
            return edits;
        }

        final result:Array<TextChange> = [];
        var resultLen = 0;

        for (i in 0...edits.length) {
            final edit = edits[i];

            if (edit.oldText == edit.newText) {
                continue;
            }
            result[resultLen++] = edit;
        }

        return result;
    }

}
