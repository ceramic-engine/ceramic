package ceramic;

using ceramic.Extensions;

/**
 * A map that uses int as keys and booleans as values.
 */
abstract IntBoolMap(IntIntMap) {

    public var size(get,never):Int;
    inline public function get_size():Int return this.size;

    public var iterableKeys(get,never):Array<Int>;
    inline function get_iterableKeys():Array<Int> return this.iterableKeys;

    inline function _asIntBoolMap():IntBoolMap {
        return untyped this;
    }

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

    inline public function clear():Void {
        this.clear();
    }

    public function copy():IntBoolMap {
        return cast this.copy();
    }

    inline public function iterator():IntBoolMapIterator {
        return new IntBoolMapIterator(_asIntBoolMap());
    }

    inline public function keys():IntBoolMapKeyIterator {
        return new IntBoolMapKeyIterator(_asIntBoolMap());
    }

    inline public function keyValueIterator():IntBoolMapKeyValueIterator {
        return new IntBoolMapKeyValueIterator(_asIntBoolMap());
    }

}

@:allow(ceramic.IntBoolMap)
class IntBoolMapIterator {

    var intBoolMap:IntBoolMap;
    var i:Int;
    var len:Int;

    inline private function new(intBoolMap:IntBoolMap) {

        this.intBoolMap = intBoolMap;
        i = 0;
        var iterableKeys = this.intBoolMap.iterableKeys;
        len = iterableKeys != null ? iterableKeys.length : -1;

    }

    inline public function hasNext():Bool {
        return i < len;
    }

    inline public function next():Bool {

        var n = i++;
        var k = intBoolMap.iterableKeys.unsafeGet(n);
        return intBoolMap.get(k);

    }

}

@:allow(ceramic.IntBoolMap)
class IntBoolMapKeyIterator {

    var iterableKeys:Array<Int>;
    var i:Int;
    var len:Int;

    inline private function new(intBoolMap:IntBoolMap) {

        i = 0;
        iterableKeys = intBoolMap.iterableKeys;
        len = iterableKeys != null ? iterableKeys.length : -1;

    }

    inline public function hasNext():Bool {
        return i < len;
    }

    inline public function next():Int {

        var n = i++;
        return iterableKeys.unsafeGet(n);

    }

}

@:allow(ceramic.IntBoolMap)
class IntBoolMapKeyValueIterator {

    var intBoolMap:IntBoolMap;
    var i:Int;
    var len:Int;

    inline private function new(intBoolMap:IntBoolMap) {

        this.intBoolMap = intBoolMap;
        i = 0;
        var iterableKeys = this.intBoolMap.iterableKeys;
        len = iterableKeys != null ? iterableKeys.length : -1;

    }

    inline public function hasNext():Bool {
        return i < len;
    }

    inline public function next():{ key:Int, value:Bool } {

        var n = i++;
        var k = intBoolMap.iterableKeys.unsafeGet(n);
        return { key: k, value: intBoolMap.get(k) };

    }

}

