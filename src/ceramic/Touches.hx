package ceramic;

//typedef Touches = ceramic.internal.ReadOnlyMap<Int,Touch>;

@:allow(ceramic.Screen)
abstract Touches(Map<Int,Touch>) {
    
    /**
        Creates a new Touches map.

        This becomes a constructor call to one of the specialization types in
        the output. The rules for that are as follows:

        1. if K is a `String`, `haxe.ds.StringMap` is used
        2. if K is an `Int`, `haxe.ds.IntMap` is used
        3. if K is an `EnumValue`, `haxe.ds.EnumValueMap` is used
        4. if K is any other class or structure, `haxe.ds.ObjectMap` is used
        5. if K is any other type, it causes a compile-time error

        (Cpp) Map does not use weak indexs on ObjectMap by default.
    **/
    public function new() {
        this = new Map<Int,Touch>();
    }

    /**
        Maps `index` to `touch`.

        If `index` already has a mapping, the previous touch disappears.

        If `index` is null, the result is unspecified.
    **/
    private inline function set(index:Int, touch:Touch) this.set(index, touch);

    /**
        Returns the current mapping of `index`.

        If no such mapping exists, null is returned.

        Note that a check like `map.get(index) == null` can hold for two reasons:

        1. the map has no mapping for `index`
        2. the map has a mapping with a touch of `null`

        If it is important to distinguish these cases, `exists()` should be
        used.

        If `index` is null, the result is unspecified.
    **/
    @:arrayAccess public inline function get(index:Int) return this.get(index);

    /**
        Returns true if `index` has a mapping, false otherwise.

        If `index` is null, the result is unspecified.
    **/
    public inline function exists(index:Int) return this.exists(index);

    /**
        Removes the mapping of `index` and returns true if such a mapping existed,
        false otherwise.

        If `index` is null, the result is unspecified.
    **/
    private inline function remove(index:Int) return this.remove(index);

    /**
        Returns an Iterator over the indexs of `this` Map.

        The order of indexs is undefined.
    **/
    public inline function indexes():Iterator<Int> {
        return this.keys();
    }

    /**
        Returns an Iterator over the touchs of `this` Map.

        The order of touchs is undefined.
    **/
    public inline function iterator():Iterator<Touch> {
        return this.iterator();
    }

    /**
        Returns a String representation of `this` Touches.

        The exact representation depends on the platform and index-type.
    **/
    public inline function toString():String {
        return this.toString();
    }

    @:arrayAccess @:noCompletion public inline function arrayWrite(k:Int, v:Touch):Touch {
        this.set(k, v);
        return v;
    }

    /** Get the number of touches. Each access requires to count the elements in mapping. */
    public var length(get,never):Int;
    inline function get_length():Int { return Lambda.count(this); }

} //Touches
