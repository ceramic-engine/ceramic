// Ported from vscode src/vs/editor/common/diff/legacyLinesDiffComputer.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff;

import cityscape.base.common.Assert;
import cityscape.base.common.CharCode;
import cityscape.base.common.Strings;
import cityscape.base.common.diff.Diff;
import cityscape.base.common.diff.DiffChange;
import cityscape.common.core.LineRange;
import cityscape.common.core.Range;
import cityscape.common.diff.LinesDiffComputer;
import cityscape.common.diff.RangeMapping.DetailedLineRangeMapping;
import cityscape.common.diff.RangeMapping.RangeMapping;
import haxe.extern.EitherType;

class LegacyLinesDiffComputer implements ILinesDiffComputer {

    @:allow(cityscape.common.diff)
    static inline final MINIMUM_MATCHING_CHARACTER_LENGTH = 3;

    public function new() {}

    public function computeDiff(originalLines:Array<String>, modifiedLines:Array<String>, options:ILinesDiffComputerOptions):LinesDiff {
        final diffComputer = new DiffComputer(originalLines, modifiedLines, {
            maxComputationTime: options.maxComputationTimeMs,
            shouldIgnoreTrimWhitespace: options.ignoreTrimWhitespace,
            shouldComputeCharChanges: true,
            shouldMakePrettyDiff: true,
            shouldPostProcessCharChanges: true,
        });
        final result = diffComputer.computeDiff();
        final changes:Array<DetailedLineRangeMapping> = [];
        var lastChange:Null<DetailedLineRangeMapping> = null;

        for (c in result.changes) {
            var originalRange:LineRange;
            if (c.originalEndLineNumber == 0) {
                // Insertion
                originalRange = new LineRange(c.originalStartLineNumber + 1, c.originalStartLineNumber + 1);
            }
            else {
                originalRange = new LineRange(c.originalStartLineNumber, c.originalEndLineNumber + 1);
            }

            var modifiedRange:LineRange;
            if (c.modifiedEndLineNumber == 0) {
                // Deletion
                modifiedRange = new LineRange(c.modifiedStartLineNumber + 1, c.modifiedStartLineNumber + 1);
            }
            else {
                modifiedRange = new LineRange(c.modifiedStartLineNumber, c.modifiedEndLineNumber + 1);
            }

            final charChanges = c.charChanges;
            var change = new DetailedLineRangeMapping(originalRange, modifiedRange, charChanges != null ? charChanges.map(c -> new RangeMapping(
                new Range(c.originalStartLineNumber, c.originalStartColumn, c.originalEndLineNumber, c.originalEndColumn),
                new Range(c.modifiedStartLineNumber, c.modifiedStartColumn, c.modifiedEndLineNumber, c.modifiedEndColumn)
            )) : null);
            if (lastChange != null) {
                if (lastChange.modified.endLineNumberExclusive == change.modified.startLineNumber
                    || lastChange.original.endLineNumberExclusive == change.original.startLineNumber) {
                    // join touching diffs. Probably moving diffs up/down in the algorithm causes touching diffs.
                    change = new DetailedLineRangeMapping(
                        lastChange.original.join(change.original),
                        lastChange.modified.join(change.modified),
                        lastChange.innerChanges != null && change.innerChanges != null ?
                            lastChange.innerChanges.concat(change.innerChanges) : null
                    );
                    changes.pop();
                }
            }

            changes.push(change);
            lastChange = change;
        }

        Assert.assertFn(() -> {
            return Assert.checkAdjacentItems(changes,
                (m1, m2) -> m2.original.startLineNumber - m1.original.endLineNumberExclusive == m2.modified.startLineNumber - m1.modified.endLineNumberExclusive &&
                    // There has to be an unchanged line in between (otherwise both diffs should have been joined)
                    m1.original.endLineNumberExclusive < m2.original.startLineNumber &&
                    m1.modified.endLineNumberExclusive < m2.modified.startLineNumber
            );
        });

        return new LinesDiff(changes, [], result.quitEarly);
    }

}

/**
 * A change
 */
typedef IChange = {
    final originalStartLineNumber:Int;
    final originalEndLineNumber:Int;
    final modifiedStartLineNumber:Int;
    final modifiedEndLineNumber:Int;
}

/**
 * A character level change (Monaco's `ICharChange`; `CharChange` is the class).
 */
typedef ICharChange = {
    final originalStartLineNumber:Int;
    final originalEndLineNumber:Int;
    final modifiedStartLineNumber:Int;
    final modifiedEndLineNumber:Int;
    final originalStartColumn:Int;
    final originalEndColumn:Int;
    final modifiedStartColumn:Int;
    final modifiedEndColumn:Int;
}

/**
 * A line change (Monaco's `ILineChange`; `LineChange` is the class).
 */
typedef ILineChange = {
    final originalStartLineNumber:Int;
    final originalEndLineNumber:Int;
    final modifiedStartLineNumber:Int;
    final modifiedEndLineNumber:Int;
    final charChanges:Null<Array<ICharChange>>;
}

typedef IDiffComputerResult = {
    var quitEarly:Bool;
    var changes:Array<LineChange>;
}

typedef IDiffComputationResult = {
    var quitEarly:Bool;
    var identical:Bool;

    /**
     * The changes as (legacy) line change array.
     * @deprecated Use `changes2` instead.
     */
    var changes:Array<ILineChange>;

    /**
     * The changes as (modern) line range mapping array.
     */
    var changes2:Array<DetailedLineRangeMapping>;
}

private class LegacyDiff {

    public static function computeDiff(originalSequence:ISequence, modifiedSequence:ISequence, continueProcessingPredicate:() -> Bool, pretty:Bool):IDiffResult {
        final diffAlgo = new LcsDiff(originalSequence, modifiedSequence, (_, _) -> continueProcessingPredicate());
        return diffAlgo.ComputeDiff(pretty);
    }

    public static function postProcessCharChanges(rawChanges:Array<DiffChange>):Array<DiffChange> {
        if (rawChanges.length <= 1) {
            return rawChanges;
        }

        final result = [rawChanges[0]];
        var prevChange = result[0];

        for (i in 1...rawChanges.length) {
            final currChange = rawChanges[i];

            final originalMatchingLength = currChange.originalStart - (prevChange.originalStart + prevChange.originalLength);
            final modifiedMatchingLength = currChange.modifiedStart - (prevChange.modifiedStart + prevChange.modifiedLength);
            // Both of the above should be equal, but the continueProcessingPredicate may prevent this from being true
            final matchingLength = Std.int(Math.min(originalMatchingLength, modifiedMatchingLength));

            if (matchingLength < LegacyLinesDiffComputer.MINIMUM_MATCHING_CHARACTER_LENGTH) {
                // Merge the current change into the previous one
                prevChange.originalLength = (currChange.originalStart + currChange.originalLength) - prevChange.originalStart;
                prevChange.modifiedLength = (currChange.modifiedStart + currChange.modifiedLength) - prevChange.modifiedStart;
            }
            else {
                // Add the current change
                result.push(currChange);
                prevChange = currChange;
            }
        }

        return result;
    }

    public static function getFirstNonBlankColumn(txt:String, defaultValue:Int):Int {
        final r = Strings.firstNonWhitespaceIndex(txt);
        if (r == -1) {
            return defaultValue;
        }
        return r + 1;
    }

    public static function getLastNonBlankColumn(txt:String, defaultValue:Int):Int {
        final r = Strings.lastNonWhitespaceIndex(txt);
        if (r == -1) {
            return defaultValue;
        }
        return r + 2;
    }

    public static function createContinueProcessingPredicate(maximumRuntime:Float):() -> Bool {
        if (maximumRuntime == 0) {
            return () -> true;
        }

        final startTime = haxe.Timer.stamp() * 1000;
        return () -> {
            return haxe.Timer.stamp() * 1000 - startTime < maximumRuntime;
        };
    }

    /**
     * JavaScript's `str.charCodeAt(index)`: `NaN` out of range (so that
     * two out of range reads are not equal, like Monaco's comparison).
     */
    public static function charCodeAt(str:String, index:Int):Float {
        if (index < 0 || index >= str.length) {
            return Math.NaN;
        }
        return StringTools.fastCodeAt(str, index);
    }

}

private class LineSequence implements ISequence {

    public final lines:Array<String>;
    final _startColumns:Array<Int>;
    final _endColumns:Array<Int>;

    public function new(lines:Array<String>) {
        final startColumns:Array<Int> = [];
        final endColumns:Array<Int> = [];
        for (i in 0...lines.length) {
            startColumns[i] = LegacyDiff.getFirstNonBlankColumn(lines[i], 1);
            endColumns[i] = LegacyDiff.getLastNonBlankColumn(lines[i], 1);
        }
        this.lines = lines;
        this._startColumns = startColumns;
        this._endColumns = endColumns;
    }

    public function getElements():EitherType<Array<Int>, Array<String>> {
        final elements:Array<String> = [];
        for (i in 0...this.lines.length) {
            elements[i] = this.lines[i].substring(this._startColumns[i] - 1, this._endColumns[i] - 1);
        }
        return elements;
    }

    public function getStrictElement(index:Int):Null<String> {
        return this.lines[index];
    }

    public function getStartLineNumber(i:Int):Int {
        return i + 1;
    }

    public function getEndLineNumber(i:Int):Int {
        return i + 1;
    }

    public function createCharSequence(shouldIgnoreTrimWhitespace:Bool, startIndex:Int, endIndex:Int):CharSequence {
        final charCodes:Array<Int> = [];
        final lineNumbers:Array<Int> = [];
        final columns:Array<Int> = [];
        var len = 0;
        for (index in startIndex...endIndex + 1) {
            final lineContent = this.lines[index];
            final startColumn = (shouldIgnoreTrimWhitespace ? this._startColumns[index] : 1);
            final endColumn = (shouldIgnoreTrimWhitespace ? this._endColumns[index] : lineContent.length + 1);
            for (col in startColumn...endColumn) {
                charCodes[len] = StringTools.fastCodeAt(lineContent, col - 1);
                lineNumbers[len] = index + 1;
                columns[len] = col;
                len++;
            }
            if (!shouldIgnoreTrimWhitespace && index < endIndex) {
                // Add \n if trim whitespace is not ignored
                charCodes[len] = CharCode.LineFeed;
                lineNumbers[len] = index + 1;
                columns[len] = lineContent.length + 1;
                len++;
            }
        }
        return new CharSequence(charCodes, lineNumbers, columns);
    }

}

private class CharSequence implements ISequence {

    final _charCodes:Array<Int>;
    final _lineNumbers:Array<Int>;
    final _columns:Array<Int>;

    public function new(charCodes:Array<Int>, lineNumbers:Array<Int>, columns:Array<Int>) {
        this._charCodes = charCodes;
        this._lineNumbers = lineNumbers;
        this._columns = columns;
    }

    public function toString():String {
        final parts:Array<String> = [];
        for (idx in 0...this._charCodes.length) {
            final s = this._charCodes[idx];
            parts.push((s == CharCode.LineFeed ? '\\n' : String.fromCharCode(s)) + '-(' + this._lineNumbers[idx] + ',' + this._columns[idx] + ')');
        }
        return '[' + parts.join(', ') + ']';
    }

    function _assertIndex(index:Int, arr:Array<Int>):Void {
        if (index < 0 || index >= arr.length) {
            throw new haxe.Exception('Illegal index');
        }
    }

    public function getElements():EitherType<Array<Int>, Array<String>> {
        return this._charCodes;
    }

    public function getStrictElement(index:Int):Null<String> {
        return null;
    }

    public function getStartLineNumber(i:Int):Int {
        if (i > 0 && i == this._lineNumbers.length) {
            // the start line number of the element after the last element
            // is the end line number of the last element
            return this.getEndLineNumber(i - 1);
        }
        this._assertIndex(i, this._lineNumbers);

        return this._lineNumbers[i];
    }

    public function getEndLineNumber(i:Int):Int {
        if (i == -1) {
            // the end line number of the element before the first element
            // is the start line number of the first element
            return this.getStartLineNumber(i + 1);
        }
        this._assertIndex(i, this._lineNumbers);

        if (this._charCodes[i] == CharCode.LineFeed) {
            return this._lineNumbers[i] + 1;
        }
        return this._lineNumbers[i];
    }

    public function getStartColumn(i:Int):Int {
        if (i > 0 && i == this._columns.length) {
            // the start column of the element after the last element
            // is the end column of the last element
            return this.getEndColumn(i - 1);
        }
        this._assertIndex(i, this._columns);
        return this._columns[i];
    }

    public function getEndColumn(i:Int):Int {
        if (i == -1) {
            // the end column of the element before the first element
            // is the start column of the first element
            return this.getStartColumn(i + 1);
        }
        this._assertIndex(i, this._columns);

        if (this._charCodes[i] == CharCode.LineFeed) {
            return 1;
        }
        return this._columns[i] + 1;
    }

}

class CharChange {

    public var originalStartLineNumber:Int;
    public var originalStartColumn:Int;
    public var originalEndLineNumber:Int;
    public var originalEndColumn:Int;

    public var modifiedStartLineNumber:Int;
    public var modifiedStartColumn:Int;
    public var modifiedEndLineNumber:Int;
    public var modifiedEndColumn:Int;

    public function new(
        originalStartLineNumber:Int,
        originalStartColumn:Int,
        originalEndLineNumber:Int,
        originalEndColumn:Int,
        modifiedStartLineNumber:Int,
        modifiedStartColumn:Int,
        modifiedEndLineNumber:Int,
        modifiedEndColumn:Int
    ) {
        this.originalStartLineNumber = originalStartLineNumber;
        this.originalStartColumn = originalStartColumn;
        this.originalEndLineNumber = originalEndLineNumber;
        this.originalEndColumn = originalEndColumn;
        this.modifiedStartLineNumber = modifiedStartLineNumber;
        this.modifiedStartColumn = modifiedStartColumn;
        this.modifiedEndLineNumber = modifiedEndLineNumber;
        this.modifiedEndColumn = modifiedEndColumn;
    }

    @:allow(cityscape.common.diff)
    static function createFromDiffChange(diffChange:DiffChange, originalCharSequence:CharSequence, modifiedCharSequence:CharSequence):CharChange {
        final originalStartLineNumber = originalCharSequence.getStartLineNumber(diffChange.originalStart);
        final originalStartColumn = originalCharSequence.getStartColumn(diffChange.originalStart);
        final originalEndLineNumber = originalCharSequence.getEndLineNumber(diffChange.originalStart + diffChange.originalLength - 1);
        final originalEndColumn = originalCharSequence.getEndColumn(diffChange.originalStart + diffChange.originalLength - 1);

        final modifiedStartLineNumber = modifiedCharSequence.getStartLineNumber(diffChange.modifiedStart);
        final modifiedStartColumn = modifiedCharSequence.getStartColumn(diffChange.modifiedStart);
        final modifiedEndLineNumber = modifiedCharSequence.getEndLineNumber(diffChange.modifiedStart + diffChange.modifiedLength - 1);
        final modifiedEndColumn = modifiedCharSequence.getEndColumn(diffChange.modifiedStart + diffChange.modifiedLength - 1);

        return new CharChange(
            originalStartLineNumber, originalStartColumn, originalEndLineNumber, originalEndColumn,
            modifiedStartLineNumber, modifiedStartColumn, modifiedEndLineNumber, modifiedEndColumn
        );
    }

}

class LineChange {

    public var originalStartLineNumber:Int;
    public var originalEndLineNumber:Int;
    public var modifiedStartLineNumber:Int;
    public var modifiedEndLineNumber:Int;
    public var charChanges:Null<Array<CharChange>>;

    public function new(
        originalStartLineNumber:Int,
        originalEndLineNumber:Int,
        modifiedStartLineNumber:Int,
        modifiedEndLineNumber:Int,
        charChanges:Null<Array<CharChange>>
    ) {
        this.originalStartLineNumber = originalStartLineNumber;
        this.originalEndLineNumber = originalEndLineNumber;
        this.modifiedStartLineNumber = modifiedStartLineNumber;
        this.modifiedEndLineNumber = modifiedEndLineNumber;
        this.charChanges = charChanges;
    }

    @:allow(cityscape.common.diff)
    static function createFromDiffResult(shouldIgnoreTrimWhitespace:Bool, diffChange:DiffChange, originalLineSequence:LineSequence, modifiedLineSequence:LineSequence, continueCharDiff:() -> Bool, shouldComputeCharChanges:Bool, shouldPostProcessCharChanges:Bool):LineChange {
        var originalStartLineNumber:Int;
        var originalEndLineNumber:Int;
        var modifiedStartLineNumber:Int;
        var modifiedEndLineNumber:Int;
        var charChanges:Null<Array<CharChange>> = null;

        if (diffChange.originalLength == 0) {
            originalStartLineNumber = originalLineSequence.getStartLineNumber(diffChange.originalStart) - 1;
            originalEndLineNumber = 0;
        }
        else {
            originalStartLineNumber = originalLineSequence.getStartLineNumber(diffChange.originalStart);
            originalEndLineNumber = originalLineSequence.getEndLineNumber(diffChange.originalStart + diffChange.originalLength - 1);
        }

        if (diffChange.modifiedLength == 0) {
            modifiedStartLineNumber = modifiedLineSequence.getStartLineNumber(diffChange.modifiedStart) - 1;
            modifiedEndLineNumber = 0;
        }
        else {
            modifiedStartLineNumber = modifiedLineSequence.getStartLineNumber(diffChange.modifiedStart);
            modifiedEndLineNumber = modifiedLineSequence.getEndLineNumber(diffChange.modifiedStart + diffChange.modifiedLength - 1);
        }

        if (shouldComputeCharChanges && diffChange.originalLength > 0 && diffChange.originalLength < 20 && diffChange.modifiedLength > 0 && diffChange.modifiedLength < 20 && continueCharDiff()) {
            // Compute character changes for diff chunks of at most 20 lines...
            final originalCharSequence = originalLineSequence.createCharSequence(shouldIgnoreTrimWhitespace, diffChange.originalStart, diffChange.originalStart + diffChange.originalLength - 1);
            final modifiedCharSequence = modifiedLineSequence.createCharSequence(shouldIgnoreTrimWhitespace, diffChange.modifiedStart, diffChange.modifiedStart + diffChange.modifiedLength - 1);

            final originalElements:Array<Int> = originalCharSequence.getElements();
            final modifiedElements:Array<Int> = modifiedCharSequence.getElements();
            if (originalElements.length > 0 && modifiedElements.length > 0) {
                var rawChanges = LegacyDiff.computeDiff(originalCharSequence, modifiedCharSequence, continueCharDiff, true).changes;

                if (shouldPostProcessCharChanges) {
                    rawChanges = LegacyDiff.postProcessCharChanges(rawChanges);
                }

                charChanges = [];
                for (i in 0...rawChanges.length) {
                    charChanges.push(CharChange.createFromDiffChange(rawChanges[i], originalCharSequence, modifiedCharSequence));
                }
            }
        }

        return new LineChange(originalStartLineNumber, originalEndLineNumber, modifiedStartLineNumber, modifiedEndLineNumber, charChanges);
    }

}

typedef IDiffComputerOpts = {
    var shouldComputeCharChanges:Bool;
    var shouldPostProcessCharChanges:Bool;
    var shouldIgnoreTrimWhitespace:Bool;
    var shouldMakePrettyDiff:Bool;
    var maxComputationTime:Float;
}

class DiffComputer {

    final shouldComputeCharChanges:Bool;
    final shouldPostProcessCharChanges:Bool;
    final shouldIgnoreTrimWhitespace:Bool;
    final shouldMakePrettyDiff:Bool;
    final originalLines:Array<String>;
    final modifiedLines:Array<String>;
    final original:LineSequence;
    final modified:LineSequence;
    final continueLineDiff:() -> Bool;
    final continueCharDiff:() -> Bool;

    public function new(originalLines:Array<String>, modifiedLines:Array<String>, opts:IDiffComputerOpts) {
        this.shouldComputeCharChanges = opts.shouldComputeCharChanges;
        this.shouldPostProcessCharChanges = opts.shouldPostProcessCharChanges;
        this.shouldIgnoreTrimWhitespace = opts.shouldIgnoreTrimWhitespace;
        this.shouldMakePrettyDiff = opts.shouldMakePrettyDiff;
        this.originalLines = originalLines;
        this.modifiedLines = modifiedLines;
        this.original = new LineSequence(originalLines);
        this.modified = new LineSequence(modifiedLines);

        this.continueLineDiff = LegacyDiff.createContinueProcessingPredicate(opts.maxComputationTime);
        this.continueCharDiff = LegacyDiff.createContinueProcessingPredicate(opts.maxComputationTime == 0 ? 0 : Math.min(opts.maxComputationTime, 5000)); // never run after 5s for character changes...
    }

    public function computeDiff():IDiffComputerResult {

        if (this.original.lines.length == 1 && this.original.lines[0].length == 0) {
            // empty original => fast path
            if (this.modified.lines.length == 1 && this.modified.lines[0].length == 0) {
                return {
                    quitEarly: false,
                    changes: []
                };
            }

            return {
                quitEarly: false,
                changes: [new LineChange(1, 1, 1, this.modified.lines.length, null)]
            };
        }

        if (this.modified.lines.length == 1 && this.modified.lines[0].length == 0) {
            // empty modified => fast path
            return {
                quitEarly: false,
                changes: [new LineChange(1, this.original.lines.length, 1, 1, null)]
            };
        }

        final diffResult = LegacyDiff.computeDiff(this.original, this.modified, this.continueLineDiff, this.shouldMakePrettyDiff);
        final rawChanges = diffResult.changes;
        final quitEarly = diffResult.quitEarly;

        // The diff is always computed with ignoring trim whitespace
        // This ensures we get the prettiest diff

        if (this.shouldIgnoreTrimWhitespace) {
            final lineChanges:Array<LineChange> = [];
            for (i in 0...rawChanges.length) {
                lineChanges.push(LineChange.createFromDiffResult(this.shouldIgnoreTrimWhitespace, rawChanges[i], this.original, this.modified, this.continueCharDiff, this.shouldComputeCharChanges, this.shouldPostProcessCharChanges));
            }
            return {
                quitEarly: quitEarly,
                changes: lineChanges
            };
        }

        // Need to post-process and introduce changes where the trim whitespace is different
        // Note that we are looping starting at -1 to also cover the lines before the first change
        final result:Array<LineChange> = [];

        var originalLineIndex = 0;
        var modifiedLineIndex = 0;
        final len = rawChanges.length;
        for (i in -1...len) {
            final nextChange = (i + 1 < len ? rawChanges[i + 1] : null);
            final originalStop = (nextChange != null ? nextChange.originalStart : this.originalLines.length);
            final modifiedStop = (nextChange != null ? nextChange.modifiedStart : this.modifiedLines.length);

            while (originalLineIndex < originalStop && modifiedLineIndex < modifiedStop) {
                final originalLine = this.originalLines[originalLineIndex];
                final modifiedLine = this.modifiedLines[modifiedLineIndex];

                if (originalLine != modifiedLine) {
                    // These lines differ only in trim whitespace

                    // Check the leading whitespace
                    {
                        var originalStartColumn = LegacyDiff.getFirstNonBlankColumn(originalLine, 1);
                        var modifiedStartColumn = LegacyDiff.getFirstNonBlankColumn(modifiedLine, 1);
                        while (originalStartColumn > 1 && modifiedStartColumn > 1) {
                            final originalChar = LegacyDiff.charCodeAt(originalLine, originalStartColumn - 2);
                            final modifiedChar = LegacyDiff.charCodeAt(modifiedLine, modifiedStartColumn - 2);
                            if (originalChar != modifiedChar) {
                                break;
                            }
                            originalStartColumn--;
                            modifiedStartColumn--;
                        }

                        if (originalStartColumn > 1 || modifiedStartColumn > 1) {
                            this._pushTrimWhitespaceCharChange(result,
                                originalLineIndex + 1, 1, originalStartColumn,
                                modifiedLineIndex + 1, 1, modifiedStartColumn
                            );
                        }
                    }

                    // Check the trailing whitespace
                    {
                        var originalEndColumn = LegacyDiff.getLastNonBlankColumn(originalLine, 1);
                        var modifiedEndColumn = LegacyDiff.getLastNonBlankColumn(modifiedLine, 1);
                        final originalMaxColumn = originalLine.length + 1;
                        final modifiedMaxColumn = modifiedLine.length + 1;
                        while (originalEndColumn < originalMaxColumn && modifiedEndColumn < modifiedMaxColumn) {
                            final originalChar = LegacyDiff.charCodeAt(originalLine, originalEndColumn - 1);
                            final modifiedChar = LegacyDiff.charCodeAt(originalLine, modifiedEndColumn - 1);
                            if (originalChar != modifiedChar) {
                                break;
                            }
                            originalEndColumn++;
                            modifiedEndColumn++;
                        }

                        if (originalEndColumn < originalMaxColumn || modifiedEndColumn < modifiedMaxColumn) {
                            this._pushTrimWhitespaceCharChange(result,
                                originalLineIndex + 1, originalEndColumn, originalMaxColumn,
                                modifiedLineIndex + 1, modifiedEndColumn, modifiedMaxColumn
                            );
                        }
                    }
                }
                originalLineIndex++;
                modifiedLineIndex++;
            }

            if (nextChange != null) {
                // Emit the actual change
                result.push(LineChange.createFromDiffResult(this.shouldIgnoreTrimWhitespace, nextChange, this.original, this.modified, this.continueCharDiff, this.shouldComputeCharChanges, this.shouldPostProcessCharChanges));

                originalLineIndex += nextChange.originalLength;
                modifiedLineIndex += nextChange.modifiedLength;
            }
        }

        return {
            quitEarly: quitEarly,
            changes: result
        };
    }

    function _pushTrimWhitespaceCharChange(
        result:Array<LineChange>,
        originalLineNumber:Int, originalStartColumn:Int, originalEndColumn:Int,
        modifiedLineNumber:Int, modifiedStartColumn:Int, modifiedEndColumn:Int
    ):Void {
        if (this._mergeTrimWhitespaceCharChange(result, originalLineNumber, originalStartColumn, originalEndColumn, modifiedLineNumber, modifiedStartColumn, modifiedEndColumn)) {
            // Merged into previous
            return;
        }

        var charChanges:Null<Array<CharChange>> = null;
        if (this.shouldComputeCharChanges) {
            charChanges = [new CharChange(
                originalLineNumber, originalStartColumn, originalLineNumber, originalEndColumn,
                modifiedLineNumber, modifiedStartColumn, modifiedLineNumber, modifiedEndColumn
            )];
        }
        result.push(new LineChange(
            originalLineNumber, originalLineNumber,
            modifiedLineNumber, modifiedLineNumber,
            charChanges
        ));
    }

    function _mergeTrimWhitespaceCharChange(
        result:Array<LineChange>,
        originalLineNumber:Int, originalStartColumn:Int, originalEndColumn:Int,
        modifiedLineNumber:Int, modifiedStartColumn:Int, modifiedEndColumn:Int
    ):Bool {
        final len = result.length;
        if (len == 0) {
            return false;
        }

        final prevChange = result[len - 1];

        if (prevChange.originalEndLineNumber == 0 || prevChange.modifiedEndLineNumber == 0) {
            // Don't merge with inserts/deletes
            return false;
        }

        if (prevChange.originalEndLineNumber == originalLineNumber && prevChange.modifiedEndLineNumber == modifiedLineNumber) {
            if (this.shouldComputeCharChanges && prevChange.charChanges != null) {
                prevChange.charChanges.push(new CharChange(
                    originalLineNumber, originalStartColumn, originalLineNumber, originalEndColumn,
                    modifiedLineNumber, modifiedStartColumn, modifiedLineNumber, modifiedEndColumn
                ));
            }
            return true;
        }

        if (prevChange.originalEndLineNumber + 1 == originalLineNumber && prevChange.modifiedEndLineNumber + 1 == modifiedLineNumber) {
            prevChange.originalEndLineNumber = originalLineNumber;
            prevChange.modifiedEndLineNumber = modifiedLineNumber;
            if (this.shouldComputeCharChanges && prevChange.charChanges != null) {
                prevChange.charChanges.push(new CharChange(
                    originalLineNumber, originalStartColumn, originalLineNumber, originalEndColumn,
                    modifiedLineNumber, modifiedStartColumn, modifiedLineNumber, modifiedEndColumn
                ));
            }
            return true;
        }

        return false;
    }

}
