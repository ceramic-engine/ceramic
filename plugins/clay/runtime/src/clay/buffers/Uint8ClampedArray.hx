package clay.buffers;

// Code imported from snowkit/snow (https://github.com/snowkit/snow/tree/fe93eb1ecfc82131a6143be1b3e3e0a274f4cf65)
// Credits go to its original author (@ruby0x1 on Github)

#if js

    @:forward
    abstract Uint8ClampedArray(js.lib.Uint8ClampedArray)
        from js.lib.Uint8ClampedArray
        to js.lib.Uint8ClampedArray {

        public inline static var BYTES_PER_ELEMENT : Int = 1;

        inline public function new(_elements:Int) {
            this = new js.lib.Uint8ClampedArray(_elements);
        }
        
        inline static public function fromArray<T>(_array:Array<T>) : Uint8ClampedArray {
            return new js.lib.Uint8ClampedArray(untyped _array);
        }
        
        inline static public function fromView(_view:ArrayBufferView) : Uint8ClampedArray {
            return new js.lib.Uint8ClampedArray(untyped _view);
        }
        
        inline static public function fromBuffer(_buffer:ArrayBuffer, _byteOffset:Int, _byteLength:Int) : Uint8ClampedArray {
            return new js.lib.Uint8ClampedArray(_buffer, _byteOffset, _byteLength);
        }

        @:arrayAccess @:extern inline function __set(idx:Int, val:UInt) : Void this[idx] = _clamp(val);
        @:arrayAccess @:extern inline function __get(idx:Int) : UInt return this[idx];


            //non spec haxe conversions
        inline public static function fromBytes( bytes:haxe.io.Bytes, ?byteOffset:Int=0, ?len:Int ) : Uint8ClampedArray {
            if(byteOffset == null) return new js.lib.Uint8ClampedArray(cast bytes.getData());
            if(len == null) return new js.lib.Uint8ClampedArray(cast bytes.getData(), byteOffset);
            return new js.lib.Uint8ClampedArray(cast bytes.getData(), byteOffset, len);
        }

        inline public function toBytes() : haxe.io.Bytes {
            #if (haxe_ver < 3.2)
                return @:privateAccess new haxe.io.Bytes( this.byteLength, cast new js.lib.Uint8Array(this.buffer) );
            #else
                return @:privateAccess new haxe.io.Bytes( cast new js.lib.Uint8Array(this.buffer) );
            #end
        }

        inline function toString() return 'Uint8ClampedArray [byteLength:${this.byteLength}, length:${this.length}]';

        //internal
        //clamp a Int to a 0-255 Uint8
        static function _clamp(_in:Float) : Int {
            var _out = Std.int(_in);
            _out = _out > 255 ? 255 : _out;
            return _out < 0 ? 0 : _out;
        }

    }

#else

    import clay.buffers.ArrayBufferView;
    import clay.buffers.TypedArrayType;

    @:forward
    @:arrayAccess
    abstract Uint8ClampedArray(ArrayBufferView) from ArrayBufferView to ArrayBufferView {

        public inline static var BYTES_PER_ELEMENT : Int = 1;

        public var length (get, never):Int;

        inline public function new(_elements:Int) {
            this = ArrayBufferView.fromElements(Uint8Clamped, _elements);
        }

        // @:generic
        static public inline function fromArray<T>(_array:Array<T>) : Uint8ClampedArray {
            return ArrayBufferView.fromArray(Uint8Clamped, cast _array);
        }

        static public inline function fromView(_view:ArrayBufferView) : Uint8ClampedArray {
            return ArrayBufferView.fromView(Uint8Clamped, _view);
        }

        static public inline function fromBuffer(_buffer:ArrayBuffer, _byteOffset:Int, _byteLength:Int) : Uint8ClampedArray {
            return ArrayBufferView.fromBuffer(Uint8Clamped, _buffer, _byteOffset, _byteLength);
        }

    //Public API

        public inline function subarray( begin:Int, end:Null<Int> = null) : Uint8ClampedArray return this.subarray(begin, end);


        inline public static function fromBytes(_bytes:haxe.io.Bytes, ?_byteOffset:Int=0, ?_byteLength:Int) : Uint8ClampedArray {
            if(_byteLength == null) _byteLength = _bytes.length;
            return Uint8ClampedArray.fromBuffer(_bytes.getData(), _byteOffset, _byteLength);
        }

        inline public function toBytes() : haxe.io.Bytes {
            return haxe.io.Bytes.ofData(this.buffer);
        }

    //Internal

        inline function get_length() return this.length;


        @:noCompletion
        @:arrayAccess @:extern
        public inline function __get(idx:Int) {
            return ArrayBufferIO.getUint8(this.buffer, this.byteOffset+idx);
        }

        @:noCompletion
        @:arrayAccess @:extern
        public inline function __set(idx:Int, val:UInt) : Void {
            ArrayBufferIO.setUint8Clamped(this.buffer, this.byteOffset+idx, val);
        }

        inline function toString() return this == null ? null : 'Uint8ClampedArray [byteLength:${this.byteLength}, length:${this.length}]';

    }

#end //!js
