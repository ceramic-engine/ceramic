// Ported from vscode src/vs/base/common/arrays.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * Module functions of arrays.ts. Only what the ported code needs so far.
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

}
