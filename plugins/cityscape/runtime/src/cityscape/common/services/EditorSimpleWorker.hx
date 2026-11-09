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

}
