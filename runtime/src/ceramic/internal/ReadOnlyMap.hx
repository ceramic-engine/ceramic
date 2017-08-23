package ceramic.internal;

 /**
	Same as Map, but read-only.
**/
@:multiType(@:followWithAbstracts K)
@:allow(ceramic.Screen)
abstract ReadOnlyMap<K,V>(Map<K,V>) {

	/**
		Creates a new Map.

		This becomes a constructor call to one of the specialization types in
		the output. The rules for that are as follows:

		1. if K is a `String`, `haxe.ds.StringMap` is used
		2. if K is an `Int`, `haxe.ds.IntMap` is used
		3. if K is an `EnumValue`, `haxe.ds.EnumValueMap` is used
		4. if K is any other class or structure, `haxe.ds.ObjectMap` is used
		5. if K is any other type, it causes a compile-time error

		(Cpp) Map does not use weak keys on ObjectMap by default.
	**/
	public function new();

	/**
		Maps `key` to `value`.

		If `key` already has a mapping, the previous value disappears.

		If `key` is null, the result is unspecified.
	**/
	private inline function set(key:K, value:V) this.set(key, value);

	/**
		Returns the current mapping of `key`.

		If no such mapping exists, null is returned.

		Note that a check like `map.get(key) == null` can hold for two reasons:

		1. the map has no mapping for `key`
		2. the map has a mapping with a value of `null`

		If it is important to distinguish these cases, `exists()` should be
		used.

		If `key` is null, the result is unspecified.
	**/
	@:arrayAccess public inline function get(key:K) return this.get(key);

	/**
		Returns true if `key` has a mapping, false otherwise.

		If `key` is null, the result is unspecified.
	**/
	public inline function exists(key:K) return this.exists(key);

	/**
		Removes the mapping of `key` and returns true if such a mapping existed,
		false otherwise.

		If `key` is null, the result is unspecified.
	**/
	private inline function remove(key:K) return this.remove(key);

	/**
		Returns an Iterator over the keys of `this` Map.

		The order of keys is undefined.
	**/
	public inline function keys():Iterator<K> {
		return this.keys();
	}

	/**
		Returns an Iterator over the values of `this` Map.

		The order of values is undefined.
	**/
	public inline function iterator():Iterator<V> {
		return this.iterator();
	}

	/**
		Returns a String representation of `this` Map.

		The exact representation depends on the platform and key-type.
	**/
	public inline function toString():String {
		return this.toString();
	}

	@:arrayAccess @:noCompletion public inline function arrayWrite(k:K, v:V):V {
		this.set(k, v);
		return v;
	}

} //ReadOnlyMap
