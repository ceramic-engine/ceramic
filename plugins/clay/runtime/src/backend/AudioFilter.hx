package backend;

#if sys
import haxe.atomic.AtomicBool;
import haxe.atomic.AtomicInt;
#end

abstract class AudioFilter {

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

    public function new() {}

    /**
     * Process audio buffer in place. Override this method to implement custom filtering.
     * CAUTION: this may be called from a background thread
     * @param buffer The audio buffer to process (modify in place)
     * @param samples Number of samples to process
     * @param bufferChannels Number of audio channels (1 = mono, 2 = stereo)
     * @param sampleRate Sample rate in Hz
     * @param time Current playback time in seconds
     */
    public function process(buffer:Float32Array, samples:Int, bufferChannels:Int, sampleRate:Float, time:Float):Void {

        // Override in subclasses

    }

}
