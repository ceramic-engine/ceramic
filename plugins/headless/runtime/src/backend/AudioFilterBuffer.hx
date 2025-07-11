package backend;

#if documentation

typedef AudioFilterBuffer = ceramic.Float32Array;

#else

abstract AudioFilterBuffer(ceramic.Float32Array) {

    inline public function new(buffer:ceramic.Float32Array) {
        this = buffer;
    }

    inline public function setBuffer(buffer:ceramic.Float32Array):Void {
        this = buffer;
    }

    @:arrayAccess
    public inline function get(index:Int):Float {
        return this[index];
    }

    @:arrayAccess
    public inline function set(index:Int, value:Float):Float {
        this[index] = value;
        return value;
    }

}

#end
