package ceramic;

@:forward(get, exists, keys, iterator, toString)
abstract ImmutableMap<K,V>(Map<K,V>) from Map<K,V> to Map<K,V> {

    @:arrayAccess @:extern inline public function arrayAccess(key:K):V return this.get(key);

    /** Returns the underlying (and mutable) data. Use at your own risk! */
    public var mutable(get,never):Map<K,V>;
    inline private function get_mutable():Map<K,V> return this;

}
