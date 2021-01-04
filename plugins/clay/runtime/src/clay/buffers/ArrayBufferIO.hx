package clay.buffers;

// Code imported from snowkit/snow (https://github.com/snowkit/snow/tree/fe93eb1ecfc82131a6143be1b3e3e0a274f4cf65)
// Credits go to its original author (@ruby0x1 on Github)

#if cpp

typedef UINT = Int

//:todo: ArrayBufferIO Big Endian

class ArrayBufferIO {

    //8

        #if !clay_no_inline_buffers @:extern inline #end
        public static function getInt8( buffer:ArrayBuffer, byteOffset:Int ) : Int {

            return untyped __global__.__hxcpp_memory_get_byte(buffer, byteOffset);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function setInt8( buffer:ArrayBuffer, byteOffset:Int, value:Int ) : Void {

            untyped __global__.__hxcpp_memory_set_byte(buffer, byteOffset, value);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function getUint8( buffer:ArrayBuffer, byteOffset:Int ) : UINT {

            return untyped __global__.__hxcpp_memory_get_byte(buffer, byteOffset) & 0xff;

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function setUint8Clamped( buffer:ArrayBuffer, byteOffset:Int, value:UINT ) : Void {

            setUint8( buffer, byteOffset, _clamp(value) );

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function setUint8( buffer:ArrayBuffer, byteOffset:Int, value:UINT ) : Void {

            untyped __global__.__hxcpp_memory_set_byte(buffer, byteOffset, value);

        }

    //16

        public static  function getInt16( buffer:ArrayBuffer, byteOffset:Int ) : Int {

            untyped return __global__.__hxcpp_memory_get_i16(buffer, byteOffset);

        }

        public static  function getInt16_BE( buffer:ArrayBuffer, byteOffset:Int ) : Int {

            untyped return __global__.__hxcpp_memory_get_i16(buffer, byteOffset);

        }

        public static function setInt16( buffer:ArrayBuffer, byteOffset:Int, value:Int ) : Void {

            untyped __global__.__hxcpp_memory_set_i16(buffer, byteOffset, value);

        }

        public static function setInt16_BE( buffer:ArrayBuffer, byteOffset:Int, value:Int ) : Void {

            untyped __global__.__hxcpp_memory_set_i16(buffer, byteOffset, value);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function getUint16( buffer:ArrayBuffer, byteOffset:Int ) : UINT {

            untyped return __global__.__hxcpp_memory_get_ui16(buffer, byteOffset) & 0xffff;

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function getUint16_BE( buffer:ArrayBuffer, byteOffset:Int ) : UINT {

            untyped return __global__.__hxcpp_memory_get_ui16(buffer, byteOffset) & 0xffff;

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function setUint16( buffer:ArrayBuffer, byteOffset:Int, value:UINT ) : Void {

            untyped __global__.__hxcpp_memory_set_ui16(buffer, byteOffset, value);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function setUint16_BE( buffer:ArrayBuffer, byteOffset:Int, value:UINT ) : Void {

            untyped __global__.__hxcpp_memory_set_ui16(buffer, byteOffset, value);

        }

    //32

        #if !clay_no_inline_buffers @:extern inline #end
        public static function getInt32( buffer:ArrayBuffer, byteOffset:Int ) : Int {

            untyped return __global__.__hxcpp_memory_get_i32(buffer, byteOffset);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function getInt32_BE( buffer:ArrayBuffer, byteOffset:Int ) : Int {

            untyped return __global__.__hxcpp_memory_get_i32(buffer, byteOffset);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function setInt32( buffer:ArrayBuffer, byteOffset:Int, value:Int ) : Void {

            untyped __global__.__hxcpp_memory_set_i32(buffer, byteOffset, value);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function setInt32_BE( buffer:ArrayBuffer, byteOffset:Int, value:Int ) : Void {

            untyped __global__.__hxcpp_memory_set_i32(buffer, byteOffset, value);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function getUint32( buffer:ArrayBuffer, byteOffset:Int ) : UINT {

            untyped return __global__.__hxcpp_memory_get_ui32(buffer, byteOffset);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function getUint32_BE( buffer:ArrayBuffer, byteOffset:Int ) : UINT {

            untyped return __global__.__hxcpp_memory_get_ui32(buffer, byteOffset);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function setUint32( buffer:ArrayBuffer, byteOffset:Int, value:UINT ) : Void {

            untyped __global__.__hxcpp_memory_set_ui32(buffer, byteOffset, value);

        }
        #if !clay_no_inline_buffers @:extern inline #end
        public static function setUint32_BE( buffer:ArrayBuffer, byteOffset:Int, value:UINT ) : Void {

            untyped __global__.__hxcpp_memory_set_ui32(buffer, byteOffset, value);

        }

    //Float

        #if !clay_no_inline_buffers @:extern inline #end
        public static function getFloat32( buffer:ArrayBuffer, byteOffset:Int ) : Float {

            untyped return __global__.__hxcpp_memory_get_float(buffer, byteOffset);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function getFloat32_BE( buffer:ArrayBuffer, byteOffset:Int ) : Float {

            untyped return __global__.__hxcpp_memory_get_float(buffer, byteOffset);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function setFloat32( buffer:ArrayBuffer, byteOffset:Int, value:Float ) : Void {

            untyped __global__.__hxcpp_memory_set_float(buffer, byteOffset, value);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function setFloat32_BE( buffer:ArrayBuffer, byteOffset:Int, value:Float ) : Void {

            untyped __global__.__hxcpp_memory_set_float(buffer, byteOffset, value);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function getFloat64( buffer:ArrayBuffer, byteOffset:Int ) : Float {

            untyped return __global__.__hxcpp_memory_get_double(buffer, byteOffset);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function getFloat64_BE( buffer:ArrayBuffer, byteOffset:Int ) : Float {

            untyped return __global__.__hxcpp_memory_get_double(buffer, byteOffset);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function setFloat64( buffer:ArrayBuffer, byteOffset:Int, value:Float ) : Void {

            untyped __global__.__hxcpp_memory_set_double(buffer, byteOffset, value);

        }

        #if !clay_no_inline_buffers @:extern inline #end
        public static function setFloat64_BE( buffer:ArrayBuffer, byteOffset:Int, value:Float ) : Void {

            untyped __global__.__hxcpp_memory_set_double(buffer, byteOffset, value);

        }

//Internal

    #if !clay_no_inline_buffers @:extern inline #end
    //clamp a Int to a 0-255 Uint8 (for Uint8Clamped array)
    static function _clamp(_in:Float) : Int {

        var _out = Std.int(_in);
        _out = _out > 255 ? 255 : _out;
        return _out < 0 ? 0 : _out;

    }

}

#else

    #error "ArrayBufferIO is only implemented for the cpp target"

#end //cpp