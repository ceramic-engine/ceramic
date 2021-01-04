package clay.buffers;

// Code imported from snowkit/snow (https://github.com/snowkit/snow/tree/fe93eb1ecfc82131a6143be1b3e3e0a274f4cf65)
// Credits go to its original author (@ruby0x1 on Github)

#if js

    typedef ArrayBufferView = js.lib.ArrayBufferView;

#else
    
    using cpp.NativeArray;
    import clay.buffers.TypedArrayType;

    class ArrayBufferView {

        public var type = TypedArrayType.None;
        public var buffer: ArrayBuffer;
        public var byteOffset: Int;
        public var byteLength: Int;
        public var length: Int;

            //internal for avoiding switching on types
        var bytesPerElement (default,null) : Int = 0;

        @:allow(clay.buffers)
        #if !clay_no_inline_buffers inline #end
        function new(in_type:TypedArrayType) {

            type = in_type;
            bytesPerElement = bytesForType(type);

        }

    //Constructor helpers

        @:allow(clay.buffers)
        #if !clay_no_inline_buffers inline #end
        static function fromElements(_type:TypedArrayType, _elements:Int) : ArrayBufferView {

            if(_elements < 0) _elements = 0;
            //:note:spec: also has, platform specific max int?
            //_elements = min(_elements,maxint);

            var _view = new ArrayBufferView(_type);
            var _bytelen = _view.toByteLength(_elements);

                _view.byteOffset = 0;
                _view.byteLength = _bytelen;
                _view.buffer = new ArrayBuffer(_bytelen);
                _view.length = _elements;

            return _view;

        }

        @:allow(clay.buffers)
        #if !clay_no_inline_buffers inline #end
        static function fromView(_type:TypedArrayType, _other:ArrayBufferView) : ArrayBufferView {

            var _src_type = _other.type;
            var _src_data = _other.buffer;
            var _src_length = _other.length;
            var _src_byte_offset = _other.byteOffset;

            var _view = new ArrayBufferView(_type);

                    //same TypedArrayType, so just blit the data.
                    //In other words, it shares the same bytes per element etc
                if(_src_type == _type) {
                    _view.cloneBuffer(_src_data, _src_byte_offset);
                } else {                    
                    throw ("unimplemented"); //see :note:1: below use FPHelper!
                }

            _view.byteLength = _view.bytesPerElement * _src_length;
            _view.byteOffset = 0;
            _view.length = _src_length;

            return _view;

        }

        @:allow(clay.buffers)
        #if !clay_no_inline_buffers inline #end
        static function fromBuffer(_type:TypedArrayType, _buffer:ArrayBuffer, _byte_offset:Int, _byte_length:Int, ?_view:ArrayBufferView) : ArrayBufferView {

            if (_view == null) _view = new ArrayBufferView(_type);
            var _bytes_per_elem = _view.bytesPerElement;

            if(_byte_offset < 0) throw TAError.RangeError('fromBuffer: byte offset must be positive (> 0)');
            if(_byte_offset % _bytes_per_elem != 0) throw TAError.RangeError('fromBuffer: byte offset must be aligned with the bytes per element');

            var _src_bytelen = _buffer.length;
            var _new_range = _byte_offset + _byte_length;
            if( _new_range > _src_bytelen ) throw TAError.RangeError('fromBuffer: specified range would exceed the source buffer');

            _view.buffer = _buffer;
            _view.byteOffset = _byte_offset;
            _view.byteLength = _byte_length;
            _view.length = Std.int(_byte_length / _bytes_per_elem);

            return _view;

        }


        @:allow(clay.buffers)
        #if !clay_no_inline_buffers inline #end
        static function fromArray(_type:TypedArrayType, _array:Array<Float>) : ArrayBufferView {

            var _view = new ArrayBufferView(_type);
            var _length = _array.length;
            var _bytelen = _view.toByteLength(_length);

                _view.byteOffset = 0;
                _view.length = _length;
                _view.byteLength = _bytelen;
                _view.buffer = new ArrayBuffer(_bytelen);

                _view.copyFromArray(_array);

            return _view;

        }


    //Public shared APIs

    //T is required because it can translate [0,0] as Int array
        #if !clay_no_inline_buffers inline #end
    public function set( ?view:ArrayBufferView, ?array:Array<Float>, offset:Int = 0 ) : Void {

        if(view != null && array == null) {
            buffer.blit( toByteLength(offset), view.buffer, view.byteOffset, view.byteLength );
        } else if(array != null && view == null) {
            copyFromArray(array, offset);
        } else {
            throw "Invalid .set call. either view, or array must be not-null.";
        }

    }


    //Internal TypedArray api

        #if !clay_no_inline_buffers inline #end
        function cloneBuffer(src:ArrayBuffer, srcByteOffset:Int = 0) {

            var srcLength = src.length;
            var cloneLength = srcLength - srcByteOffset;

            buffer = new ArrayBuffer(cloneLength);

            buffer.blit( 0, src, srcByteOffset, cloneLength );

        }


        @:generic
        @:allow(clay.buffers)
        #if !clay_no_inline_buffers inline #end
        function subarray<T_subarray>( begin:Int, end:Null<Int> = null ) : T_subarray {

            if (end == null) end == length;
            var byte_len = toByteLength(end - begin);
            var byte_offset = toByteLength(begin) + byteOffset;

            var view : ArrayBufferView =
                switch(type) {

                    case Int8:
                         Int8Array.fromBuffer(buffer, byte_offset, byte_len);

                    case Int16:
                         Int16Array.fromBuffer(buffer, byte_offset, byte_len);

                    case Int32:
                         Int32Array.fromBuffer(buffer, byte_offset, byte_len);

                    case Uint8:
                         Uint8Array.fromBuffer(buffer, byte_offset, byte_len);

                    case Uint8Clamped:
                         Uint8ClampedArray.fromBuffer(buffer, byte_offset, byte_len);

                    case Uint16:
                         Uint16Array.fromBuffer(buffer, byte_offset, byte_len);

                    case Uint32:
                         Uint32Array.fromBuffer(buffer, byte_offset, byte_len);

                    case Float32:
                         Float32Array.fromBuffer(buffer, byte_offset, byte_len);

                    case Float64:
                         Float64Array.fromBuffer(buffer, byte_offset, byte_len);

                    case None:
                        throw "subarray on a blank ArrayBufferView";
                }

            return cast view;

        }

        #if !clay_no_inline_buffers inline #end
        function bytesForType( type:TypedArrayType ) : Int {

            return
                switch(type) {

                    case Int8:
                         Int8Array.BYTES_PER_ELEMENT;

                    case Uint8:
                         Uint8Array.BYTES_PER_ELEMENT;

                    case Uint8Clamped:
                         Uint8ClampedArray.BYTES_PER_ELEMENT;

                    case Int16:
                         Int16Array.BYTES_PER_ELEMENT;

                    case Uint16:
                         Uint16Array.BYTES_PER_ELEMENT;

                    case Int32:
                         Int32Array.BYTES_PER_ELEMENT;

                    case Uint32:
                         Uint32Array.BYTES_PER_ELEMENT;

                    case Float32:
                         Float32Array.BYTES_PER_ELEMENT;

                    case Float64:
                         Float64Array.BYTES_PER_ELEMENT;

                    case _: 1;
                }

        }

        #if !clay_no_inline_buffers inline #end
        function toString() {

            var name =
                switch(type) {
                    case Int8: 'Int8Array';
                    case Uint8: 'Uint8Array';
                    case Uint8Clamped: 'Uint8ClampedArray';
                    case Int16: 'Int16Array';
                    case Uint16: 'Uint16Array';
                    case Int32: 'Int32Array';
                    case Uint32: 'Uint32Array';
                    case Float32: 'Float32Array';
                    case Float64: 'Float64Array';
                    case _: 'ArrayBufferView';
                }

            return name + ' [byteLength:${this.byteLength}, length:${this.length}]';

        }

        #if !clay_no_inline_buffers inline #end
        function toByteLength( elemCount:Int ) : Int {

            return elemCount * bytesPerElement;

        }

    //Non-spec

        #if !clay_no_inline_buffers #end
        function copyFromArray(array:Array<Float>, ?offset : Int = 0 ) {

            //Ideally, native semantics could be used, like cpp.NativeArray.blit
            var i = 0, len = array.length;

            switch(type) {
                case Int8:
                    while(i<len) {
                        var pos = (offset+i)*bytesPerElement;
                        ArrayBufferIO.setInt8(buffer,
                            pos, Std.int(array[i]));
                        ++i;
                    }
                case Int16:
                    while(i<len) {
                        var pos = (offset+i)*bytesPerElement;
                        ArrayBufferIO.setInt16(buffer,
                            pos, Std.int(array[i]));
                        ++i;
                    }
                case Int32:
                    while(i<len) {
                        var pos = (offset+i)*bytesPerElement;
                        ArrayBufferIO.setInt32(buffer,
                            pos, Std.int(array[i]));
                        ++i;
                    }
                case Uint8:
                    while(i<len) {
                        var pos = (offset+i)*bytesPerElement;
                        ArrayBufferIO.setUint8(buffer,
                            pos, Std.int(array[i]));
                        ++i;
                    }
                case Uint16:
                    while(i<len) {
                        var pos = (offset+i)*bytesPerElement;
                        ArrayBufferIO.setUint16(buffer,
                            pos, Std.int(array[i]));
                        ++i;
                    }
                case Uint32:
                    while(i<len) {
                        var pos = (offset+i)*bytesPerElement;
                        ArrayBufferIO.setUint32(buffer,
                            pos, Std.int(array[i]));
                        ++i;
                    }
                case Uint8Clamped:
                    while(i<len) {
                        var pos = (offset+i)*bytesPerElement;
                        ArrayBufferIO.setUint8Clamped(buffer,
                            pos, Std.int(array[i]));
                        ++i;
                    }
                case Float32:
                    while(i<len) {
                        var pos = (offset+i)*bytesPerElement;
                        ArrayBufferIO.setFloat32(buffer,
                            pos, array[i]);
                        ++i;
                    }
                case Float64:
                    while(i<len) {
                        var pos = (offset+i)*bytesPerElement;
                        ArrayBufferIO.setFloat64(buffer,
                            pos, array[i]);
                        ++i;
                    }

                case None:
                    throw "copyFromArray on a base type ArrayBuffer";

            }

        }

    }

#end //!js
