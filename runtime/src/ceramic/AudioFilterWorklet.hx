package ceramic;

#if sys
import haxe.atomic.AtomicBool;
import haxe.atomic.AtomicInt;
#end

/**
 * The actual worklet class that will do the audio processing of a given `AudioFilter`.
 * 
 * AudioFilterWorklet is the base class for implementing custom audio effects and
 * processors. Each worklet runs in the audio processing pipeline and can modify
 * audio data in real-time.
 * 
 * Features:
 * - Thread-safe parameter access (atomic operations on native platforms)
 * - Automatic parameter management via @param metadata
 * - Support for boolean, int, and float parameters
 * - Per-bus audio processing
 * 
 * To create a custom filter:
 * 1. Extend this class
 * 2. Mark parameters with @param metadata
 * 3. Override the process() method
 * 4. Create an AudioFilter wrapper for public API
 * 
 * ```haxe
 * class MyEchoWorklet extends AudioFilterWorklet {
 *     @param public var delay:Float = 0.5;
 *     @param public var feedback:Float = 0.3;
 *     @param public var mix:Float = 0.5;
 *     
 *     var delayBuffer:Array<Float> = [];
 *     var writePos:Int = 0;
 *     
 *     override function process(buffer:AudioFilterBuffer, samples:Int, 
 *                              channels:Int, sampleRate:Float, time:Float):Void {
 *         // Implement echo effect here
 *     }
 * }
 * ```
 * 
 * @see AudioFilter
 * @see AudioFilters
 * @see AudioFilterBuffer
 */
#if (!macro && !display && !completion)
@:autoBuild(ceramic.macros.AudioFiltersMacro.buildWorklet())
#end
abstract class AudioFilterWorklet {

    /**
     * The id of the audio filter this worklet is associated with
     */
    public final filterId:Int;

    /**
     * The bus this filter is attached to (-1 if not attached)
     */
    #if sys
    private var _bus:AtomicInt = new AtomicInt(-1);
    public var bus(get,set):Int;
    inline function get_bus():Int {
        return _bus.load();
    }
    inline function set_bus(bus:Int):Int {
        _bus.exchange(bus);
        return bus;
    }
    #else
    public var bus:Int = -1;
    #end

    /**
     * Whether this filter is currently active
     */
    #if sys
    private var _active:AtomicBool = new AtomicBool(true);
    public var active(get,set):Bool;
    inline function get_active():Bool {
        return _active.load();
    }
    inline function set_active(active:Bool):Bool {
        _active.exchange(active);
        return active;
    }
    #else
    public var active:Bool = true;
    #end

    /**
     * Internal storage for filter parameters.
     * Populated automatically from fields marked with @param metadata.
     */
    private final params:Array<Float> = [];

    /**
     * Get a boolean parameter at the given position (0-based).
     * Parameters are stored as floats where 0 = false, non-zero = true.
     * @param index Parameter index (order matches @param field declaration order)
     * @return Boolean value of the parameter
     */
    private function getBool(index:Int):Bool {
        final val:Null<Float> = params[index];
        return val != null ? val != 0 : false;
    }

    /**
     * Get an int parameter at the given position (0-based).
     * The float value is truncated to an integer.
     * @param index Parameter index (order matches @param field declaration order)
     * @return Integer value of the parameter
     */
    private function getInt(index:Int):Int {
        final val:Null<Float> = params[index];
        return val != null ? Std.int(val) : 0;
    }

    /**
     * Get a float parameter at the given position (0-based).
     * @param index Parameter index (order matches @param field declaration order)
     * @return Float value of the parameter
     */
    private function getFloat(index:Int):Float {
        final val:Null<Float> = params[index];
        return val != null ? val : 0;
    }

    /**
     * Creates a new audio filter worklet.
     * @param filterId Unique identifier for this filter instance
     * @param bus Audio bus ID where this filter will process audio
     */
    public function new(filterId:Int, bus:Int) {
        this.filterId = filterId;
        this.bus = bus;
    }

    /**
     * Return the number of parameters this filter has.
     * (automatically generated from fields marked with `@param`, no need to override it)
     */
    public function numParams():Int {
        return 0;
    }

    /**
     * Process audio buffer in place. Override this method to implement custom filtering.
     * CAUTION: this may be called from a background thread
     * @param buffer The audio buffer to process (modify in place, planar layout: one channel after another, not interleaved)
     * @param samples Number of samples per channel
     * @param channels Number of audio channels (1 = mono, 2 = stereo)
     * @param sampleRate Sample rate in Hz
     * @param time Current playback time in seconds
     */
    public abstract function process(buffer:AudioFilterBuffer, samples:Int, channels:Int, sampleRate:Float, time:Float):Void;

}

