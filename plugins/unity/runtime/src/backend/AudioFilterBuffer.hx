package backend;

#if documentation

typedef AudioFilterBuffer = cs.NativeArray<Single>;

#else

@:forward
@:arrayAccess
abstract AudioFilterBuffer(cs.NativeArray<Single>)
    from cs.NativeArray<Single>
    to cs.NativeArray<Single> {

    @:arrayAccess extern inline function set(index:Int, value:Float):Void {
        this[index] = value;
    }
    @:arrayAccess extern inline function get(index:Int):Float {
        return this[index];
    }

}

#end
