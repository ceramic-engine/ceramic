package ceramic.scriptable;

import haxe.ds.Map;

/**
 * Scriptable interface for Map to expose key-value mapping functionality to scripts.
 * 
 * This interface provides a temporary wrapper around Haxe's Map abstract type
 * until the ExportApi macro can properly extract methods from abstracts.
 * In scripts, this type is exposed as `Map<K,V>`.
 * 
 * Maps are key-value data structures that allow efficient storage and retrieval
 * of values based on unique keys. The implementation automatically selects the
 * most efficient underlying data structure based on the key type.
 * 
 * ## Usage in Scripts
 * 
 * ```hscript
 * // Create a string-to-number map
 * var scores = new Map<String, Int>();
 * 
 * // Add entries
 * scores.set("Alice", 100);
 * scores.set("Bob", 85);
 * scores.set("Charlie", 92);
 * 
 * // Get values
 * var aliceScore = scores.get("Alice"); // 100
 * var daveScore = scores.get("Dave");   // null (not found)
 * 
 * // Check existence
 * if (scores.exists("Bob")) {
 *     trace("Bob has a score");
 * }
 * 
 * // Remove entries
 * scores.remove("Charlie");
 * 
 * // Iterate over keys
 * for (name in scores.keys()) {
 *     trace(name + ": " + scores.get(name));
 * }
 * 
 * // Iterate over values
 * for (score in scores) {
 *     trace("Score: " + score);
 * }
 * 
 * // Clear all entries
 * scores.clear();
 * ```
 * 
 * ## Key Types
 * 
 * Maps support various key types:
 * - String keys: Most common, good performance
 * - Int keys: Very fast lookups
 * - Object keys: Uses object identity for comparison
 * - Enum keys: Compared by value
 * 
 * @see haxe.ds.Map The actual Haxe Map implementation
 */
interface ScriptableMap<K,V> {

    /**
        Maps `key` to `value`.

        If `key` already has a mapping, the previous value disappears.

        If `key` is `null`, the result is unspecified.
    **/
    public function set(key:K, value:V):Void;

    /**
        Returns the current mapping of `key`.

        If no such mapping exists, `null` is returned.

        Note that a check like `map.get(key) == null` can hold for two reasons:

        1. the map has no mapping for `key`
        2. the map has a mapping with a value of `null`

        If it is important to distinguish these cases, `exists()` should be
        used.

        If `key` is `null`, the result is unspecified.
    **/
    public function get(key:K):V;

    /**
        Returns true if `key` has a mapping, false otherwise.

        If `key` is `null`, the result is unspecified.
    **/
    public function exists(key:K):Bool;

    /**
        Removes the mapping of `key` and returns true if such a mapping existed,
        false otherwise.

        If `key` is `null`, the result is unspecified.
    **/
    public function remove(key:K):Bool;

    /**
        Returns an Iterator over the keys of `this` Map.

        The order of keys is undefined.
    **/
    public function keys():Iterator<K>;

    /**
        Returns an Iterator over the values of `this` Map.

        The order of values is undefined.
    **/
    public function iterator():Iterator<V>;

    /**
        Returns an Iterator over the keys and values of `this` Map.

        The order of values is undefined.
    **/
    public function keyValueIterator():KeyValueIterator<K, V>;

    /**
        Removes all keys from `this` Map.
    **/
    public function clear():Void;

}