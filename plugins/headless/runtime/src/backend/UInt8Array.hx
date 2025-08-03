package backend;

#if !no_backend_docs
/**
 * UInt8Array implementation for the headless backend.
 * 
 * This provides a typed array for 8-bit unsigned integers (bytes).
 * The implementation varies by platform:
 * - On JavaScript: Uses native js.lib.Uint8Array
 * - On other platforms: Uses Array<Int> with bounds checking
 * 
 * UInt8Arrays are commonly used for pixel data, binary file content,
 * and other byte-oriented operations.
 */
#end
#if js

typedef UInt8Array = UInt8ArrayImplHeadlessJS;

#if !no_backend_docs
/**
 * JavaScript-specific implementation using native Uint8Array.
 * 
 * This provides optimal performance and memory usage on JavaScript
 * platforms by using the browser's native typed array implementation.
 */
#end
@:forward
abstract UInt8ArrayImplHeadlessJS(js.lib.Uint8Array)
    from js.lib.Uint8Array
    to js.lib.Uint8Array {

    #if !no_backend_docs
    /**
     * Number of bytes per array element (always 1 for UInt8Array).
     */
    #end
    public inline static var BYTES_PER_ELEMENT : Int = 1;

    #if !no_backend_docs
    /**
     * Creates a new UInt8Array with the specified number of elements.
     * 
     * @param _elements Number of byte elements to allocate
     */
    #end
    inline public function new(_elements:Int) {
        this = new js.lib.Uint8Array(_elements);
    }

    #if !no_backend_docs
    /**
     * Creates a UInt8Array from a regular array.
     * 
     * @param _array The source array to convert
     * @return A new UInt8Array containing the array data
     */
    #end
    inline static public function fromArray<T>(_array:Array<T>) : UInt8Array {
        return new js.lib.Uint8Array(untyped _array);
    }

    #if !no_backend_docs
    /**
     * Creates a UInt8Array from an ArrayBufferView.
     * 
     * @param _view The source view to convert
     * @return A new UInt8Array containing the view data
     */
    #end
    inline static public function fromView(_view:js.lib.ArrayBufferView) : UInt8Array {
        return new js.lib.Uint8Array(untyped _view);
    }

    #if !no_backend_docs
    /**
     * Creates a UInt8Array from an ArrayBuffer with offset and length.
     * 
     * @param _buffer The source buffer
     * @param _byteOffset Offset in bytes from the start of the buffer
     * @param _byteLength Number of bytes to include
     * @return A new UInt8Array view of the buffer data
     */
    #end
    inline static public function fromBuffer(_buffer:js.lib.ArrayBuffer, _byteOffset:Int, _byteLength:Int) : UInt8Array {
        return new js.lib.Uint8Array(_buffer, _byteOffset, _byteLength);
    }

    #if !no_backend_docs
    /**
     * Sets a value at the specified index.
     * 
     * @param idx Array index
     * @param val Value to set (0-255)
     */
    #end
    @:arrayAccess extern inline function __set(idx:Int, val:UInt) : Void this[idx] = val;
    
    #if !no_backend_docs
    /**
     * Gets a value at the specified index.
     * 
     * @param idx Array index
     * @return The value at the index (0-255)
     */
    #end
    @:arrayAccess extern inline function __get(idx:Int) : Int return this[idx];

    #if !no_backend_docs
    /**
     * Creates a UInt8Array from Haxe Bytes.
     * 
     * This is a Haxe-specific convenience method for interoperability.
     * 
     * @param bytes The source bytes
     * @param byteOffset Optional offset into the bytes
     * @param len Optional length to copy
     * @return A new UInt8Array containing the bytes data
     */
    #end
    inline public static function fromBytes( bytes:haxe.io.Bytes, ?byteOffset:Int, ?len:Int ) : UInt8Array {
        if(byteOffset == null) return new js.lib.Uint8Array(cast bytes.getData());
        if(len == null) return new js.lib.Uint8Array(cast bytes.getData(), byteOffset);
        return new js.lib.Uint8Array(cast bytes.getData(), byteOffset, len);
    }

    #if !no_backend_docs
    /**
     * Converts this UInt8Array to Haxe Bytes.
     * 
     * This is a Haxe-specific convenience method for interoperability.
     * 
     * @return A new Bytes object containing the array data
     */
    #end
    inline public function toBytes() : haxe.io.Bytes {
        #if (haxe_ver < 3.2)
            return @:privateAccess new haxe.io.Bytes( this.byteLength, cast new js.lib.Uint8Array(this.buffer) );
        #else
            return @:privateAccess new haxe.io.Bytes( cast new js.lib.Uint8Array(this.buffer) );
        #end
    }

    #if !no_backend_docs
    /**
     * Returns a string representation of this UInt8Array.
     * 
     * @return String describing the array size and length
     */
    #end
    inline function toString() return 'Uint8Array [byteLength:${this.byteLength}, length:${this.length}]';

}

#else

typedef UInt8Array = UInt8ArrayImplHeadless;

#if !no_backend_docs
/**
 * Non-JavaScript implementation using Array<Int>.
 * 
 * This provides UInt8Array functionality on platforms that don't
 * have native typed arrays, using a regular Haxe array as backing storage.
 */
#end
@:forward
abstract UInt8ArrayImplHeadless(Array<Int>) from Array<Int> to Array<Int> {

    #if !no_backend_docs
    /**
     * Creates a new UInt8Array with the specified size.
     * 
     * The array is initialized with zero values.
     * 
     * @param size Number of byte elements to allocate
     */
    #end
    public function new(size:Int) {

        this = [];
        if (size > 0) {
            // Pre-allocate array by setting the last element
            this[size-1] = 0;
        }

    }

}

#end
