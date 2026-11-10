// Ported from vscode src/vs/editor/common/services/editorSimpleWorker.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import cityscape.base.common.RegExp;
import cityscape.common.Languages.IInplaceReplaceSupportResult;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.core.WordHelper;
import cityscape.common.languages.supports.InplaceReplaceSupport.BasicInplaceReplace;

/**
 * The parts of Monaco's editor worker (`BaseEditorSimpleWorker`) that
 * Cityscape uses, run synchronously on the text model itself (Monaco
 * mirrors the model in a web worker and calls it through the
 * `IEditorWorkerService`).
 *
 * TODO: the other requests of the worker (diffs, word ranges, links...)
 * come with the contributions that use them.
 */
class EditorSimpleWorker {

    /**
     * Monaco's `$navigateValueSet`: the next (`up`) or previous value of the
     * value set at `range` (numbers, `true`/`false`, visibility keywords...).
     * `wordDefRegExp` is the word definition of the language (Monaco sends
     * its source and flags to the worker).
     */
    public static function navigateValueSet(model:ITextModel, range:IRange, up:Bool, wordDefRegExp:RegExp):Null<IInplaceReplaceSupportResult> {

        if (range.startColumn == range.endColumn) {
            range = {
                startLineNumber: range.startLineNumber,
                startColumn: range.startColumn,
                endLineNumber: range.endLineNumber,
                endColumn: range.endColumn + 1
            };
        }

        final selectionText = getValueInRange(model, range);

        final wordRange = getWordAtPosition(model, range.startLineNumber, range.startColumn, wordDefRegExp);
        if (wordRange == null) {
            return null;
        }
        final word = getValueInRange(model, wordRange);
        final result = BasicInplaceReplace.INSTANCE.navigateValueSet(range, selectionText, wordRange, word, up);
        return result;
    }

    /**
     * The worker's mirror model `getValueInRange`: the lines of the range,
     * cut with `substring` (columns past the end of a line are clamped).
     */
    static function getValueInRange(model:ITextModel, range:IRange):String {
        if (range.startLineNumber == range.endLineNumber) {
            return model.getLineContent(range.startLineNumber).substring(range.startColumn - 1, range.endColumn - 1);
        }
        final lineEnding = model.getEOL();
        final startLineIndex = range.startLineNumber - 1;
        final endLineIndex = range.endLineNumber - 1;
        final resultLines:Array<String> = [];

        resultLines.push(model.getLineContent(startLineIndex + 1).substring(range.startColumn - 1));
        for (i in startLineIndex + 1...endLineIndex) {
            resultLines.push(model.getLineContent(i + 1));
        }
        resultLines.push(model.getLineContent(endLineIndex + 1).substring(0, range.endColumn - 1));

        return resultLines.join(lineEnding);
    }

    /**
     * The worker's mirror model `getWordAtPosition`.
     */
    static function getWordAtPosition(model:ITextModel, lineNumber:Int, column:Int, wordDefinition:RegExp):Null<Range> {
        final wordAtText = WordHelper.getWordAtText(column, WordHelper.ensureValidWordDefinition(wordDefinition), model.getLineContent(lineNumber), 0);
        if (wordAtText != null) {
            return new Range(lineNumber, wordAtText.startColumn, lineNumber, wordAtText.endColumn);
        }
        return null;
    }


    // Links and colors (step 7, cs7-rest-links)

    /**
     * Monaco's `$computeLinks`: the links of the default link computer
     * (http, https and file links in the text).
     */
    public static function computeLinks(model:ITextModel):Null<Array<cityscape.common.Languages.ILink>> {
        if (model == null) {
            return null;
        }
        return cityscape.common.languages.LinkComputer.LinkComputerUtils.computeLinks(new cityscape.common.languages.LinkComputer.TextModelLinkComputerTarget(model));
    }

    /**
     * Monaco's `$computeDefaultDocumentColors`: the CSS like colors of the
     * text (`#rgb`, `#rrggbb`, `rgb()`, `rgba()`, `hsl()`, `hsla()`).
     */
    public static function computeDefaultDocumentColors(model:ITextModel):Null<Array<cityscape.common.Languages.IColorInformation>> {
        if (model == null) {
            return null;
        }
        return cityscape.common.languages.DefaultDocumentColorsComputer.computeDefaultDocumentColors(new cityscape.common.languages.DefaultDocumentColorsComputer.TextModelDocumentColorComputerTarget(model));
    }


    static inline final _diffLimit = 100000;

    /**
     * Monaco's `$computeMoreMinimalEdits`: the edits sorted, the adjacent
     * ones merged, then each one reduced to the characters it changes (a
     * diff of its text with the text it replaces), so that formatting keeps
     * the cursors and decorations of the unchanged text. An end of line
     * change (`eol`) goes last.
     */
    public static function computeMoreMinimalEdits(model:ITextModel, edits:Array<cityscape.common.Languages.TextEdit>, pretty:Bool):Array<cityscape.common.Languages.TextEdit> {
        final result:Array<cityscape.common.Languages.TextEdit> = [];
        var lastEol:Null<cityscape.common.Model.EndOfLineSequence> = null;

        edits = edits.copy();
        haxe.ds.ArraySort.sort(edits, (a, b) -> {
            if (a.range != null && b.range != null) {
                return Range.compareRangesUsingStarts(a.range, b.range);
            }
            // eol only changes should go to the end
            final aRng = a.range != null ? 0 : 1;
            final bRng = b.range != null ? 0 : 1;
            return aRng - bRng;
        });

        // merge adjacent edits (copies: the edits of the caller are not changed)
        edits = [for (e in edits) ({range: e.range, text: e.text, eol: e.eol} : cityscape.common.Languages.TextEdit)];
        var writeIndex = 0;
        for (readIndex in 1...edits.length) {
            if (Range.getEndPositionStatic(edits[writeIndex].range).equals(Range.getStartPositionStatic(edits[readIndex].range))) {
                edits[writeIndex].range = Range.fromPositions(Range.getStartPositionStatic(edits[writeIndex].range), Range.getEndPositionStatic(edits[readIndex].range));
                edits[writeIndex].text += edits[readIndex].text;
            } else {
                writeIndex++;
                edits[writeIndex] = edits[readIndex];
            }
        }
        if (edits.length > 0) {
            edits.resize(writeIndex + 1);
        }

        for (edit in edits) {
            final range = edit.range;
            var text = edit.text;

            if (edit.eol != null) {
                lastEol = edit.eol;
            }

            if (Range.isEmptyStatic(range) && (text == null || text.length == 0)) {
                // empty change
                continue;
            }

            final original = model.getValueInRange(range);
            text = normalizeEol(text != null ? text : '', model.getEOL());

            if (original == text) {
                // noop
                continue;
            }

            // make sure diff won't take too long
            if (Math.max(text.length, original.length) > _diffLimit) {
                result.push({range: range, text: text});
                continue;
            }

            // compute diff between original and edit.text
            final changes = cityscape.base.common.diff.Diff.stringDiff(original, text, pretty);
            final editOffset = model.getOffsetAt(Range.lift(range).getStartPosition());

            for (change in changes) {
                final start = model.getPositionAt(editOffset + change.originalStart);
                final end = model.getPositionAt(editOffset + change.originalStart + change.originalLength);
                final newEdit:cityscape.common.Languages.TextEdit = {
                    text: text.substr(change.modifiedStart, change.modifiedLength),
                    range: {startLineNumber: start.lineNumber, startColumn: start.column, endLineNumber: end.lineNumber, endColumn: end.column}
                };

                if (model.getValueInRange(newEdit.range) != newEdit.text) {
                    result.push(newEdit);
                }
            }
        }

        if (lastEol != null) {
            result.push({eol: lastEol, text: '', range: {startLineNumber: 0, startColumn: 0, endLineNumber: 0, endColumn: 0}});
        }

        return result;
    }

    /**
     * `text.replace(/\r\n|\n|\r/g, eol)`.
     */
    static function normalizeEol(text:String, eol:String):String {
        if (text.indexOf('\r') < 0 && (eol == '\n' || text.indexOf('\n') < 0)) {
            return text;
        }
        final buf = new StringBuf();
        var i = 0;
        final n = text.length;
        while (i < n) {
            final c = StringTools.fastCodeAt(text, i);
            if (c == '\r'.code) {
                buf.add(eol);
                if (i + 1 < n && StringTools.fastCodeAt(text, i + 1) == '\n'.code) {
                    i++;
                }
            } else if (c == '\n'.code) {
                buf.add(eol);
            } else {
                buf.addChar(c);
            }
            i++;
        }
        return buf.toString();
    }

}
