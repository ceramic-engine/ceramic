package ceramic;

#if sys
import haxe.atomic.AtomicBool;
import haxe.atomic.AtomicInt;
#end

/**
 * The actual worklet class that will do the audio processing of a given `AudioFilter`
 */
abstract class AudioFilterWorklet {

    /**
     * The id of the audio fitler this worklet is associated with
     */
    public final filterId:Int;

    /**
     * The channel this filter is attached to (-1 if not attached)
     */
    #if sys
    private var _channel:AtomicInt = new AtomicInt(-1);
    public var channel(get,set):Int;
    inline function get_channel():Int {
        return _channel.load();
    }
    inline function set_channel(channel:Int):Int {
        _channel.exchange(channel);
        return channel;
    }
    #else
    public var channel:Int = -1;
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
     * Set a boolean parameter at the given position (0-based)
     */
    public function getBool(index:Int):Bool {
        final val:Null<Float> = params[index];
        return val != null ? val != 0 : false;
    }

    /**
     * Set an int parameter at the given position (0-based)
     */
    public function getInt(index:Int):Int {
        final val:Null<Float> = params[index];
        return val != null ? Std.int(val) : 0;
    }

    /**
     * Set a float parameter at the given position (0-based)
     */
    public function getFloat(index:Int):Float {
        final val:Null<Float> = params[index];
        return val != null ? val : 0;
    }

    public function new(filterId:Int, channel:Int) {
        this.filterId = filterId;
        this.channel = channel;
    }

    /**
     * Process audio buffer in place. Override this method to implement custom filtering.
     * CAUTION: this may be called from a background thread
     * @param buffer The audio buffer to process (modify in place)
     * @param samples Number of samples to process
     * @param bufferChannels Number of audio channels (1 = mono, 2 = stereo)
     * @param sampleRate Sample rate in Hz
     * @param time Current playback time in seconds
     */
    public abstract function process(buffer:AudioFilterBuffer, samples:Int, bufferChannels:Int, sampleRate:Float, time:Float):Void;

}

