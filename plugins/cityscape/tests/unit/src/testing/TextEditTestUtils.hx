// Ported from vscode src/vs/editor/common/core/textEdit.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package testing;

import cityscape.common.core.Position;
import cityscape.common.core.Range;

/**
 * The parts of textEdit.ts the diff tests use (`TextEdit.normalize`,
 * `apply`, `ArrayText`), not ported in the runtime yet.
 */
class TextEdit {

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

    public function apply(text:ArrayText):String {
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
        final r = rangeFromPositions(lastEditEnd, text.endPositionExclusive());
        if (!r.isEmpty()) {
            result.add(text.getValueOfRange(r));
        }
        return result.toString();
    }

    static function rangeFromPositions(start:Position, end:Position):Range {
        if (start.lineNumber == end.lineNumber && start.column == cityscape.common.diff.RangeMapping.LineRangeMapping.MAX_COLUMN) {
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

}

class ArrayText {

    final lines:Array<String>;

    public function new(lines:Array<String>) {
        this.lines = lines;
    }

    public function getValueOfRange(range:Range):String {
        if (range.startLineNumber == range.endLineNumber) {
            return lines[range.startLineNumber - 1].substring(range.startColumn - 1, range.endColumn - 1);
        }
        var result = lines[range.startLineNumber - 1].substring(range.startColumn - 1);
        for (i in range.startLineNumber + 1...range.endLineNumber) {
            result += '\n' + lines[i - 1];
        }
        result += '\n' + lines[range.endLineNumber - 1].substring(0, range.endColumn - 1);
        return result;
    }

    public function endPositionExclusive():Position {
        final lastLine = lines[lines.length - 1];
        // TextLength(lineCount - 1, lastLine.length).addToPosition(1, 1)
        return new Position(lines.length, lastLine.length + 1);
    }

}
