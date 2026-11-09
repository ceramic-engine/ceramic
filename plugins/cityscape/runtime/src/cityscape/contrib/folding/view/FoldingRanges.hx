// Ported from vscode src/vs/editor/contrib/folding/browser/foldingRanges.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.folding.view;

import cityscape.contrib.folding.view.Folding.SelectedLines;
import haxe.extern.EitherType;
import haxe.io.UInt32Array;

typedef ILineRange = {
    var startLineNumber:Int;
    var endLineNumber:Int;
}

enum abstract FoldSource(Int) from Int to Int {
    var provider = 0;
    var userDefined = 1;
    var recovered = 2;
}

/**
 * A folding range with its state. A class here (Monaco's is an interface
 * of literals) because the merge reads and writes it on every update.
 */
class FoldRange {
    public var startLineNumber:Int;
    public var endLineNumber:Int;
    public var type:Null<String>;
    public var isCollapsed:Bool;
    public var source:FoldSource;

    public function new(startLineNumber:Int, endLineNumber:Int, type:Null<String>, isCollapsed:Bool, source:FoldSource) {
        this.startLineNumber = startLineNumber;
        this.endLineNumber = endLineNumber;
        this.type = type;
        this.isCollapsed = isCollapsed;
        this.source = source;
    }
}

class FoldingRangesConstants {

    public static inline final MAX_FOLDING_REGIONS = 0xFFFF;
    public static inline final MAX_LINE_NUMBER = 0xFFFFFF;

    public static inline final MASK_INDENT = 0xFF000000;

    public static function foldSourceAbbr(source:FoldSource):String {
        return switch source {
            case FoldSource.userDefined: 'u';
            case FoldSource.recovered: 'r';
            case _: ' ';
        };
    }

}

private class BitField {
    final _states:UInt32Array;

    public function new(size:Int) {
        final numWords = Math.ceil(size / 32);
        _states = new UInt32Array(numWords);
    }

    public function get(index:Int):Bool {
        final arrayIndex = Std.int(index / 32);
        final bit = index % 32;
        if (index < 0 || arrayIndex >= _states.length) {
            return false; // `undefined` in Monaco
        }
        final value:Int = _states[arrayIndex];
        return (value & (1 << bit)) != 0;
    }

    public function set(index:Int, newState:Bool):Void {
        final arrayIndex = Std.int(index / 32);
        final bit = index % 32;
        final value:Int = _states[arrayIndex];
        if (newState) {
            _states[arrayIndex] = value | (1 << bit);
        }
        else {
            _states[arrayIndex] = value & ~(1 << bit);
        }
    }
}

class FoldingRegions {
    final _startIndexes:UInt32Array;
    final _endIndexes:UInt32Array;
    final _collapseStates:BitField;
    final _userDefinedStates:BitField;
    final _recoveredStates:BitField;

    var _parentsComputed:Bool;
    final _types:Null<Array<Null<String>>>;

    public function new(startIndexes:UInt32Array, endIndexes:UInt32Array, ?types:Array<Null<String>>) {
        if (startIndexes.length != endIndexes.length || startIndexes.length > FoldingRangesConstants.MAX_FOLDING_REGIONS) {
            throw 'invalid startIndexes or endIndexes size';
        }
        _startIndexes = startIndexes;
        _endIndexes = endIndexes;
        _collapseStates = new BitField(startIndexes.length);
        _userDefinedStates = new BitField(startIndexes.length);
        _recoveredStates = new BitField(startIndexes.length);
        _types = types;
        _parentsComputed = false;
    }

    function ensureParentIndices():Void {
        if (!_parentsComputed) {
            _parentsComputed = true;
            final parentIndexes:Array<Int> = [];
            inline function isInsideLast(startLineNumber:Int, endLineNumber:Int):Bool {
                final index = parentIndexes[parentIndexes.length - 1];
                return getStartLineNumber(index) <= startLineNumber && getEndLineNumber(index) >= endLineNumber;
            }
            for (i in 0..._startIndexes.length) {
                final startLineNumber:Int = _startIndexes[i];
                final endLineNumber:Int = _endIndexes[i];
                if (startLineNumber > FoldingRangesConstants.MAX_LINE_NUMBER || endLineNumber > FoldingRangesConstants.MAX_LINE_NUMBER) {
                    throw 'startLineNumber or endLineNumber must not exceed ' + FoldingRangesConstants.MAX_LINE_NUMBER;
                }
                while (parentIndexes.length > 0 && !isInsideLast(startLineNumber, endLineNumber)) {
                    parentIndexes.pop();
                }
                final parentIndex = parentIndexes.length > 0 ? parentIndexes[parentIndexes.length - 1] : -1;
                parentIndexes.push(i);
                _startIndexes[i] = startLineNumber + ((parentIndex & 0xFF) << 24);
                _endIndexes[i] = endLineNumber + ((parentIndex & 0xFF00) << 16);
            }
        }
    }

    public var length(get, never):Int;
    inline function get_length():Int {
        return _startIndexes.length;
    }

    /**
     * The stored start of region `index`, 0 out of range (Monaco reads
     * `undefined` there, which its bit operations turn into 0: the fold
     * jumping functions read one region past the end).
     */
    inline function rawStart(index:Int):Int {
        if (index < 0 || index >= _startIndexes.length) {
            return 0;
        }
        final value:Int = _startIndexes[index];
        return value;
    }

    inline function rawEnd(index:Int):Int {
        if (index < 0 || index >= _endIndexes.length) {
            return 0;
        }
        final value:Int = _endIndexes[index];
        return value;
    }

    public function getStartLineNumber(index:Int):Int {
        return rawStart(index) & FoldingRangesConstants.MAX_LINE_NUMBER;
    }

    public function getEndLineNumber(index:Int):Int {
        return rawEnd(index) & FoldingRangesConstants.MAX_LINE_NUMBER;
    }

    public function getType(index:Int):Null<String> {
        return _types != null ? _types[index] : null;
    }

    public function hasTypes():Bool {
        return _types != null;
    }

    public function isCollapsed(index:Int):Bool {
        return _collapseStates.get(index);
    }

    public function setCollapsed(index:Int, newState:Bool):Void {
        _collapseStates.set(index, newState);
    }

    function isUserDefined(index:Int):Bool {
        return _userDefinedStates.get(index);
    }

    function setUserDefined(index:Int, newState:Bool):Void {
        _userDefinedStates.set(index, newState);
    }

    function isRecovered(index:Int):Bool {
        return _recoveredStates.get(index);
    }

    function setRecovered(index:Int, newState:Bool):Void {
        _recoveredStates.set(index, newState);
    }

    public function getSource(index:Int):FoldSource {
        if (isUserDefined(index)) {
            return FoldSource.userDefined;
        }
        else if (isRecovered(index)) {
            return FoldSource.recovered;
        }
        return FoldSource.provider;
    }

    public function setSource(index:Int, source:FoldSource):Void {
        if (source == FoldSource.userDefined) {
            setUserDefined(index, true);
            setRecovered(index, false);
        }
        else if (source == FoldSource.recovered) {
            setUserDefined(index, false);
            setRecovered(index, true);
        }
        else {
            setUserDefined(index, false);
            setRecovered(index, false);
        }
    }

    public function setCollapsedAllOfType(type:String, newState:Bool):Bool {
        var hasChanged = false;
        if (_types != null) {
            for (i in 0..._types.length) {
                if (_types[i] == type) {
                    setCollapsed(i, newState);
                    hasChanged = true;
                }
            }
        }
        return hasChanged;
    }

    public function toRegion(index:Int):FoldingRegion {
        return new FoldingRegion(this, index);
    }

    public function getParentIndex(index:Int):Int {
        ensureParentIndices();
        final start:Int = rawStart(index);
        final end:Int = rawEnd(index);
        final parent = ((start & FoldingRangesConstants.MASK_INDENT) >>> 24) + ((end & FoldingRangesConstants.MASK_INDENT) >>> 16);
        if (parent == FoldingRangesConstants.MAX_FOLDING_REGIONS) {
            return -1;
        }
        return parent;
    }

    public function contains(index:Int, line:Int):Bool {
        return getStartLineNumber(index) <= line && getEndLineNumber(index) >= line;
    }

    function findIndex(line:Int):Int {
        var low = 0, high = _startIndexes.length;
        if (high == 0) {
            return -1; // no children
        }
        while (low < high) {
            final mid = (low + high) >> 1;
            if (line < getStartLineNumber(mid)) {
                high = mid;
            }
            else {
                low = mid + 1;
            }
        }
        return low - 1;
    }

    public function findRange(line:Int):Int {
        var index = findIndex(line);
        if (index >= 0) {
            final endLineNumber = getEndLineNumber(index);
            if (endLineNumber >= line) {
                return index;
            }
            index = getParentIndex(index);
            while (index != -1) {
                if (contains(index, line)) {
                    return index;
                }
                index = getParentIndex(index);
            }
        }
        return -1;
    }

    public function toString():String {
        final res:Array<String> = [];
        for (i in 0...length) {
            res[i] = '[' + FoldingRangesConstants.foldSourceAbbr(getSource(i)) + (isCollapsed(i) ? '+' : '-') + '] ' + getStartLineNumber(i) + '/' + getEndLineNumber(i);
        }
        return res.join(', ');
    }

    public function toFoldRange(index:Int):FoldRange {
        return new FoldRange(
            getStartLineNumber(index),
            getEndLineNumber(index),
            _types != null ? _types[index] : null,
            isCollapsed(index),
            getSource(index)
        );
    }

    public static function fromFoldRanges(ranges:Array<FoldRange>):FoldingRegions {
        final rangesLength = ranges.length;
        final startIndexes = new UInt32Array(rangesLength);
        final endIndexes = new UInt32Array(rangesLength);
        var types:Null<Array<Null<String>>> = [];
        var gotTypes = false;
        for (i in 0...rangesLength) {
            final range = ranges[i];
            startIndexes[i] = range.startLineNumber;
            endIndexes[i] = range.endLineNumber;
            types.push(range.type);
            if (range.type != null && range.type.length > 0) {
                gotTypes = true;
            }
        }
        if (!gotTypes) {
            types = null;
        }
        final regions = new FoldingRegions(startIndexes, endIndexes, types);
        for (i in 0...rangesLength) {
            if (ranges[i].isCollapsed) {
                regions.setCollapsed(i, true);
            }
            regions.setSource(i, ranges[i].source);
        }
        return regions;
    }

    /**
     * Two inputs, each a FoldingRegions or a FoldRange[], are merged.
     * Each input must be pre-sorted on startLineNumber.
     * The first list is assumed to always include all regions currently defined by range providers.
     * The second list only contains the previously collapsed and all manual ranges.
     * If the line position matches, the range of the new range is taken, and the range is no longer manual
     * When an entry in one list overlaps an entry in the other, the second list's entry "wins" and
     * overlapping entries in the first list are discarded.
     * Invalid entries are discarded. An entry is invalid if:
     * 		the start and end line numbers aren't a valid range of line numbers,
     * 		it is out of sequence or has the same start line as a preceding entry,
     * 		it overlaps a preceding entry and is not fully contained by that entry.
     */
    public static function sanitizeAndMerge(rangesA:EitherType<FoldingRegions, Array<FoldRange>>, rangesB:EitherType<FoldingRegions, Array<FoldRange>>, maxLineNumber:Null<Int>, ?selection:SelectedLines):Array<FoldRange> {

        final maxLine:Int = maxLineNumber != null ? maxLineNumber : 0x7FFFFFFF;

        final regionsA:Null<FoldingRegions> = Std.isOfType(rangesA, FoldingRegions) ? cast rangesA : null;
        final arrayA:Null<Array<FoldRange>> = regionsA == null ? cast rangesA : null;
        final regionsB:Null<FoldingRegions> = Std.isOfType(rangesB, FoldingRegions) ? cast rangesB : null;
        final arrayB:Null<Array<FoldRange>> = regionsB == null ? cast rangesB : null;
        final limitA = regionsA != null ? regionsA.length : arrayA.length;
        final limitB = regionsB != null ? regionsB.length : arrayB.length;

        inline function getA(i:Int):Null<FoldRange> {
            return (i < limitA) ? (regionsA != null ? regionsA.toFoldRange(i) : arrayA[i]) : null;
        }
        inline function getB(i:Int):Null<FoldRange> {
            return (i < limitB) ? (regionsB != null ? regionsB.toFoldRange(i) : arrayB[i]) : null;
        }
        var indexA = 0;
        var indexB = 0;
        var nextA = getA(0);
        var nextB = getB(0);

        final stackedRanges:Array<FoldRange> = [];
        var topStackedRange:Null<FoldRange> = null;
        var prevLineNumber = 0;
        final resultRanges:Array<FoldRange> = [];

        while (nextA != null || nextB != null) {

            var useRange:Null<FoldRange> = null;
            if (nextB != null && (nextA == null || nextA.startLineNumber >= nextB.startLineNumber)) {
                if (nextA != null && nextA.startLineNumber == nextB.startLineNumber) {
                    if (nextB.source == FoldSource.userDefined) {
                        // a user defined range (possibly unfolded)
                        useRange = nextB;
                    }
                    else {
                        // a previously folded range or a (possibly unfolded) recovered range
                        useRange = nextA;
                        // stays collapsed if the range still has the same number of lines or the selection is not in the range or after it
                        useRange.isCollapsed = nextB.isCollapsed && (nextA.endLineNumber == nextB.endLineNumber || selection == null || !selection.startsInside(nextA.startLineNumber + 1, nextA.endLineNumber + 1));
                        useRange.source = FoldSource.provider;
                    }
                    nextA = getA(++indexA); // not necessary, just for speed
                }
                else {
                    useRange = nextB;
                    if (nextB.isCollapsed && nextB.source == FoldSource.provider) {
                        // a previously collapsed range
                        useRange.source = FoldSource.recovered;
                    }
                }
                nextB = getB(++indexB);
            }
            else {
                // nextA is next. The user folded B set takes precedence and we sometimes need to look
                // ahead in it to check for an upcoming conflict.
                var scanIndex = indexB;
                var prescanB = nextB;
                while (true) {
                    if (prescanB == null || prescanB.startLineNumber > nextA.endLineNumber) {
                        useRange = nextA;
                        break; // no conflict, use this nextA
                    }
                    if (prescanB.source == FoldSource.userDefined && prescanB.endLineNumber > nextA.endLineNumber) {
                        // we found a user folded range, it wins
                        break; // without setting nextResult, so this nextA gets skipped
                    }
                    prescanB = getB(++scanIndex);
                }
                nextA = getA(++indexA);
            }

            if (useRange != null) {
                while (topStackedRange != null
                    && topStackedRange.endLineNumber < useRange.startLineNumber) {
                    topStackedRange = stackedRanges.pop();
                }
                if (useRange.endLineNumber > useRange.startLineNumber
                    && useRange.startLineNumber > prevLineNumber
                    && useRange.endLineNumber <= maxLine
                    && (topStackedRange == null
                        || topStackedRange.endLineNumber >= useRange.endLineNumber)) {
                    resultRanges.push(useRange);
                    prevLineNumber = useRange.startLineNumber;
                    if (topStackedRange != null) {
                        stackedRanges.push(topStackedRange);
                    }
                    topStackedRange = useRange;
                }
            }

        }
        return resultRanges;
    }

}

class FoldingRegion {

    final ranges:FoldingRegions;
    var index:Int;

    public function new(ranges:FoldingRegions, index:Int) {
        this.ranges = ranges;
        this.index = index;
    }

    public var startLineNumber(get, never):Int;
    function get_startLineNumber():Int {
        return ranges.getStartLineNumber(index);
    }

    public var endLineNumber(get, never):Int;
    function get_endLineNumber():Int {
        return ranges.getEndLineNumber(index);
    }

    public var regionIndex(get, never):Int;
    function get_regionIndex():Int {
        return index;
    }

    public var parentIndex(get, never):Int;
    function get_parentIndex():Int {
        return ranges.getParentIndex(index);
    }

    public var isCollapsed(get, never):Bool;
    function get_isCollapsed():Bool {
        return ranges.isCollapsed(index);
    }

    /**
     * Monaco takes an `ILineRange`; it is only called with regions.
     */
    public function containedBy(range:FoldingRegion):Bool {
        return range.startLineNumber <= startLineNumber && range.endLineNumber >= endLineNumber;
    }

    public function containsLine(lineNumber:Int):Bool {
        return startLineNumber <= lineNumber && lineNumber <= endLineNumber;
    }

    public function hidesLine(lineNumber:Int):Bool {
        return startLineNumber < lineNumber && lineNumber <= endLineNumber;
    }
}
