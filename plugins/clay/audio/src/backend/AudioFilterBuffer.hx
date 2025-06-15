package backend;

@:forward
@:arrayAccess
abstract AudioFilterBuffer(js.lib.Float32Array)
    from js.lib.Float32Array
    to js.lib.Float32Array {

    @:arrayAccess extern inline function set(index:Int, value:Float):Void {
        this[index] = value;
    }
    @:arrayAccess extern inline function get(index:Int):Float {
        return this[index];
    }

}
