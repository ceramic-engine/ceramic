package ceramic;

@:forward(get, exists, keys, toString)
abstract ReadOnlyMap<K,V>(Map<K,V>) from Map<K,V> to Map<K,V> {

    @:arrayAccess @:extern inline public function arrayAccess(key:K):V return this.get(key);

    /** Returns the underlying (and mutable) data. Use at your own risk! */
    public var original(get,never):Map<K,V>;
    inline private function get_original():Map<K,V> return this;

    inline public function iterator():Iterator<V>
        return this.iterator();

    inline public function keyValueIterator():KeyValueIterator<K, V>
        return this.keyValueIterator();

}
