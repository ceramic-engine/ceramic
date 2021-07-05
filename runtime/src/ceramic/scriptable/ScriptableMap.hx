package ceramic.scriptable;

import haxe.ds.Map;

// This is temporary, until we are able to extract methods from haxe.ds.Map abstract in ExportApi

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