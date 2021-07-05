package ceramic;

#if (!documentation && cpp)

/** A map that uses int as keys and booleans as values. */
abstract IntBoolMap(IntIntMap) {

    public var size(get,never):Int;
    inline public function get_size():Int return this.size;

    public var iterableKeys(get,never):Array<Int>;
    inline function get_iterableKeys():Array<Int> return this.iterableKeys;

    inline public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {
        this = new IntIntMap(size, fillFactor, iterable);
    }

    inline public function exists(key:Int):Bool {
        return this.exists(key);
    }

    inline public function existsInline(key:Int):Bool {
        return this.existsInline(key);
    }

    inline public function get(key:Int):Bool {
        return this.get(key) != 0;
    }

    inline public function getInline(key:Int):Bool {
        return this.getInline(key) != 0;
    }

    inline public function set(key:Int, value:Bool):Void {
        this.set(key, value ? 1 : 0);
    }

    inline public function remove(key:Int):Bool {
        return this.remove(key) != 0;
    }

    public function copy():IntBoolMap {
        return cast this.copy();
    }

}

#else

abstract IntBoolMap(Map<Int,Bool>) {

    inline public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {
        this = new Map<Int,Bool>();
    }

    public var size(get,never):Int;
    inline function get_size():Int {
        return Lambda.count(this);
    }

    public var iterableKeys(get,never):Array<Int>;
    inline function get_iterableKeys():Array<Int> {
        var keys:Array<Int> = [];
        for (k in this.keys()) {
            keys.push(k);
        }
        return keys;
    }

    inline public function exists(key:Int):Bool {
        return this.exists(Std.int(key));
    }

    inline public function set(key:Int, value:Bool):Bool {
        this.set(Std.int(key), value);
        return value;
    }

    inline public function get(key:Int):Bool {
        return this.get(Std.int(key));
    }

    inline public function remove(key:Int):Bool {
        return this.remove(Std.int(key));
    }

    inline public function getInline(key:Int):Bool {
        return this.get(key);
    }

    inline public function existsInline(key:Int):Bool {
        return this.exists(key);
    }

    inline public function copy():IntBoolMap {
        return cast this.copy();
    }

}

#end
