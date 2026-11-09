// Ported from vscode src/vs/editor/test/common/model/editableTextModelTestUtils.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

import cityscape.base.common.Strings;
import cityscape.common.Model;
import cityscape.common.TextModelEvents;
import cityscape.common.core.EditOperation.ISingleEditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range.IRange;
import cityscape.common.model.PrefixSumComputer;
import cityscape.common.model.TextModel;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

// Classes of this module:
//   EditableTextModelTestUtils (static helpers, not a test case)
//   MirrorTextModel (used by EditableTextModelTest too)

/**
 * Helpers of editableTextModelTestUtils.ts.
 *
 * The assertions are made on the calling test case, given as first argument
 * (`t`), since this is not a `TestCase`.
 */
@:access(testing.TestCase)
class EditableTextModelTestUtils {

    public static function testApplyEditsWithSyncedModels(t:TestCase, original:Array<String>, edits:Array<ISingleEditOperation>, expected:Array<String>, inputEditsAreInvalid:Bool = false):Void {
        final originalStr = original.join('\n');
        final expectedStr = expected.join('\n');

        assertSyncedModels(t, originalStr, (model, assertMirrorModels) -> {
            // Apply edits & collect inverse edits
            final inverseEdits = model.applyEdits(cast edits, true);

            // Assert edits produced expected result
            t.assertDeepEquals(model.getValue(EndOfLinePreference.LF), expectedStr);

            assertMirrorModels();

            // Apply the inverse edits
            final inverseInverseEdits = model.applyEdits(cast inverseEdits, true);

            // Assert the inverse edits brought back model to original state
            t.assertDeepEquals(model.getValue(EndOfLinePreference.LF), originalStr);

            if (!inputEditsAreInvalid) {
                final simplifyEdit = (edit:ISingleEditOperation) -> {
                    return {
                        range: edit.range,
                        text: edit.text,
                        forceMoveMarkers: edit.forceMoveMarkers == true
                    };
                };
                // Assert the inverse of the inverse edits are the original edits
                final inverseInverse:Array<ISingleEditOperation> = cast inverseInverseEdits;
                t.assertDeepEquals(inverseInverse.map(simplifyEdit), edits.map(simplifyEdit));
            }

            assertMirrorModels();
        });
    }

    static function assertOneDirectionLineMapping(t:TestCase, model:TextModel, direction:AssertDocumentLineMappingDirection, msg:String):Void {
        final allText = model.getValue();

        var line = 1, column = 1, previousIsCarriageReturn = false;
        for (offset in 0...(allText.length + 1)) {
            // The position coordinate system cannot express the position between \r and \n
            final position:Position = new Position(line, column + (previousIsCarriageReturn ? -1 : 0));

            if (direction == AssertDocumentLineMappingDirection.OffsetToPosition) {
                final actualPosition = model.getPositionAt(offset);
                t.assertEquals(actualPosition.toString(), position.toString(), msg + ' - getPositionAt mismatch for offset ' + offset);
            }
            else {
                // The position coordinate system cannot express the position between \r and \n
                final expectedOffset:Int = offset + (previousIsCarriageReturn ? -1 : 0);
                final actualOffset = model.getOffsetAt(position);
                t.assertEquals(actualOffset, expectedOffset, msg + ' - getOffsetAt mismatch for position ' + position.toString());
            }

            if (allText.charAt(offset) == '\n') {
                line++;
                column = 1;
            }
            else {
                column++;
            }

            previousIsCarriageReturn = (allText.charAt(offset) == '\r');
        }
    }

    static function assertLineMapping(t:TestCase, model:TextModel, msg:String):Void {
        assertOneDirectionLineMapping(t, model, AssertDocumentLineMappingDirection.PositionToOffset, msg);
        assertOneDirectionLineMapping(t, model, AssertDocumentLineMappingDirection.OffsetToPosition, msg);
    }

    public static function assertSyncedModels(t:TestCase, text:String, callback:(model:TextModel, assertMirrorModels:() -> Void) -> Void, ?setup:(model:TextModel) -> Void):Void {
        final model = createTextModel(text);
        model.setEOL(EndOfLineSequence.LF);
        assertLineMapping(t, model, 'model');

        if (setup != null) {
            setup(model);
            assertLineMapping(t, model, 'model');
        }

        final mirrorModel2 = new MirrorTextModel(null, model.getLinesContent(), model.getEOL(), model.getVersionId());
        var mirrorModel2PrevVersionId = model.getVersionId();

        final disposable = model.onDidChangeContent((e:IModelContentChangedEvent) -> {
            final versionId = e.versionId;
            if (versionId < mirrorModel2PrevVersionId) {
                trace('Model version id did not advance between edits (2)');
            }
            mirrorModel2PrevVersionId = versionId;
            mirrorModel2.onEvents(e);
        });

        final assertMirrorModels = () -> {
            assertLineMapping(t, model, 'model');
            t.assertEquals(mirrorModel2.getText(), model.getValue(), 'mirror model 2 text OK');
            t.assertEquals(mirrorModel2.version, model.getVersionId(), 'mirror model 2 version OK');
        };

        callback(model, assertMirrorModels);

        disposable.dispose();
        model.dispose();
        mirrorModel2.dispose();
    }

}

private enum abstract AssertDocumentLineMappingDirection(Int) {
    var OffsetToPosition = 0;
    var PositionToOffset = 1;
}

// Ported from vscode src/vs/editor/common/model/mirrorTextModel.ts (the part the tests use)
// Public (not private to this module) because editableTextModel.test.ts uses it directly.
// The uri argument is kept for the signature but unused (always null in the tests).
class MirrorTextModel {

    var _uri:Dynamic;
    var _lines:Array<String>;
    var _eol:String;
    var _versionId:Int;
    var _lineStarts:Null<PrefixSumComputer>;
    var _cachedTextValue:Null<String>;

    public function new(uri:Dynamic, lines:Array<String>, eol:String, versionId:Int) {
        this._uri = uri;
        this._lines = lines;
        this._eol = eol;
        this._versionId = versionId;
        this._lineStarts = null;
        this._cachedTextValue = null;
    }

    public function dispose():Void {
        this._lines.resize(0);
    }

    public var version(get, never):Int;
    function get_version():Int {
        return this._versionId;
    }

    public function getText():String {
        if (this._cachedTextValue == null) {
            this._cachedTextValue = this._lines.join(this._eol);
        }
        return this._cachedTextValue;
    }

    public function onEvents(e:IModelContentChangedEvent):Void {
        if (e.eol != null && e.eol.length > 0 && e.eol != this._eol) {
            this._eol = e.eol;
            this._lineStarts = null;
        }

        // Update my lines
        final changes = e.changes;
        for (change in changes) {
            this._acceptDeleteRange(change.range);
            this._acceptInsertText(new Position(change.range.startLineNumber, change.range.startColumn), change.text);
        }

        this._versionId = e.versionId;
        this._cachedTextValue = null;
    }

    function _ensureLineStarts():Void {
        if (this._lineStarts == null) {
            final eolLength = this._eol.length;
            final linesLength = this._lines.length;
            final lineStartValues:Array<Int> = [for (i in 0...linesLength) 0];
            for (i in 0...linesLength) {
                lineStartValues[i] = this._lines[i].length + eolLength;
            }
            this._lineStarts = new PrefixSumComputer(lineStartValues);
        }
    }

    /**
     * All changes to a line's text go through this method
     */
    function _setLineText(lineIndex:Int, newValue:String):Void {
        this._lines[lineIndex] = newValue;
        if (this._lineStarts != null) {
            // update prefix sum
            this._lineStarts.setValue(lineIndex, this._lines[lineIndex].length + this._eol.length);
        }
    }

    function _acceptDeleteRange(range:IRange):Void {

        if (range.startLineNumber == range.endLineNumber) {
            if (range.startColumn == range.endColumn) {
                // Nothing to delete
                return;
            }
            // Delete text on the affected line
            this._setLineText(range.startLineNumber - 1,
                this._lines[range.startLineNumber - 1].substring(0, range.startColumn - 1)
                + this._lines[range.startLineNumber - 1].substring(range.endColumn - 1)
            );
            return;
        }

        // Take remaining text on last line and append it to remaining text on first line
        this._setLineText(range.startLineNumber - 1,
            this._lines[range.startLineNumber - 1].substring(0, range.startColumn - 1)
            + this._lines[range.endLineNumber - 1].substring(range.endColumn - 1)
        );

        // Delete middle lines
        this._lines.splice(range.startLineNumber, range.endLineNumber - range.startLineNumber);
        if (this._lineStarts != null) {
            // update prefix sum
            this._lineStarts.removeValues(range.startLineNumber, range.endLineNumber - range.startLineNumber);
        }
    }

    function _acceptInsertText(position:Position, insertText:String):Void {
        if (insertText.length == 0) {
            // Nothing to insert
            return;
        }
        final insertLines = Strings.splitLines(insertText);
        if (insertLines.length == 1) {
            // Inserting text on one line
            this._setLineText(position.lineNumber - 1,
                this._lines[position.lineNumber - 1].substring(0, position.column - 1)
                + insertLines[0]
                + this._lines[position.lineNumber - 1].substring(position.column - 1)
            );
            return;
        }

        // Append overflowing text from first line to the end of text to insert
        insertLines[insertLines.length - 1] += this._lines[position.lineNumber - 1].substring(position.column - 1);

        // Delete overflowing text from first line and insert text on first line
        this._setLineText(position.lineNumber - 1,
            this._lines[position.lineNumber - 1].substring(0, position.column - 1)
            + insertLines[0]
        );

        // Insert new lines & store lengths
        final newLengths:Array<Int> = [for (i in 0...(insertLines.length - 1)) 0];
        for (i in 1...insertLines.length) {
            this._lines.insert(position.lineNumber + i - 1, insertLines[i]);
            newLengths[i - 1] = insertLines[i].length + this._eol.length;
        }

        if (this._lineStarts != null) {
            // update prefix sum
            this._lineStarts.insertValues(position.lineNumber, newLengths);
        }
    }

}
