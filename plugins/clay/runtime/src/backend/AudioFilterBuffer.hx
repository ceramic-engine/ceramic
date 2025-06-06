package backend;

#if cpp
abstract AudioFilterBuffer(cpp.Pointer<cpp.Float32>) {

    inline public function new(buffer:cpp.Pointer<cpp.Float32>) {
        this = buffer;
    }

    inline public function setBuffer(buffer:cpp.Pointer<cpp.Float32>):Void {
        this = buffer;
    }

    @:arrayAccess
    public inline function get(index:Int):cpp.Float32 {
        return this[index];
    }

    @:arrayAccess
    public inline function set(index:Int, value:cpp.Float32):cpp.Float32 {
        this[index] = value;
        return value;
    }

}
#end
