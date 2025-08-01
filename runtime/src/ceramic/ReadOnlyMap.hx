package ceramic;

/**
 * A read-only view of a Map that prevents modification.
 * 
 * ReadOnlyMap is an abstract over a regular Map that only exposes
 * non-modifying operations. This provides compile-time safety when
 * passing maps to code that should not modify them.
 * 
 * Note: The underlying Map can still be modified through other references.
 * Use the `original` property to access the mutable Map at your own risk.
 * 
 * Example usage:
 * ```haxe
 * var scores = new Map<String, Int>();
 * scores["player1"] = 100;
 * 
 * // Pass as read-only
 * function displayScores(scores:ReadOnlyMap<String, Int>) {
 *     trace(scores["player1"]); // OK
 *     // scores["player1"] = 200; // Compile error!
 * }
 * 
 * displayScores(scores);
 * ```
 * 
 * @param K The key type
 * @param V The value type
 */
@:forward(get, exists, keys, toString)
abstract ReadOnlyMap<K,V>(Map<K,V>) from Map<K,V> to Map<K,V> {

    @:arrayAccess extern inline public function arrayAccess(key:K):V return this.get(key);

    /**
     * Returns the underlying (and mutable) data. Use at your own risk!
     */
    public var original(get,never):Map<K,V>;
    inline private function get_original():Map<K,V> return this;

    inline public function iterator():Iterator<V>
        return this.iterator();

    inline public function keyValueIterator():KeyValueIterator<K, V>
        return this.keyValueIterator();

}
