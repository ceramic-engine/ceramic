package backend;

#if !no_backend_docs
/**
 * Audio filter buffer abstraction for Unity backend.
 * 
 * This type wraps Unity's native array of audio samples (Single/float values)
 * and provides a Haxe-friendly interface for audio processing. The buffer
 * contains raw PCM audio data that can be read and modified by audio filters.
 * 
 * In Unity's audio system, these buffers are passed to OnAudioFilterRead
 * callbacks where real-time DSP processing occurs. The abstract type ensures:
 * - Zero-overhead access to the underlying native array
 * - Type safety when working with audio data
 * - Compatibility with Ceramic's audio filter API
 * 
 * Buffer format:
 * - Interleaved samples for multi-channel audio
 * - Values typically range from -1.0 to 1.0
 * - Sample rate and channel count provided separately
 * 
 * @see backend.Audio._unityFilterProcess Where these buffers are processed
 * @see ceramic.AudioFilterWorklet The worklets that process these buffers
 */
#end
#if documentation

typedef AudioFilterBuffer = cs.NativeArray<Single>;

#else

@:forward
@:arrayAccess
abstract AudioFilterBuffer(cs.NativeArray<Single>)
    from cs.NativeArray<Single>
    to cs.NativeArray<Single> {

    #if !no_backend_docs
    /**
     * Set a sample value at the given index.
     * @param index Sample index in the buffer
     * @param value Sample value (typically -1.0 to 1.0)
     */
    #end
    @:arrayAccess extern inline function set(index:Int, value:Float):Void {
        this[index] = value;
    }
    
    #if !no_backend_docs
    /**
     * Get a sample value at the given index.
     * @param index Sample index in the buffer
     * @return Sample value
     */
    #end
    @:arrayAccess extern inline function get(index:Int):Float {
        return this[index];
    }

}

#end
