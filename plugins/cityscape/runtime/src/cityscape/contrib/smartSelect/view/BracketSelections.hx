// Ported from vscode src/vs/editor/contrib/smartSelect/browser/bracketSelections.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.smartSelect.view;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.SelectionRange;
import cityscape.common.Languages.SelectionRangeProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.languages.supports.LanguageBracketsConfiguration;

/**
 * The selection ranges of the brackets around a position.
 *
 * Monaco searches in rounds and yields to the event loop (`setTimeout`)
 * when a round takes longer than `_maxDuration` ms. Cityscape runs the
 * rounds one after the other in the same call (the limit of rounds is
 * Monaco's): the ranges are the same, `resolve` is called before
 * returning. Monaco's `LinkedList` is an array.
 */
class BracketSelectionRangeProvider implements SelectionRangeProvider {

    public function new() {}

    public function provideSelectionRanges(model:ITextModel, positions:Array<Position>, token:CancellationToken, resolve:(ranges:Null<Array<Array<SelectionRange>>>) -> Void):Void {
        final result:Array<Array<SelectionRange>> = [];

        for (position in positions) {
            final bucket:Array<SelectionRange> = [];
            result.push(bucket);

            final ranges = new Map<String, Array<Range>>();
            BracketSelectionRangeProvider._bracketsRightYield(0, model, position, ranges);
            BracketSelectionRangeProvider._bracketsLeftYield(0, model, position, ranges, bucket);
        }

        resolve(result);
    }

    /**
     * The time a round may take (ms). Monaco's static, which its tests set.
     */
    public static var _maxDuration:Float = 30;
    static inline final _maxRounds = 2;

    static inline function now():Float {
        return haxe.Timer.stamp() * 1000;
    }

    static function mapIsEmpty<T>(map:Map<String, T>):Bool {
        return !map.keys().hasNext();
    }

    static function _bracketsRightYield(round:Int, model:ITextModel, pos:Null<Position>, ranges:Map<String, Array<Range>>):Void {
        final counts = new Map<String, Int>();
        var t1 = now();
        while (true) {
            if (round >= BracketSelectionRangeProvider._maxRounds) {
                break;
            }
            if (pos == null) {
                break;
            }
            final bracket = model.bracketPairs.findNextBracket(pos);
            if (bracket == null) {
                break;
            }
            final d = now() - t1;
            if (d > BracketSelectionRangeProvider._maxDuration) {
                // Monaco: `setTimeout(() => _bracketsRightYield(resolve, round + 1, ...))`
                // (a new round with new counts)
                round++;
                counts.clear();
                t1 = now();
                continue;
            }
            if (bracket.bracketInfo.isOpeningBracket) {
                final key = bracket.bracketInfo.bracketText;
                // wait for closing
                final val = counts.exists(key) ? counts.get(key) : 0;
                counts.set(key, val + 1);
            }
            else {
                final key = (cast bracket.bracketInfo : ClosingBracketKind).getOpeningBrackets()[0].bracketText;
                // process closing
                var val = counts.exists(key) ? counts.get(key) : 0;
                val -= 1;
                counts.set(key, Std.int(Math.max(0, val)));
                if (val < 0) {
                    var list = ranges.get(key);
                    if (list == null) {
                        list = [];
                        ranges.set(key, list);
                    }
                    list.push(bracket.range);
                }
            }
            pos = bracket.range.getEndPosition();
        }
    }

    static function _bracketsLeftYield(round:Int, model:ITextModel, pos:Null<Position>, ranges:Map<String, Array<Range>>, bucket:Array<SelectionRange>):Void {
        final counts = new Map<String, Int>();
        var t1 = now();
        while (true) {
            if (round >= BracketSelectionRangeProvider._maxRounds && mapIsEmpty(ranges)) {
                break;
            }
            if (pos == null) {
                break;
            }
            final bracket = model.bracketPairs.findPrevBracket(pos);
            if (bracket == null) {
                break;
            }
            final d = now() - t1;
            if (d > BracketSelectionRangeProvider._maxDuration) {
                // Monaco: `setTimeout(() => _bracketsLeftYield(resolve, round + 1, ...))`
                round++;
                counts.clear();
                t1 = now();
                continue;
            }
            if (!bracket.bracketInfo.isOpeningBracket) {
                final key = (cast bracket.bracketInfo : ClosingBracketKind).getOpeningBrackets()[0].bracketText;
                // wait for opening
                final val = counts.exists(key) ? counts.get(key) : 0;
                counts.set(key, val + 1);
            }
            else {
                final key = bracket.bracketInfo.bracketText;
                // opening
                var val = counts.exists(key) ? counts.get(key) : 0;
                val -= 1;
                counts.set(key, Std.int(Math.max(0, val)));
                if (val < 0) {
                    final list = ranges.get(key);
                    if (list != null) {
                        final closing = list.shift();
                        if (list.length == 0) {
                            ranges.remove(key);
                        }
                        final innerBracket = Range.fromPositions(bracket.range.getEndPosition(), closing.getStartPosition());
                        final outerBracket = Range.fromPositions(bracket.range.getStartPosition(), closing.getEndPosition());
                        bucket.push({range: innerBracket});
                        bucket.push({range: outerBracket});
                        BracketSelectionRangeProvider._addBracketLeading(model, outerBracket, bucket);
                    }
                }
            }
            pos = bracket.range.getStartPosition();
        }
    }

    static function _addBracketLeading(model:ITextModel, bracket:Range, bucket:Array<SelectionRange>):Void {
        if (bracket.startLineNumber == bracket.endLineNumber) {
            return;
        }
        // xxxxxxxx {
        //
        // }
        final startLine = bracket.startLineNumber;
        final column = model.getLineFirstNonWhitespaceColumn(startLine);
        if (column != 0 && column != bracket.startColumn) {
            bucket.push({range: Range.fromPositions(new Position(startLine, column), bracket.getEndPosition())});
            bucket.push({range: Range.fromPositions(new Position(startLine, 1), bracket.getEndPosition())});
        }

        // xxxxxxxx
        // {
        //
        // }
        final aboveLine = startLine - 1;
        if (aboveLine > 0) {
            final column = model.getLineFirstNonWhitespaceColumn(aboveLine);
            if (column == bracket.startColumn && column != model.getLineLastNonWhitespaceColumn(aboveLine)) {
                bucket.push({range: Range.fromPositions(new Position(aboveLine, column), bracket.getEndPosition())});
                bucket.push({range: Range.fromPositions(new Position(aboveLine, 1), bracket.getEndPosition())});
            }
        }
    }

}
