// Ported from vscode src/vs/base/common/arrays.ts and arraysFind.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * Module functions of arrays.ts and arraysFind.ts. Only what the ported code
 * needs so far.
 */
class Arrays {

    /**
     * Insert the new items in the array.
     */
    public static function pushMany<T>(arr:Array<T>, items:Array<T>):Void {
        for (item in items) {
            arr.push(item);
        }
    }

    /**
     * Returns whether two arrays have the same length and equal items.
     */
    public static function equals<T>(one:Null<Array<T>>, other:Null<Array<T>>, ?itemEquals:(a:T, b:T) -> Bool):Bool {
        if (one == other) {
            return true;
        }
        if (one == null || other == null) {
            return false;
        }
        if (one.length != other.length) {
            return false;
        }
        for (i in 0...one.length) {
            if (itemEquals != null ? !itemEquals(one[i], other[i]) : one[i] != other[i]) {
                return false;
            }
        }
        return true;
    }

    /**
     * Performs a binary search algorithm over a sorted array.
     *
     * @return See `binarySearch2`.
     */
    public static function binarySearch<T>(array:Array<T>, key:T, comparator:(op1:T, op2:T) -> Int):Int {
        return binarySearch2(array.length, i -> comparator(array[i], key));
    }

    /**
     * Performs a binary search algorithm over a sorted collection. Useful for cases
     * when we need to perform a binary search over something that isn't actually an
     * array, and converting data to an array would defeat the use of binary search
     * in the first place.
     *
     * @return the index of the key in the collection if found, or `-(n + 1)` where
     * `n` is the index where it would be inserted.
     */
    public static function binarySearch2(length:Int, compareToKey:(index:Int) -> Int):Int {
        var low = 0;
        var high = length - 1;

        while (low <= high) {
            final mid = ((low + high) >> 1);
            final comp = compareToKey(mid);
            if (comp < 0) {
                low = mid + 1;
            }
            else if (comp > 0) {
                high = mid - 1;
            }
            else {
                return mid;
            }
        }
        return -(low + 1);
    }

    /**
     * Takes a sorted array and a function p. The array is sorted in such a way that all elements where p(x) is false
     * are located before all elements where p(x) is true.
     * @returns the least x for which p(x) is true or array.length if no element fullfills the given function.
     */
    public static function findFirstInSorted<T>(array:Array<T>, p:(x:T) -> Bool):Int {
        var low = 0;
        var high = array.length;
        if (high == 0) {
            return 0; // no children
        }
        while (low < high) {
            final mid = Math.floor((low + high) / 2);
            if (p(array[mid])) {
                high = mid;
            }
            else {
                low = mid + 1;
            }
        }
        return low;
    }

    /**
     * Inserts the items of `insertArr` in `array` at `index`, returning a new array.
     */
    public static function arrayInsert<T>(target:Array<T>, insertIndex:Int, insertArr:Array<T>):Array<T> {
        final before = target.slice(0, insertIndex);
        final after = target.slice(insertIndex);
        return before.concat(insertArr).concat(after);
    }

    /**
     * Finds the last item where predicate is true using binary search.
     * `predicate` must be monotonous, i.e. `arr.map(predicate)` must be like `[true, ..., true, false, ..., false]`!
     *
     * @returns `null` if no item matches, otherwise the last item that matches the predicate.
     */
    public static function findLastMonotonous<T>(array:Array<T>, predicate:(item:T) -> Bool):Null<T> {
        final idx = findLastIdxMonotonous(array, predicate);
        return idx == -1 ? null : array[idx];
    }

    /**
     * Finds the last item where predicate is true using binary search.
     * `predicate` must be monotonous, i.e. `arr.map(predicate)` must be like `[true, ..., true, false, ..., false]`!
     *
     * @returns `startIdx - 1` if predicate is false for all items, otherwise the index of the last item that matches the predicate.
     */
    public static function findLastIdxMonotonous<T>(array:Array<T>, predicate:(item:T) -> Bool, startIdx:Int = 0, ?endIdxEx:Int):Int {
        var i = startIdx;
        var j = endIdxEx != null ? endIdxEx : array.length;
        while (i < j) {
            final k = Math.floor((i + j) / 2);
            if (predicate(array[k])) {
                i = k + 1;
            }
            else {
                j = k;
            }
        }
        return i - 1;
    }

    /**
     * Finds the first item where predicate is true using binary search.
     * `predicate` must be monotonous, i.e. `arr.map(predicate)` must be like `[false, ..., false, true, ..., true]`!
     *
     * @returns `null` if no item matches, otherwise the first item that matches the predicate.
     */
    public static function findFirstMonotonous<T>(array:Array<T>, predicate:(item:T) -> Bool):Null<T> {
        final idx = findFirstIdxMonotonousOrArrLen(array, predicate);
        return idx == array.length ? null : array[idx];
    }

    /**
     * Finds the first item where predicate is true using binary search.
     * `predicate` must be monotonous, i.e. `arr.map(predicate)` must be like `[false, ..., false, true, ..., true]`!
     *
     * @returns `endIdxEx` if predicate is false for all items, otherwise the index of the first item that matches the predicate.
     */
    public static function findFirstIdxMonotonousOrArrLen<T>(array:Array<T>, predicate:(item:T) -> Bool, startIdx:Int = 0, ?endIdxEx:Int):Int {
        var i = startIdx;
        var j = endIdxEx != null ? endIdxEx : array.length;
        while (i < j) {
            final k = Math.floor((i + j) / 2);
            if (predicate(array[k])) {
                j = k;
            }
            else {
                i = k + 1;
            }
        }
        return i;
    }

}

class ArrayQueue<T> {

    final items:Array<T>;

    var firstIdx:Int = 0;

    var lastIdx:Int;

    /**
     * Constructs a queue that is backed by the given array. Runtime is O(1).
     */
    public function new(items:Array<T>) {
        this.items = items;
        this.lastIdx = items.length - 1;
    }

    public var length(get, never):Int;
    function get_length():Int {
        return this.lastIdx - this.firstIdx + 1;
    }

    /**
     * Consumes elements from the beginning of the queue as long as the predicate returns true.
     * If no elements were consumed, `null` is returned. Has a runtime of O(result.length).
     */
    public function takeWhile(predicate:(value:T) -> Bool):Null<Array<T>> {
        // P(k) := k <= this.lastIdx && predicate(this.items[k])
        // Find s := min { k | k >= this.firstIdx && !P(k) } and return this.data[this.firstIdx...s)

        var startIdx = this.firstIdx;
        while (startIdx < this.items.length && predicate(this.items[startIdx])) {
            startIdx++;
        }
        final result = startIdx == this.firstIdx ? null : this.items.slice(this.firstIdx, startIdx);
        this.firstIdx = startIdx;
        return result;
    }

    /**
     * Consumes elements from the end of the queue as long as the predicate returns true.
     * If no elements were consumed, `null` is returned.
     * The result has the same order as the underlying array!
     */
    public function takeFromEndWhile(predicate:(value:T) -> Bool):Null<Array<T>> {
        // P(k) := this.firstIdx >= k && predicate(this.items[k])
        // Find s := max { k | k <= this.lastIdx && !P(k) } and return this.data(s...this.lastIdx]

        var endIdx = this.lastIdx;
        while (endIdx >= 0 && predicate(this.items[endIdx])) {
            endIdx--;
        }
        final result = endIdx == this.lastIdx ? null : this.items.slice(endIdx + 1, this.lastIdx + 1);
        this.lastIdx = endIdx;
        return result;
    }

    public function peek():Null<T> {
        if (this.length == 0) {
            return null;
        }
        return this.items[this.firstIdx];
    }

    public function peekLast():Null<T> {
        if (this.length == 0) {
            return null;
        }
        return this.items[this.lastIdx];
    }

    public function dequeue():Null<T> {
        final idx = firstIdx;
        firstIdx++;
        return idx >= 0 && idx < items.length ? items[idx] : null;
    }

    public function removeLast():Null<T> {
        final idx = lastIdx;
        lastIdx--;
        return idx >= 0 && idx < items.length ? items[idx] : null;
    }

    public function takeCount(count:Int):Array<T> {
        final result = items.slice(firstIdx, firstIdx + count);
        firstIdx += count;
        return result;
    }

}

/**
 * Iterates over the items given to a callback (`CallbackIterable` of
 * arrays.ts).
 */
class CallbackIterable<T> {

    /**
     * Monaco's `CallbackIterable.empty` (a function, since Haxe statics
     * cannot be generic).
     */
    public static function empty<T>():CallbackIterable<T> {
        return new CallbackIterable<T>(_callback -> {});
    }

    /**
     * Calls the callback for every item.
     * Stops when the callback returns false.
     */
    public final iterate:(callback:(item:T) -> Bool) -> Void;

    public function new(iterate:(callback:(item:T) -> Bool) -> Void) {
        this.iterate = iterate;
    }

    public function forEach(handler:(item:T) -> Void):Void {
        iterate(item -> {
            handler(item);
            return true;
        });
    }

    public function toArray():Array<T> {
        final result:Array<T> = [];
        iterate(item -> {
            result.push(item);
            return true;
        });
        return result;
    }

    public function filter(predicate:(item:T) -> Bool):CallbackIterable<T> {
        return new CallbackIterable<T>(cb -> iterate(item -> predicate(item) ? cb(item) : true));
    }

    public function map<TResult>(mapFn:(item:T) -> TResult):CallbackIterable<TResult> {
        return new CallbackIterable<TResult>(cb -> iterate(item -> cb(mapFn(item))));
    }

    public function some(predicate:(item:T) -> Bool):Bool {
        var result = false;
        iterate(item -> {
            result = predicate(item);
            return !result;
        });
        return result;
    }

    public function findFirst(predicate:(item:T) -> Bool):Null<T> {
        var result:Null<T> = null;
        iterate(item -> {
            if (predicate(item)) {
                result = item;
                return false;
            }
            return true;
        });
        return result;
    }

    public function findLast(predicate:(item:T) -> Bool):Null<T> {
        var result:Null<T> = null;
        iterate(item -> {
            if (predicate(item)) {
                result = item;
            }
            return true;
        });
        return result;
    }

    /**
     * `comparator` returns a negative number, zero or a positive number
     * (Monaco's `Comparator` and `CompareResult.isGreaterThan`).
     */
    public function findLastMaxBy(comparator:(a:T, b:T) -> Int):Null<T> {
        var result:Null<T> = null;
        var first = true;
        iterate(item -> {
            if (first || comparator(item, result) > 0) {
                first = false;
                result = item;
            }
            return true;
        });
        return result;
    }

}
