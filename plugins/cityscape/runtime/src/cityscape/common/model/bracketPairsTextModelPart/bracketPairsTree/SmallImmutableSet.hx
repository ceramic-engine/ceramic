// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/bracketPairsTree/smallImmutableSet.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree;

/**
 * Represents an immutable set that works best for a small number of elements (less than 32).
 * It uses bits to encode element membership efficiently.
 */
class SmallImmutableSet<T> {

    static final emptyArr:Array<Int> = [];

    /**
     * Interned sets of up to 7 dense elements. The sets are immutable and
     * each entry only depends on its index: this is a table filled on first
     * use, shared by all contexts.
     */
    static var cache:Null<Array<SmallImmutableSet<Any>>> = null;

    static function create<T>(items:Int, additionalItems:Array<Int>):SmallImmutableSet<T> {
        if (items >= 0 && items <= 128 && additionalItems.length == 0) {
            // We create a cache of 128=2^7 elements to cover all sets with up to 7 (dense) elements.
            if (cache == null) {
                cache = [for (_ in 0...129) null];
            }
            var cached = cache[items];
            if (cached == null) {
                cached = new SmallImmutableSet<Any>(items, additionalItems);
                cache[items] = cached;
            }
            return cast cached;
        }

        return new SmallImmutableSet<T>(items, additionalItems);
    }

    static var empty:Null<SmallImmutableSet<Any>> = null;

    public static function getEmpty<T>():SmallImmutableSet<T> {
        if (empty == null) {
            empty = SmallImmutableSet.create(0, emptyArr);
        }
        return cast empty;
    }

    final items:Int;
    final additionalItems:Array<Int>;

    function new(items:Int, additionalItems:Array<Int>) {
        this.items = items;
        this.additionalItems = additionalItems;
    }

    public function add(value:T, keyProvider:IDenseKeyProvider<T>):SmallImmutableSet<T> {
        final key = keyProvider.getKey(value);
        var idx = key >> 5; // divided by 32
        if (idx == 0) {
            // fast path
            final newItem = (1 << key) | items;
            if (newItem == items) {
                return this;
            }
            return SmallImmutableSet.create(newItem, additionalItems);
        }
        idx--;

        final newItems = additionalItems.slice(0);
        while (newItems.length < idx) {
            newItems.push(0);
        }
        if (newItems.length == idx) {
            newItems.push(0);
        }
        newItems[idx] |= 1 << (key & 31);

        return SmallImmutableSet.create(items, newItems);
    }

    public function has(value:T, keyProvider:IDenseKeyProvider<T>):Bool {
        final key = keyProvider.getKey(value);
        var idx = key >> 5; // divided by 32
        if (idx == 0) {
            // fast path
            return (items & (1 << key)) != 0;
        }
        idx--;

        final item = idx < additionalItems.length ? additionalItems[idx] : 0;
        return (item & (1 << (key & 31))) != 0;
    }

    public function merge(other:SmallImmutableSet<T>):SmallImmutableSet<T> {
        final merged = items | other.items;

        if (additionalItems == emptyArr && other.additionalItems == emptyArr) {
            // fast path
            if (merged == items) {
                return this;
            }
            if (merged == other.items) {
                return other;
            }
            return SmallImmutableSet.create(merged, emptyArr);
        }

        // This can be optimized, but it's not a common case
        final newItems:Array<Int> = [];
        final len = additionalItems.length > other.additionalItems.length ? additionalItems.length : other.additionalItems.length;
        for (i in 0...len) {
            final item1 = i < additionalItems.length ? additionalItems[i] : 0;
            final item2 = i < other.additionalItems.length ? other.additionalItems[i] : 0;
            newItems.push(item1 | item2);
        }

        return SmallImmutableSet.create(merged, newItems);
    }

    public function intersects(other:SmallImmutableSet<T>):Bool {
        if ((items & other.items) != 0) {
            return true;
        }

        final len = additionalItems.length < other.additionalItems.length ? additionalItems.length : other.additionalItems.length;
        for (i in 0...len) {
            if ((additionalItems[i] & other.additionalItems[i]) != 0) {
                return true;
            }
        }

        return false;
    }

    public function equals(other:SmallImmutableSet<T>):Bool {
        if (items != other.items) {
            return false;
        }

        if (additionalItems.length != other.additionalItems.length) {
            return false;
        }

        for (i in 0...additionalItems.length) {
            if (additionalItems[i] != other.additionalItems[i]) {
                return false;
            }
        }

        return true;
    }

}

interface IDenseKeyProvider<T> {
    function getKey(value:T):Int;
}

/**
 * `identityKeyProvider` of smallImmutableSet.ts is `IdentityKeyProvider.INSTANCE`.
 */
class IdentityKeyProvider implements IDenseKeyProvider<Int> {

    public static final INSTANCE = new IdentityKeyProvider();

    function new() {}

    public inline function getKey(value:Int):Int {
        return value;
    }

}

/**
 * Assigns values a unique incrementing key.
 *
 * Monaco's keys can be of any type; they are strings in every use (the
 * bracket texts), and Cityscape's keys are strings.
 */
class DenseKeyProvider<T:String> implements IDenseKeyProvider<T> {

    final items = new Map<String, Int>();

    /**
     * The keys in insertion order (Monaco's `Map` keeps it).
     */
    final orderedKeys:Array<T> = [];

    public function new() {}

    public function getKey(value:T):Int {
        var existing = items.get(value);
        if (existing == null) {
            existing = orderedKeys.length;
            items.set(value, existing);
            orderedKeys.push(value);
        }
        return existing;
    }

    public function reverseLookup(value:Int):Null<T> {
        return value >= 0 && value < orderedKeys.length ? orderedKeys[value] : null;
    }

    public function reverseLookupSet(set:SmallImmutableSet<T>):Array<T> {
        final result:Array<T> = [];
        for (key in orderedKeys) {
            if (set.has(key, this)) {
                result.push(key);
            }
        }
        return result;
    }

    public function keys():Iterator<T> {
        return orderedKeys.iterator();
    }

}
