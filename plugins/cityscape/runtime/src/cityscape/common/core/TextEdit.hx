// Ported from vscode src/vs/editor/common/core/textEdit.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.common.core.EditOperation.ISingleEditOperation;
import cityscape.common.core.PositionToOffset.PositionOffsetTransformer;

/**
 * Edits sorted by range, not overlapping (Monaco's `TextEdit`).
 * Not ported yet: `mapPosition`, `mapRange`, `inverseMapPosition`,
 * `inverseMapRange` (nothing uses them).
 */
class TextEdit {

    public static function single(originalRange:Range, newText:String):TextEdit {
        return new TextEdit([new SingleTextEdit(originalRange, newText)]);
    }

    public final edits:Array<SingleTextEdit>;

    public function new(edits:Array<SingleTextEdit>) {
        this.edits = edits;
    }

    /**
     * Joins touching edits and removes empty edits.
     */
    public function normalize():TextEdit {
        final edits:Array<SingleTextEdit> = [];
        for (edit in this.edits) {
            if (edits.length > 0 && edits[edits.length - 1].range.getEndPosition().equals(edit.range.getStartPosition())) {
                final last = edits[edits.length - 1];
                edits[edits.length - 1] = new SingleTextEdit(last.range.plusRange(edit.range), last.text + edit.text);
            }
            else if (!edit.isEmpty) {
                edits.push(edit);
            }
        }
        return new TextEdit(edits);
    }

    public function apply(text:AbstractText):String {
        final result = new StringBuf();
        var lastEditEnd = new Position(1, 1);
        for (edit in this.edits) {
            final editRange = edit.range;
            final editStart = editRange.getStartPosition();
            final editEnd = editRange.getEndPosition();

            final r = rangeFromPositions(lastEditEnd, editStart);
            if (!r.isEmpty()) {
                result.add(text.getValueOfRange(r));
            }
            result.add(edit.text);
            lastEditEnd = editEnd;
        }
        final r = rangeFromPositions(lastEditEnd, text.endPositionExclusive);
        if (!r.isEmpty()) {
            result.add(text.getValueOfRange(r));
        }
        return result.toString();
    }

    public function applyToString(str:String):String {
        final strText = new StringText(str);
        return this.apply(strText);
    }

    public function inverse(doc:AbstractText):TextEdit {
        final ranges = this.getNewRanges();
        return new TextEdit([for (idx in 0...this.edits.length) new SingleTextEdit(ranges[idx], doc.getValueOfRange(this.edits[idx].range))]);
    }

    public function getNewRanges():Array<Range> {
        final newRanges:Array<Range> = [];
        var previousEditEndLineNumber = 0;
        var lineOffset = 0;
        var columnOffset = 0;
        for (edit in this.edits) {
            final textLength = TextLength.ofText(edit.text);
            final newRangeStart = new Position(
                edit.range.startLineNumber + lineOffset,
                edit.range.startColumn + (edit.range.startLineNumber == previousEditEndLineNumber ? columnOffset : 0)
            );
            final newRange = textLength.createRange(newRangeStart);
            newRanges.push(newRange);
            lineOffset = newRange.endLineNumber - edit.range.endLineNumber;
            columnOffset = newRange.endColumn - edit.range.endColumn;
            previousEditEndLineNumber = edit.range.endLineNumber;
        }
        return newRanges;
    }

    static function rangeFromPositions(start:Position, end:Position):Range {
        if (start.lineNumber == end.lineNumber && start.column == cityscape.common.config.EditorOptions.MAX_SAFE_SMALL_INTEGER) {
            return Range.fromPositions(end, end);
        }
        else if (!start.isBeforeOrEqual(end)) {
            throw 'start must be before end';
        }
        return new Range(start.lineNumber, start.column, end.lineNumber, end.column);
    }

}

class SingleTextEdit {

    public final range:Range;
    public final text:String;

    public function new(range:Range, text:String) {
        this.range = range;
        this.text = text;
    }

    public var isEmpty(get, never):Bool;
    function get_isEmpty():Bool {
        return this.range.isEmpty() && this.text.length == 0;
    }

    public static function equals(first:SingleTextEdit, second:SingleTextEdit):Bool {
        return first.range.equalsRange(second.range) && first.text == second.text;
    }

    public function toSingleEditOperation():ISingleEditOperation {
        return {
            range: this.range,
            text: this.text,
        };
    }

    public function toString():String {
        return 'SingleTextEdit(' + this.range.toString() + ', ' + haxe.Json.stringify(this.text) + ')';
    }

}

class AbstractText {

    function new() {}

    public function getValueOfRange(range:Range):String {
        throw 'abstract';
    }

    public var length(get, never):TextLength;
    function get_length():TextLength {
        throw 'abstract';
    }

    public var endPositionExclusive(get, never):Position;
    function get_endPositionExclusive():Position {
        return this.length.addToPosition(new Position(1, 1));
    }

    public function getValue():String {
        return this.getValueOfRange(this.length.toRange());
    }

}

class LineBasedText extends AbstractText {

    final _getLineContent:(lineNumber:Int) -> String;
    final _lineCount:Int;

    public function new(getLineContent:(lineNumber:Int) -> String, lineCount:Int) {
        super();
        this._getLineContent = getLineContent;
        this._lineCount = lineCount;
    }

    override public function getValueOfRange(range:Range):String {
        if (range.startLineNumber == range.endLineNumber) {
            return this._getLineContent(range.startLineNumber).substring(range.startColumn - 1, range.endColumn - 1);
        }
        var result = this._getLineContent(range.startLineNumber).substring(range.startColumn - 1);
        for (i in range.startLineNumber + 1...range.endLineNumber) {
            result += '\n' + this._getLineContent(i);
        }
        result += '\n' + this._getLineContent(range.endLineNumber).substring(0, range.endColumn - 1);
        return result;
    }

    override function get_length():TextLength {
        final lastLine = this._getLineContent(this._lineCount);
        return new TextLength(this._lineCount - 1, lastLine.length);
    }

}

class ArrayText extends LineBasedText {

    public function new(lines:Array<String>) {
        super(lineNumber -> lines[lineNumber - 1], lines.length);
    }

}

class StringText extends AbstractText {

    final _t:PositionOffsetTransformer;
    public final value:String;

    public function new(value:String) {
        super();
        this.value = value;
        this._t = new PositionOffsetTransformer(value);
    }

    override public function getValueOfRange(range:Range):String {
        return this._t.getOffsetRange(range).substring(this.value);
    }

    override function get_length():TextLength {
        return this._t.textLength;
    }

}
