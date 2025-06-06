package ceramic;

import ceramic.Shortcuts.*;

/**
 * Base class for audio filters that can process audio buffers in real-time.
 * Subclass this to create custom audio filters.
 */
abstract class AudioFilter {

    static var _nextFilterId:Int = 1;

    /**
     * The unique id of this filter
     */
    public final id:Int;

    /**
     * The channel this filter is attached to (-1 if not attached)
     */
    public var channel:Int = -1;

    /**
     * Whether this filter is currently active
     */
    public var active:Bool = true;

    #if sys
    private final paramsLock = new ceramic.SpinLock();
    #end

    private final params:Array<Float> = [];

    private var paramsChanged:Bool = false;
    private var paramsAcquired:Bool = false;

    public function acquireParams():Void {
        #if sys
        paramsLock.acquire();
        #end
        paramsChanged = false;
        paramsAcquired = false;
    }

    public function releaseParams():Void {
        var notifyChanged = paramsChanged;
        paramsChanged = false;
        paramsAcquired = false;
        #if sys
        paramsLock.release();
        #end
        if (notifyChanged) {
            app.backend.audio.filterParamsChanged(channel, id);
        }
    }

    public function new() {
        id = _nextFilterId++;
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

    /**
     * Return the class that should be used to instanciate audio filter worklets
     */
    @:allow(ceramic.Audio)
    public abstract function workletClass():Class<AudioFilterWorklet>;

}
