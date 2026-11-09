// Ported from vscode src/vs/editor/common/model/prefixSumComputer.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

/**
 * Monaco stores the values in `Uint32Array`s; `Array<Int>` here (unboxed on
 * hxcpp). Values are unsigned 32 bit numbers in Monaco (`toUint32`); the
 * values used by the editor (line counts, heights) fit in a positive Int.
 */
class PrefixSumComputer {

    /**
     * values[i] is the value at index i
     */
    var values:Array<Int>;

    /**
     * prefixSum[i] = SUM(heights[j]), 0 <= j <= i
     */
    var prefixSum:Array<Int>;

    /**
     * prefixSum[i], 0 <= i <= prefixSumValidIndex can be trusted
     */
    var prefixSumValidIndex:Int;

    public function new(values:Array<Int>) {
        this.values = values;
        this.prefixSum = newArray(values.length);
        this.prefixSumValidIndex = -1;
    }

    static function newArray(length:Int):Array<Int> {
        final result:Array<Int> = [];
        result.resize(length);
        for (i in 0...length) {
            result[i] = 0;
        }
        return result;
    }

    static inline function toUint32(v:Int):Int {
        return v < 0 ? 0 : v;
    }

    public function getCount():Int {
        return this.values.length;
    }

    public function insertValues(insertIndex:Int, insertValues:Array<Int>):Bool {
        insertIndex = toUint32(insertIndex);
        final oldValues = this.values;
        final oldPrefixSum = this.prefixSum;
        final insertValuesLen = insertValues.length;

        if (insertValuesLen == 0) {
            return false;
        }

        if (insertIndex > oldValues.length) {
            // `subarray` clamps the index
            insertIndex = oldValues.length;
        }

        this.values = oldValues.slice(0, insertIndex).concat(insertValues).concat(oldValues.slice(insertIndex));

        if (insertIndex - 1 < this.prefixSumValidIndex) {
            this.prefixSumValidIndex = insertIndex - 1;
        }

        this.prefixSum = newArray(this.values.length);
        if (this.prefixSumValidIndex >= 0) {
            for (i in 0...this.prefixSumValidIndex + 1) {
                this.prefixSum[i] = oldPrefixSum[i];
            }
        }
        return true;
    }

    public function setValue(index:Int, value:Int):Bool {
        index = toUint32(index);
        value = toUint32(value);

        if (this.values[index] == value) {
            return false;
        }
        this.values[index] = value;
        if (index - 1 < this.prefixSumValidIndex) {
            this.prefixSumValidIndex = index - 1;
        }
        return true;
    }

    public function removeValues(startIndex:Int, count:Int):Bool {
        startIndex = toUint32(startIndex);
        count = toUint32(count);

        final oldValues = this.values;
        final oldPrefixSum = this.prefixSum;

        if (startIndex >= oldValues.length) {
            return false;
        }

        final maxCount = oldValues.length - startIndex;
        if (count >= maxCount) {
            count = maxCount;
        }

        if (count == 0) {
            return false;
        }

        this.values = oldValues.slice(0, startIndex).concat(oldValues.slice(startIndex + count));

        this.prefixSum = newArray(this.values.length);
        if (startIndex - 1 < this.prefixSumValidIndex) {
            this.prefixSumValidIndex = startIndex - 1;
        }
        if (this.prefixSumValidIndex >= 0) {
            for (i in 0...this.prefixSumValidIndex + 1) {
                this.prefixSum[i] = oldPrefixSum[i];
            }
        }
        return true;
    }

    public function getTotalSum():Int {
        if (this.values.length == 0) {
            return 0;
        }
        return this._getPrefixSum(this.values.length - 1);
    }

    /**
     * Returns the sum of the first `index + 1` many items.
     * @returns `SUM(0 <= j <= index, values[j])`.
     */
    public function getPrefixSum(index:Int):Int {
        if (index < 0) {
            return 0;
        }

        index = toUint32(index);
        return this._getPrefixSum(index);
    }

    function _getPrefixSum(index:Int):Int {
        if (index <= this.prefixSumValidIndex) {
            return this.prefixSum[index];
        }

        var startIndex = this.prefixSumValidIndex + 1;
        if (startIndex == 0) {
            this.prefixSum[0] = this.values[0];
            startIndex++;
        }

        if (index >= this.values.length) {
            index = this.values.length - 1;
        }

        for (i in startIndex...index + 1) {
            this.prefixSum[i] = this.prefixSum[i - 1] + this.values[i];
        }
        this.prefixSumValidIndex = (this.prefixSumValidIndex > index ? this.prefixSumValidIndex : index);
        return this.prefixSum[index];
    }

    public function getIndexOf(sum:Float):PrefixSumIndexOfResult {
        final sum = Math.floor(sum);

        // Compute all sums (to get a fully valid prefixSum)
        this.getTotalSum();

        var low = 0;
        var high = this.values.length - 1;
        var mid = 0;
        var midStop = 0;
        var midStart = 0;

        while (low <= high) {
            mid = low + ((high - low) >> 1);

            midStop = this.prefixSum[mid];
            midStart = midStop - this.values[mid];

            if (sum < midStart) {
                high = mid - 1;
            }
            else if (sum >= midStop) {
                low = mid + 1;
            }
            else {
                break;
            }
        }

        return new PrefixSumIndexOfResult(mid, sum - midStart);
    }

}

/**
 * {@link getIndexOf} has an amortized runtime complexity of O(1).
 *
 * ({@link PrefixSumComputer.getIndexOf} is just  O(log n))
 */
class ConstantTimePrefixSumComputer {

    var _values:Array<Int>;

    var _isValid:Bool;

    var _validEndIndex:Int;

    /**
     * _prefixSum[i] = SUM(values[j]), 0 <= j <= i
     */
    var _prefixSum:Array<Int>;

    /**
     * _indexBySum[sum] = idx => _prefixSum[idx - 1] <= sum < _prefixSum[idx]
     */
    var _indexBySum:Array<Int>;

    public function new(values:Array<Int>) {
        this._values = values;
        this._isValid = false;
        this._validEndIndex = -1;
        this._prefixSum = [];
        this._indexBySum = [];
    }

    /**
     * @returns SUM(0 <= j < values.length, values[j])
     */
    public function getTotalSum():Int {
        this._ensureValid();
        return this._indexBySum.length;
    }

    /**
     * Returns the sum of the first `count` many items.
     * @returns `SUM(0 <= j < count, values[j])`.
     */
    public function getPrefixSum(count:Int):Int {
        this._ensureValid();
        if (count == 0) {
            return 0;
        }
        return this._prefixSum[count - 1];
    }

    /**
     * @returns `result`, such that `getPrefixSum(result.index) + result.remainder = sum`
     */
    public function getIndexOf(sum:Int):PrefixSumIndexOfResult {
        this._ensureValid();
        final idx = this._indexBySum[sum];
        final viewLinesAbove = idx > 0 ? this._prefixSum[idx - 1] : 0;
        return new PrefixSumIndexOfResult(idx, sum - viewLinesAbove);
    }

    public function removeValues(start:Int, deleteCount:Int):Void {
        this._values.splice(start, deleteCount);
        this._invalidate(start);
    }

    public function insertValues(insertIndex:Int, insertArr:Array<Int>):Void {
        // arrayInsert(this._values, insertIndex, insertArr)
        this._values = this._values.slice(0, insertIndex).concat(insertArr).concat(this._values.slice(insertIndex));
        this._invalidate(insertIndex);
    }

    function _invalidate(index:Int):Void {
        this._isValid = false;
        this._validEndIndex = (this._validEndIndex < index - 1 ? this._validEndIndex : index - 1);
    }

    function _ensureValid():Void {
        if (this._isValid) {
            return;
        }

        for (i in this._validEndIndex + 1...this._values.length) {
            final value = this._values[i];
            final sumAbove = i > 0 ? this._prefixSum[i - 1] : 0;

            this._prefixSum[i] = sumAbove + value;
            for (j in 0...value) {
                this._indexBySum[sumAbove + j] = i;
            }
        }

        // trim things
        this._prefixSum.resize(this._values.length);
        this._indexBySum.resize(this._prefixSum.length > 0 ? this._prefixSum[this._prefixSum.length - 1] : 0);

        // mark as valid
        this._isValid = true;
        this._validEndIndex = this._values.length - 1;
    }

    public function setValue(index:Int, value:Int):Void {
        if (this._values[index] == value) {
            // no change
            return;
        }
        this._values[index] = value;
        this._invalidate(index);
    }

}

class PrefixSumIndexOfResult {

    public final index:Int;

    public final remainder:Int;

    public function new(index:Int, remainder:Int) {
        this.index = index;
        this.remainder = remainder;
    }

}
