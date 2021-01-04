package clay.buffers;

// Code imported from snowkit/snow (https://github.com/snowkit/snow/tree/fe93eb1ecfc82131a6143be1b3e3e0a274f4cf65)
// Credits go to its original author (@ruby0x1 on Github)

#if js

    @:forward
    abstract Int32Array(js.lib.Int32Array)
        from js.lib.Int32Array
        to js.lib.Int32Array {

        public inline static var BYTES_PER_ELEMENT : Int = 4;

        inline public function new(_elements:Int) {
            this = new js.lib.Int32Array(_elements);
        }

        inline static public function fromArray<T>(_array:Array<T>) : Int32Array {
            return new js.lib.Int32Array(untyped _array);
        }

        inline static public function fromView(_view:ArrayBufferView) : Int32Array {
            return new js.lib.Int32Array(untyped _view);
        }

        inline static public function fromBuffer(_buffer:ArrayBuffer, _byteOffset:Int, _byteLength:Int) : Int32Array {
            return new js.lib.Int32Array(_buffer, _byteOffset, Std.int(_byteLength/BYTES_PER_ELEMENT));
        }

        @:arrayAccess @:extern inline function __set(idx:Int, val:Int) : Void this[idx] = val;
        @:arrayAccess @:extern inline function __get(idx:Int) : Int return this[idx];


            //non spec haxe conversions
        inline public static function fromBytes( bytes:haxe.io.Bytes, ?byteOffset:Int=0, ?len:Int ) : Int32Array {
            if(byteOffset == null) return new js.lib.Int32Array(cast bytes.getData());
            if(len == null) return new js.lib.Int32Array(cast bytes.getData(), byteOffset);
            return new js.lib.Int32Array(cast bytes.getData(), byteOffset, len);
        }

        inline public function toBytes() : haxe.io.Bytes {
            #if (haxe_ver < 3.2)
                return @:privateAccess new haxe.io.Bytes( this.byteLength, cast new js.lib.Uint8Array(this.buffer) );
            #else
                return @:privateAccess new haxe.io.Bytes( cast new js.lib.Uint8Array(this.buffer) );
            #end
        }

        inline function toString() return 'Int32Array [byteLength:${this.byteLength}, length:${this.length}]';

    }

#else

    import clay.buffers.ArrayBufferView;
    import clay.buffers.TypedArrayType;

    @:forward
    abstract Int32Array(ArrayBufferView) from ArrayBufferView to ArrayBufferView {

        public inline static var BYTES_PER_ELEMENT : Int = 4;

        public var length (get, never):Int;

        inline public function new(_elements:Int) {
            this = ArrayBufferView.fromElements(Int32, _elements);
        }

        // @:generic
        static public inline function fromArray<T>(_array:Array<T>) : Int32Array {
            return ArrayBufferView.fromArray(Int32, cast _array);
        }

        static public inline function fromView(_view:ArrayBufferView) : Int32Array {
            return ArrayBufferView.fromView(Int32, _view);
        }

        static public inline function fromBuffer(_buffer:ArrayBuffer, _byteOffset:Int, _byteLength:Int) : Int32Array {
            return ArrayBufferView.fromBuffer(Int32, _buffer, _byteOffset, _byteLength);
        }

    //Public API

        public inline function subarray( begin:Int, end:Null<Int> = null) : Int32Array return this.subarray(begin, end);


        inline public static function fromBytes(_bytes:haxe.io.Bytes, ?_byteOffset:Int=0, ?_byteLength:Int) : Int32Array {
            if(_byteLength == null) _byteLength = _bytes.length;
            return Int32Array.fromBuffer(_bytes.getData(), _byteOffset, _byteLength);
        }

        inline public function toBytes() : haxe.io.Bytes {
            return haxe.io.Bytes.ofData(this.buffer);
        }

    //Internal

        inline function get_length() return this.length;


        @:noCompletion
        @:arrayAccess @:extern
        public inline function __get(idx:Int) {
            return ArrayBufferIO.getInt32(this.buffer, this.byteOffset+(idx*BYTES_PER_ELEMENT));
        }

        @:noCompletion
        @:arrayAccess @:extern
        public inline function __set(idx:Int, val:Int) : Void {
            ArrayBufferIO.setInt32(this.buffer, this.byteOffset+(idx*BYTES_PER_ELEMENT), val);
        }

        inline function toString() return this == null ? null : 'Int32Array [byteLength:${this.byteLength}, length:${this.length}]';

    }

#end //!js
