package backend;

#if !no_backend_docs
/**
 * Audio filter buffer implementation for the headless backend.
 * 
 * This provides an interface for audio processing buffers used
 * in audio filter chains. In headless mode, this wraps a Float32Array
 * but doesn't perform any actual audio processing since no sound
 * is generated.
 * 
 * The buffer maintains the same array access patterns as other
 * backends for API compatibility, allowing audio filter code
 * to run without modification in headless environments.
 */
#end
#if documentation

typedef AudioFilterBuffer = ceramic.Float32Array;

#else

abstract AudioFilterBuffer(ceramic.Float32Array) {

    #if !no_backend_docs
    /**
     * Creates a new audio filter buffer from a Float32Array.
     * 
     * @param buffer The underlying float array to wrap
     */
    #end
    inline public function new(buffer:ceramic.Float32Array) {
        this = buffer;
    }

    #if !no_backend_docs
    /**
     * Sets the underlying buffer to a new Float32Array.
     * 
     * @param buffer The new buffer to use
     */
    #end
    inline public function setBuffer(buffer:ceramic.Float32Array):Void {
        this = buffer;
    }

    #if !no_backend_docs
    /**
     * Gets a value from the buffer at the specified index.
     * 
     * @param index The array index to read from
     * @return The float value at the specified index
     */
    #end
    @:arrayAccess
    public inline function get(index:Int):Float {
        return this[index];
    }

    #if !no_backend_docs
    /**
     * Sets a value in the buffer at the specified index.
     * 
     * @param index The array index to write to
     * @param value The float value to store
     * @return The value that was set
     */
    #end
    @:arrayAccess
    public inline function set(index:Int, value:Float):Float {
        this[index] = value;
        return value;
    }

}

#end
