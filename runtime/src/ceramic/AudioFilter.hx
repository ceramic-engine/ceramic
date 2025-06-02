package ceramic;

/**
 * Base class for audio filters that can process audio buffers in real-time.
 * Subclass this to create custom audio filters.
 */
abstract class AudioFilter {

    /**
     * The channel this filter is attached to (-1 if not attached)
     */
    public var channel:Int = -1;

    /**
     * Whether this filter is currently active
     */
    public var active:Bool = true;

    /**
     * The actual audio filter object managed by the backend
     */
    public var backendItem:backend.AudioFilter;

    public function new() {
        backendItem = new BackendAudioFilter(this);
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
    public function process(buffer:Float32Array, samples:Int, bufferChannels:Int, sampleRate:Float, time:Float):Void {

        // Override in subclasses

    }

    /**
     * Called when filter is attached to a channel
     */
    @:allow(ceramic.Audio)
    function attach(channel:Int):Void {
        this.channel = channel;
    }

    /**
     * Called when filter is detached from a channel
     */
    @:allow(ceramic.Audio)
    function detach(channel:Int):Void {
        this.channel = -1;
    }

}

/**
 * We use a subclass of the backend audio filter implementation in order
 * to connect our high level `process()` method with the actual backend,
 * and this while ensuring there is no boxing/unboxing involved in it.
 */
@:noCompletion
class BackendAudioFilter extends backend.AudioFilter {

    final ceramicAudioFilter:ceramic.AudioFilter;

    public function new(ceramicAudioFilter:ceramic.AudioFilter) {
        super();
        this.ceramicAudioFilter = ceramicAudioFilter;
    }

    override function process(buffer:Float32Array, samples:Int, channels:Int, sampleRate:Float, time:Float):Void {
        ceramicAudioFilter.process(buffer, samples, channels, sampleRate, time);
    }

}

