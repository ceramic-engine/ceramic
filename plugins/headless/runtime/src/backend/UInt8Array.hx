package backend;

#if js

typedef UInt8Array = UInt8ArrayImplHeadlessJS;

@:forward
abstract UInt8ArrayImplHeadlessJS(js.lib.Uint8Array)
    from js.lib.Uint8Array
    to js.lib.Uint8Array {

    public inline static var BYTES_PER_ELEMENT : Int = 1;

    inline public function new(_elements:Int) {
        this = new js.lib.Uint8Array(_elements);
    }

    inline static public function fromArray<T>(_array:Array<T>) : UInt8Array {
        return new js.lib.Uint8Array(untyped _array);
    }

    inline static public function fromView(_view:js.lib.ArrayBufferView) : UInt8Array {
        return new js.lib.Uint8Array(untyped _view);
    }

    inline static public function fromBuffer(_buffer:js.lib.ArrayBuffer, _byteOffset:Int, _byteLength:Int) : UInt8Array {
        return new js.lib.Uint8Array(_buffer, _byteOffset, _byteLength);
    }

    @:arrayAccess extern inline function __set(idx:Int, val:UInt) : Void this[idx] = val;
    @:arrayAccess extern inline function __get(idx:Int) : Int return this[idx];


        //non spec haxe conversions
    inline public static function fromBytes( bytes:haxe.io.Bytes, ?byteOffset:Int, ?len:Int ) : UInt8Array {
        if(byteOffset == null) return new js.lib.Uint8Array(cast bytes.getData());
        if(len == null) return new js.lib.Uint8Array(cast bytes.getData(), byteOffset);
        return new js.lib.Uint8Array(cast bytes.getData(), byteOffset, len);
    }

    inline public function toBytes() : haxe.io.Bytes {
        #if (haxe_ver < 3.2)
            return @:privateAccess new haxe.io.Bytes( this.byteLength, cast new js.lib.Uint8Array(this.buffer) );
        #else
            return @:privateAccess new haxe.io.Bytes( cast new js.lib.Uint8Array(this.buffer) );
        #end
    }

    inline function toString() return 'Uint8Array [byteLength:${this.byteLength}, length:${this.length}]';

}

#else

typedef UInt8Array = UInt8ArrayImplHeadless;

@:forward
abstract UInt8ArrayImplHeadless(Array<Int>) from Array<Int> to Array<Int> {

    public function new(size:Int) {

        this = [];
        if (size > 0) {
            this[size-1] = 0;
        }

    }

}

#end
