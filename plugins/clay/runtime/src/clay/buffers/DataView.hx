package clay.buffers;

// Code imported from snowkit/snow (https://github.com/snowkit/snow/tree/fe93eb1ecfc82131a6143be1b3e3e0a274f4cf65)
// Credits go to its original author (@ruby0x1 on Github)

#if js

    @:forward
    abstract DataView(js.html.DataView)
        from js.html.DataView
        to js.html.DataView {

        public inline function new(buffer:ArrayBuffer, byteOffset:Null<Int> = null, byteLength:Null<Int> = null) {
            if(byteOffset != null && byteLength == null) this = new js.html.DataView(buffer, byteOffset);
            else if(byteOffset != null && byteLength != null) this = new js.html.DataView(buffer, byteOffset, byteLength);
            else this = new js.html.DataView(buffer);
        }

        #if !clay_no_inline_buffers inline #end
        public function getInt8(byteOffset:Int) : Int {
            return this.getInt8(byteOffset);
        }

        #if !clay_no_inline_buffers inline #end
        public function getInt16(byteOffset:Int) : Int {
            return this.getInt16(byteOffset, true);
        }

        #if !clay_no_inline_buffers inline #end
        public function getInt32(byteOffset:Int) : Int {
            return this.getInt32(byteOffset, true);
        }

        #if !clay_no_inline_buffers inline #end
        public function getUint8(byteOffset:Int) : UInt {
            return this.getUint8(byteOffset);
        }

        #if !clay_no_inline_buffers inline #end
        public function getUint16(byteOffset:Int) : UInt {
            return this.getUint16(byteOffset, true);
        }

        #if !clay_no_inline_buffers inline #end
        public function getUint32(byteOffset:Int) : UInt {
            return this.getUint32(byteOffset, true);
        }

        #if !clay_no_inline_buffers inline #end
        public function getFloat32(byteOffset:Int) : Float {
            return this.getFloat32(byteOffset, true);
        }

        #if !clay_no_inline_buffers inline #end
        public function getFloat64(byteOffset:Int) : Float {
            return this.getFloat64(byteOffset, true);
        }




        #if !clay_no_inline_buffers inline #end
        public function setInt8(byteOffset:Int, value:Int) {
            this.setInt8(byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setInt16(byteOffset:Int, value:Int) {
            this.setInt16(byteOffset, value, true);
        }

        #if !clay_no_inline_buffers inline #end
        public function setInt32(byteOffset:Int, value:Int) {
            this.setInt32(byteOffset, value, true);
        }

        #if !clay_no_inline_buffers inline #end
        public function setUint8(byteOffset:Int, value:UInt) {
            this.setUint8(byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setUint16(byteOffset:Int, value:UInt) {
            this.setUint16(byteOffset, value, true);
        }

        #if !clay_no_inline_buffers inline #end
        public function setUint32(byteOffset:Int, value:UInt) {
            this.setUint32(byteOffset, value, true);
        }

        #if !clay_no_inline_buffers inline #end
        public function setFloat32(byteOffset:Int, value:Float) {
            this.setFloat32(byteOffset, value, true);
        }

        #if !clay_no_inline_buffers inline #end
        public function setFloat64(byteOffset:Int, value:Float) {
            this.setFloat64(byteOffset, value, true);
        }

    }

#else

    import clay.buffers.ArrayBuffer;

    class DataView {

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
            return ArrayBufferIO.getInt16(buffer, byteOffset);                
        }

        #if !clay_no_inline_buffers inline #end
        public function getInt32(byteOffset:Int) : Int {
            return ArrayBufferIO.getInt32(buffer, byteOffset);                
        }

        #if !clay_no_inline_buffers inline #end
        public function getUint8(byteOffset:Int) : UInt {
            return ArrayBufferIO.getUint8(buffer, byteOffset);
        }

        #if !clay_no_inline_buffers inline #end
        public function getUint16(byteOffset:Int) : UInt {
            return ArrayBufferIO.getUint16(buffer, byteOffset);                
        }

        #if !clay_no_inline_buffers inline #end
        public function getUint32(byteOffset:Int) : UInt {
            return ArrayBufferIO.getUint32(buffer, byteOffset);                
        }

        #if !clay_no_inline_buffers inline #end
        public function getFloat32(byteOffset:Int) : Float {
            return ArrayBufferIO.getFloat32(buffer, byteOffset);                
        }

        #if !clay_no_inline_buffers inline #end
        public function getFloat64(byteOffset:Int) : Float {
            return ArrayBufferIO.getFloat64(buffer, byteOffset);                
        }



        #if !clay_no_inline_buffers inline #end
        public function setInt8(byteOffset:Int, value:Int) {
            ArrayBufferIO.setInt8(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setInt16(byteOffset:Int, value:Int) {
            ArrayBufferIO.setInt16(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setInt32(byteOffset:Int, value:Int) {
            ArrayBufferIO.setInt32(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setUint8(byteOffset:Int, value:UInt) {
            ArrayBufferIO.setUint8(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setUint16(byteOffset:Int, value:UInt) {
            ArrayBufferIO.setUint16(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setUint32(byteOffset:Int, value:UInt) {
            ArrayBufferIO.setUint32(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setFloat32(byteOffset:Int, value:Float) {
            ArrayBufferIO.setFloat32(buffer, byteOffset, value);
        }

        #if !clay_no_inline_buffers inline #end
        public function setFloat64(byteOffset:Int, value:Float) {
            ArrayBufferIO.setFloat64(buffer, byteOffset, value);
        }


    }

#end //!js
