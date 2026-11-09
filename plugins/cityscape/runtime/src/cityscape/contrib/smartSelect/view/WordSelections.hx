// Ported from vscode src/vs/editor/contrib/smartSelect/browser/wordSelections.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.smartSelect.view;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.CharCode;
import cityscape.base.common.Strings;
import cityscape.common.Languages.SelectionRange;
import cityscape.common.Languages.SelectionRangeProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;

class WordSelectionRangeProvider implements SelectionRangeProvider {

    final selectSubwords:Bool;

    public function new(selectSubwords:Bool = true) {
        this.selectSubwords = selectSubwords;
    }

    /**
     * Synchronous: `resolve` is called before returning.
     */
    public function provideSelectionRanges(model:ITextModel, positions:Array<Position>, token:CancellationToken, resolve:(ranges:Null<Array<Array<SelectionRange>>>) -> Void):Void {
        resolve(this.provideSelectionRangesSync(model, positions));
    }

    /**
     * Monaco's synchronous `provideSelectionRanges`.
     */
    public function provideSelectionRangesSync(model:ITextModel, positions:Array<Position>):Array<Array<SelectionRange>> {
        final result:Array<Array<SelectionRange>> = [];
        for (position in positions) {
            final bucket:Array<SelectionRange> = [];
            result.push(bucket);
            if (this.selectSubwords) {
                this._addInWordRanges(bucket, model, position);
            }
            this._addWordRanges(bucket, model, position);
            this._addWhitespaceLine(bucket, model, position);
            bucket.push({range: model.getFullModelRange()});
        }
        return result;
    }

    /**
     * JavaScript's `charCodeAt`: -1 out of range (`NaN`, which no
     * comparison matches).
     */
    static inline function charCodeAt(str:String, index:Int):Int {
        return index >= 0 && index < str.length ? StringTools.fastCodeAt(str, index) : -1;
    }

    function _addInWordRanges(bucket:Array<SelectionRange>, model:ITextModel, pos:Position):Void {
        final obj = model.getWordAtPosition(pos);
        if (obj == null) {
            return;
        }

        final word:String = obj.word;
        final startColumn:Int = obj.startColumn;
        final offset = pos.column - startColumn;
        var start = offset;
        var end = offset;
        var lastCh:Int = 0;

        // LEFT anchor (start)
        while (start >= 0) {
            final ch = charCodeAt(word, start);
            if ((start != offset) && (ch == CharCode.Underline || ch == CharCode.Dash)) {
                // foo-bar OR foo_bar
                break;
            }
            else if (Strings.isLowerAsciiLetter(ch) && Strings.isUpperAsciiLetter(lastCh)) {
                // fooBar
                break;
            }
            lastCh = ch;
            start--;
        }
        start += 1;

        // RIGHT anchor (end)
        while (end < word.length) {
            final ch = charCodeAt(word, end);
            if (Strings.isUpperAsciiLetter(ch) && Strings.isLowerAsciiLetter(lastCh)) {
                // fooBar
                break;
            }
            else if (ch == CharCode.Underline || ch == CharCode.Dash) {
                // foo-bar OR foo_bar
                break;
            }
            lastCh = ch;
            end++;
        }

        if (start < end) {
            bucket.push({range: new Range(pos.lineNumber, startColumn + start, pos.lineNumber, startColumn + end)});
        }
    }

    function _addWordRanges(bucket:Array<SelectionRange>, model:ITextModel, pos:Position):Void {
        final word = model.getWordAtPosition(pos);
        if (word != null) {
            bucket.push({range: new Range(pos.lineNumber, word.startColumn, pos.lineNumber, word.endColumn)});
        }
    }

    function _addWhitespaceLine(bucket:Array<SelectionRange>, model:ITextModel, pos:Position):Void {
        if (model.getLineLength(pos.lineNumber) > 0
            && model.getLineFirstNonWhitespaceColumn(pos.lineNumber) == 0
            && model.getLineLastNonWhitespaceColumn(pos.lineNumber) == 0
        ) {
            bucket.push({range: new Range(pos.lineNumber, 1, pos.lineNumber, model.getLineMaxColumn(pos.lineNumber))});
        }
    }

}
