package clay.buffers;

// Code imported from snowkit/snow (https://github.com/snowkit/snow/tree/fe93eb1ecfc82131a6143be1b3e3e0a274f4cf65)
// Credits go to its original author (@ruby0x1 on Github)

#if js

    @:forward
    abstract Uint16Array(js.html.Uint16Array)
        from js.html.Uint16Array
        to js.html.Uint16Array {

        public inline static var BYTES_PER_ELEMENT : Int = 2;

        inline public function new(_elements:Int) {
            this = new js.html.Uint16Array(_elements);
        }
        
        inline static public function fromArray<T>(_array:Array<T>) : Uint16Array {
            return new js.html.Uint16Array(untyped _array);
        }
        
        inline static public function fromView(_view:ArrayBufferView) : Uint16Array {
            return new js.html.Uint16Array(untyped _view);
        }
        
        inline static public function fromBuffer(_buffer:ArrayBuffer, _byteOffset:Int, _byteLength:Int) : Uint16Array {
            return new js.html.Uint16Array(_buffer, _byteOffset, Std.int(_byteLength/BYTES_PER_ELEMENT));
        }


        @:arrayAccess @:extern inline function __set(idx:Int, val:UInt) : Void this[idx] = val;
        @:arrayAccess @:extern inline function __get(idx:Int) : UInt return this[idx];


            //non spec haxe conversions
        inline public static function fromBytes( bytes:haxe.io.Bytes, ?byteOffset:Int=0, ?len:Int ) : Uint16Array {
            if(byteOffset == null) return new js.html.Uint16Array(cast bytes.getData());
            if(len == null) return new js.html.Uint16Array(cast bytes.getData(), byteOffset);
            return new js.html.Uint16Array(cast bytes.getData(), byteOffset, len);
        }

        inline public function toBytes() : haxe.io.Bytes {
            #if (haxe_ver < 3.2)
                return @:privateAccess new haxe.io.Bytes( this.byteLength, cast new js.lib.Uint8Array(this.buffer) );
            #else
                return @:privateAccess new haxe.io.Bytes( cast new js.lib.Uint8Array(this.buffer) );
            #end
        }

        inline function toString() return 'Uint16Array [byteLength:${this.byteLength}, length:${this.length}]';

    }

#else

    import clay.buffers.ArrayBufferView;
    import clay.buffers.TypedArrayType;

    @:forward
    abstract Uint16Array(ArrayBufferView) from ArrayBufferView to ArrayBufferView {

        public inline static var BYTES_PER_ELEMENT : Int = 2;

        public var length (get, never):Int;

        inline public function new(_elements:Int) {
            this = ArrayBufferView.fromElements(Uint16, _elements);
        }

        // @:generic
        static public inline function fromArray<T>(_array:Array<T>) : Uint16Array {
            return ArrayBufferView.fromArray(Uint16, cast _array);
        }

        static public inline function fromView(_view:ArrayBufferView) : Uint16Array {
            return ArrayBufferView.fromView(Uint16, _view);
        }

        static public inline function fromBuffer(_buffer:ArrayBuffer, _byteOffset:Int, _byteLength:Int) : Uint16Array {
            return ArrayBufferView.fromBuffer(Uint16, _buffer, _byteOffset, _byteLength);
        }

    //Public API

        public inline function subarray( begin:Int, end:Null<Int> = null) : Uint16Array return this.subarray(begin, end);


        inline public static function fromBytes(_bytes:haxe.io.Bytes, ?_byteOffset:Int=0, ?_byteLength:Int) : Uint16Array {
            if(_byteLength == null) _byteLength = _bytes.length;
            return Uint16Array.fromBuffer(_bytes.getData(), _byteOffset, _byteLength);
        }

        inline public function toBytes() : haxe.io.Bytes {
            return haxe.io.Bytes.ofData(this.buffer);
        }

    //Internal

        inline function get_length() return this.length;


        @:noCompletion
        @:arrayAccess @:extern
        public inline function __get(idx:Int) {
            return ArrayBufferIO.getUint16(this.buffer, this.byteOffset+(idx*BYTES_PER_ELEMENT));
        }

        @:noCompletion
        @:arrayAccess @:extern
        public inline function __set(idx:Int, val:UInt) : Void {
            ArrayBufferIO.setUint16(this.buffer, this.byteOffset+(idx*BYTES_PER_ELEMENT), val);
        }

        inline function toString() return this == null ? null : 'Uint16Array [byteLength:${this.byteLength}, length:${this.length}]';

    }

#end //!js
