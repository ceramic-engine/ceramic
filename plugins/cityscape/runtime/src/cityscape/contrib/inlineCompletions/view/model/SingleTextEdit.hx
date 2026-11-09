// Ported from vscode src/vs/editor/contrib/inlineCompletions/browser/model/singleTextEdit.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlineCompletions.view.model;

import cityscape.base.common.Strings;
import cityscape.base.common.diff.Diff;
import cityscape.base.common.diff.DiffChange;
import cityscape.common.Model;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.TextEdit.SingleTextEdit;
import cityscape.common.core.TextLength;
import cityscape.contrib.inlineCompletions.view.model.GhostText;
import haxe.extern.EitherType;

/**
 * Module functions of singleTextEdit.ts. Monaco caches the last diff of
 * `cachingDiff` in a module variable; the diff is computed at each call
 * here (no editor state in statics), with the same result.
 */
class SingleTextEditUtils {

    public static function singleTextRemoveCommonPrefix(edit:SingleTextEdit, model:ITextModel, ?validModelRange:Range):SingleTextEdit {
        final modelRange = validModelRange != null ? edit.range.intersectRanges(validModelRange) : edit.range;
        if (modelRange == null) {
            return edit;
        }
        final valueToReplace = model.getValueInRange(modelRange, EndOfLinePreference.LF);
        final commonPrefixLen = Strings.commonPrefixLength(valueToReplace, edit.text);
        final start = TextLength.ofText(valueToReplace.substring(0, commonPrefixLen)).addToPosition(edit.range.getStartPosition());
        final text = edit.text.substring(commonPrefixLen);
        final range = Range.fromPositions(start, edit.range.getEndPosition());
        return new SingleTextEdit(range, text);
    }

    public static function singleTextEditAugments(edit:SingleTextEdit, base:SingleTextEdit):Bool {
        // The augmented completion must replace the base range, but can replace even more
        return StringTools.startsWith(edit.text, base.text) && rangeExtends(edit.range, base.range);
    }

    /**
     * @param mode `'prefix'`, `'subword'` or `'subwordSmart'`
     * @param previewSuffixLength Sets where to split `inlineCompletion.text`.
     * 	If the text is `hello` and the suffix length is 2, the non-preview part is `hel` and the preview-part is `lo`.
     */
    public static function computeGhostText(edit:SingleTextEdit, model:ITextModel, mode:String, ?cursorPosition:Position, previewSuffixLength:Int = 0):Null<GhostText> {
        var e = singleTextRemoveCommonPrefix(edit, model);

        if (e.range.endLineNumber != e.range.startLineNumber) {
            // This edit might span multiple lines, but the first lines must be a common prefix.
            return null;
        }

        final sourceLine = model.getLineContent(e.range.startLineNumber);
        final sourceIndentationLength = Strings.getLeadingWhitespace(sourceLine).length;

        final suggestionTouchesIndentation = e.range.startColumn - 1 <= sourceIndentationLength;
        if (suggestionTouchesIndentation) {
            // source:      ··········[······abc]
            //                         ^^^^^^^^^ inlineCompletion.range
            //              ^^^^^^^^^^ ^^^^^^ sourceIndentationLength
            //                         ^^^^^^ replacedIndentation.length
            //                               ^^^ rangeThatDoesNotReplaceIndentation

            // inlineCompletion.text: '··foo'
            //                         ^^ suggestionAddedIndentationLength

            final suggestionAddedIndentationLength = Strings.getLeadingWhitespace(e.text).length;

            final replacedIndentation = jsSubstring(sourceLine, e.range.startColumn - 1, sourceIndentationLength);

            final startPosition = e.range.getStartPosition();
            final endPosition = e.range.getEndPosition();
            final newStartPosition =
                startPosition.column + replacedIndentation.length <= endPosition.column
                    ? startPosition.delta(0, replacedIndentation.length)
                    : endPosition;
            final rangeThatDoesNotReplaceIndentation = Range.fromPositions(newStartPosition, endPosition);

            final suggestionWithoutIndentationChange =
                StringTools.startsWith(e.text, replacedIndentation)
                    // Adds more indentation without changing existing indentation: We can add ghost text for this
                    ? e.text.substring(replacedIndentation.length)
                    // Changes or removes existing indentation. Only add ghost text for the non-indentation part.
                    : e.text.substring(suggestionAddedIndentationLength);

            e = new SingleTextEdit(rangeThatDoesNotReplaceIndentation, suggestionWithoutIndentationChange);
        }

        // This is a single line string
        final valueToBeReplaced = model.getValueInRange(e.range);

        final changes = cachingDiff(valueToBeReplaced, e.text);

        if (changes == null) {
            // No ghost text in case the diff would be too slow to compute
            return null;
        }

        final lineNumber = e.range.startLineNumber;

        final parts:Array<GhostTextPart> = [];

        if (mode == 'prefix') {
            final filteredChanges = changes.filter(c -> c.originalLength == 0);
            if (filteredChanges.length > 1 || filteredChanges.length == 1 && filteredChanges[0].originalStart != valueToBeReplaced.length) {
                // Prefixes only have a single change.
                return null;
            }
        }

        final previewStartInCompletionText = e.text.length - previewSuffixLength;

        for (c in changes) {
            final insertColumn = e.range.startColumn + c.originalStart + c.originalLength;

            if (mode == 'subwordSmart' && cursorPosition != null && cursorPosition.lineNumber == e.range.startLineNumber && insertColumn < cursorPosition.column) {
                // No ghost text before cursor
                return null;
            }

            if (c.originalLength > 0) {
                return null;
            }

            if (c.modifiedLength == 0) {
                continue;
            }

            final modifiedEnd = c.modifiedStart + c.modifiedLength;
            final nonPreviewTextEnd = Std.int(Math.max(c.modifiedStart, Math.min(modifiedEnd, previewStartInCompletionText)));
            final nonPreviewText = e.text.substring(c.modifiedStart, nonPreviewTextEnd);
            final italicText = e.text.substring(nonPreviewTextEnd, Std.int(Math.max(c.modifiedStart, modifiedEnd)));

            if (nonPreviewText.length > 0) {
                parts.push(new GhostTextPart(insertColumn, nonPreviewText, false));
            }
            if (italicText.length > 0) {
                parts.push(new GhostTextPart(insertColumn, italicText, true));
            }
        }

        return new GhostText(lineNumber, parts);
    }

    /**
     * JavaScript's `substring` (swaps its arguments when `start > end`;
     * Haxe's does too, but clamp negative values the same way).
     */
    static inline function jsSubstring(s:String, start:Int, end:Int):String {
        return s.substring(start < 0 ? 0 : start, end < 0 ? 0 : end);
    }

    static function rangeExtends(extendingRange:Range, rangeToExtend:Range):Bool {
        return rangeToExtend.getStartPosition().equals(extendingRange.getStartPosition())
            && rangeToExtend.getEndPosition().isBeforeOrEqual(extendingRange.getEndPosition());
    }

    static function cachingDiff(originalValue:String, newValue:String):Null<Array<DiffChange>> {
        var changes = smartDiff(originalValue, newValue, true);
        if (changes != null) {
            final deletedChars = deletedCharacters(changes);
            if (deletedChars > 0) {
                // For performance reasons, don't compute diff if there is nothing to improve
                final newChanges = smartDiff(originalValue, newValue, false);
                if (newChanges != null && deletedCharacters(newChanges) < deletedChars) {
                    // Disabling smartness seems to be better here
                    changes = newChanges;
                }
            }
        }
        return changes;
    }

    static function deletedCharacters(changes:Array<DiffChange>):Int {
        var sum = 0;
        for (c in changes) {
            sum += c.originalLength;
        }
        return sum;
    }

    /**
     * When matching `if ()` with `if (f() = 1) { g(); }`,
     * align it like this:        `if (       )`
     * Not like this:			  `if (  )`
     * Also not like this:		  `if (             )`.
     *
     * The parenthesis are preprocessed to ensure that they match correctly.
     */
    static function smartDiff(originalValue:String, newValue:String, smartBracketMatching:Bool):Null<Array<DiffChange>> {
        if (originalValue.length > 5000 || newValue.length > 5000) {
            // We don't want to work on strings that are too big
            return null;
        }

        function getMaxCharCode(val:String):Int {
            var maxCharCode = 0;
            for (i in 0...val.length) {
                final charCode = StringTools.fastCodeAt(val, i);
                if (charCode > maxCharCode) {
                    maxCharCode = charCode;
                }
            }
            return maxCharCode;
        }

        final maxCharCode = Std.int(Math.max(getMaxCharCode(originalValue), getMaxCharCode(newValue)));
        function getUniqueCharCode(id:Int):Int {
            if (id < 0) {
                throw 'unexpected';
            }
            return maxCharCode + id + 1;
        }

        function getElements(source:String):Array<Int> {
            var level = 0;
            var group = 0;
            final characters:Array<Int> = [];
            for (i in 0...source.length) {
                final c = StringTools.fastCodeAt(source, i);
                // TODO support more brackets
                if (smartBracketMatching && c == '('.code) {
                    final id = group * 100 + level;
                    characters.push(getUniqueCharCode(2 * id));
                    level++;
                }
                else if (smartBracketMatching && c == ')'.code) {
                    level = Std.int(Math.max(level - 1, 0));
                    final id = group * 100 + level;
                    characters.push(getUniqueCharCode(2 * id + 1));
                    if (level == 0) {
                        group++;
                    }
                }
                else {
                    characters.push(c);
                }
            }
            return characters;
        }

        final elements1 = getElements(originalValue);
        final elements2 = getElements(newValue);

        return new LcsDiff(new IntArraySequence(elements1), new IntArraySequence(elements2)).ComputeDiff(false).changes;
    }

}

/**
 * Monaco's `{ getElements: () => elements }` sequences of `smartDiff`.
 */
private class IntArraySequence implements ISequence {

    final elements:Array<Int>;

    public function new(elements:Array<Int>) {
        this.elements = elements;
    }

    public function getElements():EitherType<Array<Int>, Array<String>> {
        return elements;
    }

    public function getStrictElement(index:Int):Null<String> {
        return null;
    }

}
