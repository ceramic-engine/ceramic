package clay.buffers;

// Code imported from snowkit/snow (https://github.com/snowkit/snow/tree/fe93eb1ecfc82131a6143be1b3e3e0a274f4cf65)
// Credits go to its original author (@ruby0x1 on Github)

#if js

    @:forward
    abstract Int8Array(js.html.Int8Array)
        from js.html.Int8Array
        to js.html.Int8Array {

        public inline static var BYTES_PER_ELEMENT : Int = 1;

        inline public function new(_elements:Int) {
            this = new js.html.Int8Array(_elements);
        }
        
        inline static public function fromArray<T>(_array:Array<T>) : Int8Array {
            return new js.html.Int8Array(untyped _array);
        }
        
        inline static public function fromView(_view:ArrayBufferView) : Int8Array {
            return new js.html.Int8Array(untyped _view);
        }
        
        inline static public function fromBuffer(_buffer:ArrayBuffer, _byteOffset:Int, _byteLength:Int) : Int8Array {
            return new js.html.Int8Array(_buffer, _byteOffset, _byteLength);
        }


        @:arrayAccess @:extern inline function __set(idx:Int, val:Int) : Void this[idx] = val;
        @:arrayAccess @:extern inline function __get(idx:Int) : Int return this[idx];


            //non spec haxe conversions
        inline public static function fromBytes( bytes:haxe.io.Bytes, ?byteOffset:Int=0, ?len:Int ) : Int8Array {
            return new js.html.Int8Array(cast bytes.getData(), byteOffset, len);
        }

        inline public function toBytes() : haxe.io.Bytes {
            #if (haxe_ver < 3.2)
                return @:privateAccess new haxe.io.Bytes( this.byteLength, cast new js.lib.Uint8Array(this.buffer) );
            #else
                return @:privateAccess new haxe.io.Bytes( cast new js.lib.Uint8Array(this.buffer) );
            #end
        }

        inline function toString() return 'Int8Array [byteLength:${this.byteLength}, length:${this.length}]';

    }

#else

    import clay.buffers.ArrayBufferView;
    import clay.buffers.TypedArrayType;

    @:forward
    abstract Int8Array(ArrayBufferView) from ArrayBufferView to ArrayBufferView {

        public inline static var BYTES_PER_ELEMENT : Int = 1;

        public var length (get, never):Int;

        inline public function new(_elements:Int) {
            this = ArrayBufferView.fromElements(Int8, _elements);
        }

        // @:generic
        static public inline function fromArray<T>(_array:Array<T>) : Int8Array {
            return ArrayBufferView.fromArray(Int8, cast _array);
        }

        static public inline function fromView(_view:ArrayBufferView) : Int8Array {
            return ArrayBufferView.fromView(Int8, _view);
        }

        static public inline function fromBuffer(_buffer:ArrayBuffer, _byteOffset:Int, _byteLength:Int) : Int8Array {
            return ArrayBufferView.fromBuffer(Int8, _buffer, _byteOffset, _byteLength);
        }

    //Public API

        public inline function subarray( begin:Int, end:Null<Int> = null) : Int8Array return this.subarray(begin, end);


        inline public static function fromBytes(_bytes:haxe.io.Bytes, ?_byteOffset:Int=0, ?_byteLength:Int) : Int8Array {
            if(_byteLength == null) _byteLength = _bytes.length;
            return Int8Array.fromBuffer(_bytes.getData(), _byteOffset, _byteLength);
        }

        inline public function toBytes() : haxe.io.Bytes {
            return haxe.io.Bytes.ofData(this.buffer);
        }

    //Internal

        inline function get_length() return this.length;


        @:noCompletion
        @:arrayAccess @:extern
        public inline function __get(idx:Int) {
            return ArrayBufferIO.getInt8(this.buffer, this.byteOffset+idx);
        }

        @:noCompletion
        @:arrayAccess @:extern
        public inline function __set(idx:Int, val:Int) : Void {
            ArrayBufferIO.setInt8(this.buffer, this.byteOffset+idx, val);
        }

        inline function toString() return this == null ? null : 'Int8Array [byteLength:${this.byteLength}, length:${this.length}]';

    }

#end //!js
