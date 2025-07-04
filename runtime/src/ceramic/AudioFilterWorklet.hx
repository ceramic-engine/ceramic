package ceramic;

#if sys
import haxe.atomic.AtomicBool;
import haxe.atomic.AtomicInt;
#end

/**
 * The actual worklet class that will do the audio processing of a given `AudioFilter`
 */
#if (!macro && !display && !completion)
@:autoBuild(ceramic.macros.AudioFiltersMacro.buildWorklet())
#end
abstract class AudioFilterWorklet {

    /**
     * The id of the audio fitler this worklet is associated with
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

    private final params:Array<Float> = [];

    /**
     * Get a boolean parameter at the given position (0-based)
     */
    private function getBool(index:Int):Bool {
        final val:Null<Float> = params[index];
        return val != null ? val != 0 : false;
    }

    /**
     * Get an int parameter at the given position (0-based)
     */
    private function getInt(index:Int):Int {
        final val:Null<Float> = params[index];
        return val != null ? Std.int(val) : 0;
    }

    /**
     * Get a float parameter at the given position (0-based)
     */
    private function getFloat(index:Int):Float {
        final val:Null<Float> = params[index];
        return val != null ? val : 0;
    }

    public function new(filterId:Int, bus:Int) {
        this.filterId = filterId;
        this.bus = bus;
    }

    /**
     * Process audio buffer in place. Override this method to implement custom filtering.
     * CAUTION: this may be called from a background thread
     * @param buffer The audio buffer to process (modify in place)
     * @param samples Number of samples per channel
     * @param channels Number of audio channels (1 = mono, 2 = stereo)
     * @param sampleRate Sample rate in Hz
     * @param time Current playback time in seconds
     */
    public abstract function process(buffer:AudioFilterBuffer, samples:Int, channels:Int, sampleRate:Float, time:Float):Void;

}

