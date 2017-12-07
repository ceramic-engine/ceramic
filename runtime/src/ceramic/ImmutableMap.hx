package ceramic;

@:forward(get, exists, keys, iterator, toString)
abstract ImmutableMap<K,V>(Map<K,V>) from Map<K,V> to Map<K,V> {

    @:arrayAccess @:extern inline public function arrayAccess(key:K):V return this.get(key);

} //ImmutableMap
