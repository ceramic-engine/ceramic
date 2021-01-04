package clay.buffers;

// Code imported from snowkit/snow (https://github.com/snowkit/snow/tree/fe93eb1ecfc82131a6143be1b3e3e0a274f4cf65)
// Credits go to its original author (@ruby0x1 on Github)

import clay.buffers.DataView;

#if js

    @:forward
    abstract DataViewBE(js.html.DataView)
        from js.html.DataView
        to js.html.DataView {

        public inline function new( buffer:ArrayBuffer, byteOffset:Null<Int> = null, byteLength:Null<Int> = null ) {
            if(byteOffset != null && byteLength == null) this = new js.html.DataView( buffer, byteOffset );
            else if(byteOffset != null && byteLength != null) this = new js.html.DataView( buffer, byteOffset, byteLength);
            else this = new js.html.DataView( buffer );
        }

        #if !clay_no_inline_buffers inline #end
        public function getInt8(byteOffset:Int) : Int {
            return this.getInt8( byteOffset);
        }

        #if !clay_no_inline_buffers inline #end
        public function getInt16(byteOffset:Int) : Int {
            return this.getInt16( byteOffset, false);
        }

        #if !clay_no_inline_buffers inline #end
        public function getInt32(byteOffset:Int) : Int {
            return this.getInt32( byteOffset, false);
        }

        #if !clay_no_inline_buffers inline #end
        public function getUint8(byteOffset:Int) : UInt {
            return this.getUint8( byteOffset);
        }

        #if !clay_no_inline_buffers inline #end
        public function getUint16(byteOffset:Int) : UInt {
            return this.getUint16( byteOffset, false);
        }

        #if !clay_no_inline_buffers inline #end
        public function getUint32(byteOffset:Int) : UInt {
            return this.getUint32( byteOffset, false);
        }

        #if !clay_no_inline_buffers inline #end
        public function getFloat32(byteOffset:Int) : Float {
            return this.getFloat32( byteOffset, false);
        }

        #if !clay_no_inline_buffers inline #end
        public function getFloat64(byteOffset:Int) : Float {
            return this.getFloat64( byteOffset, false);
        }




        #if !clay_no_inline_buffers inline #end
        public function setInt8( byteOffset:Int, value:Int ) {
            this.setInt8( byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setInt16( byteOffset:Int, value:Int) {
            this.setInt16( byteOffset, value, false);
        }

        #if !clay_no_inline_buffers inline #end
        public function setInt32( byteOffset:Int, value:Int) {
            this.setInt32( byteOffset, value, false);
        }

        #if !clay_no_inline_buffers inline #end
        public function setUint8( byteOffset:Int, value:UInt ) {
            this.setUint8( byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setUint16( byteOffset:Int, value:UInt) {
            this.setUint16( byteOffset, value, false);
        }

        #if !clay_no_inline_buffers inline #end
        public function setUint32( byteOffset:Int, value:UInt) {
            this.setUint32( byteOffset, value, false);
        }

        #if !clay_no_inline_buffers inline #end
        public function setFloat32( byteOffset:Int, value:Float) {
            this.setFloat32( byteOffset, value, false);
        }

        #if !clay_no_inline_buffers inline #end
        public function setFloat64( byteOffset:Int, value:Float) {
            this.setFloat64( byteOffset, value, false);
        }

    }


#else

        /** A big endian Data view,
            where all get/set calls will read/write in BE,
            overriding the behavior of the underlying dataview.
            Note that this class doesn't work correctly (yet) on CPP! */
    class DataViewBE {

        public var buffer:ArrayBuffer;
        public var byteLength:Int;
        public var byteOffset:Int;

        #if !clay_no_inline_buffers inline #end
        public function new(buffer:ArrayBuffer, byteOffset:Int = 0, byteLength:Null<Int> = null) {

            if(byteOffset < 0) throw TAError.RangeError('DataView: byteOffset can\'t be negative');

            var bufferByteLength = buffer.length;
            var viewByteLength = bufferByteLength - byteOffset;

            if(byteOffset > bufferByteLength) throw TAError.RangeError('DataView: byteOffset is past the buffer byte length');

            if(byteLength != null) {

                if(byteLength < 0) throw TAError.RangeError('DataView: specified byteLength must be positive');

                viewByteLength = byteLength;

                if(byteOffset + viewByteLength > bufferByteLength) throw TAError.RangeError('DataView: specified range would exceed the given buffer');

            }

            this.buffer = buffer;
            this.byteLength = viewByteLength;
            this.byteOffset = byteOffset;

        }

        #if !clay_no_inline_buffers inline #end
        public function getInt8(byteOffset:Int) : Int {
            return ArrayBufferIO.getInt8(buffer, byteOffset);
        }

        #if !clay_no_inline_buffers inline #end
        public function getInt16(byteOffset:Int) : Int {
            return ArrayBufferIO.getInt16_BE(buffer, byteOffset);
        }

        #if !clay_no_inline_buffers inline #end
        public function getInt32(byteOffset:Int) : Int {
            return ArrayBufferIO.getInt32_BE(buffer, byteOffset);
        }

        #if !clay_no_inline_buffers inline #end
        public function getUint8(byteOffset:Int) : UInt {
            return ArrayBufferIO.getUint8(buffer, byteOffset);
        }

        #if !clay_no_inline_buffers inline #end
        public function getUint16(byteOffset:Int) : UInt {
            return ArrayBufferIO.getUint16_BE(buffer, byteOffset);
        }

        #if !clay_no_inline_buffers inline #end
        public function getUint32(byteOffset:Int) : UInt {
            return ArrayBufferIO.getUint32_BE(buffer, byteOffset);
        }

        #if !clay_no_inline_buffers inline #end
        public function getFloat32(byteOffset:Int) : Float {
            return ArrayBufferIO.getFloat32_BE(buffer, byteOffset);
        }

        #if !clay_no_inline_buffers inline #end
        public function getFloat64(byteOffset:Int) : Float {
            return ArrayBufferIO.getFloat64_BE(buffer, byteOffset);
        }

        #if !clay_no_inline_buffers inline #end
        public function setInt8( byteOffset:Int, value:Int ) {
            ArrayBufferIO.setInt8(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setInt16( byteOffset:Int, value:Int) {
            ArrayBufferIO.setInt16_BE(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setInt32( byteOffset:Int, value:Int) {
            ArrayBufferIO.setInt32_BE(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setUint8( byteOffset:Int, value:UInt ) {
            ArrayBufferIO.setUint8(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setUint16( byteOffset:Int, value:UInt) {
            ArrayBufferIO.setUint16_BE(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setUint32( byteOffset:Int, value:UInt) {
            ArrayBufferIO.setUint32_BE(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setFloat32( byteOffset:Int, value:Float) {
            ArrayBufferIO.setFloat32_BE(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setFloat64( byteOffset:Int, value:Float) {
            ArrayBufferIO.setFloat64_BE(buffer, byteOffset, value);
        }

    }

#end //!js
