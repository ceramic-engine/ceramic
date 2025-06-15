package ceramic;

import ceramic.Shortcuts.*;

/**
 * Base class for audio filters that can process audio buffers in real-time.
 * Subclass this to create custom audio filters.
 */
#if (web && !macro && !display && !completion)
@:autoBuild(ceramic.macros.AudioFiltersMacro.buildFilter())
#end
abstract class AudioFilter extends Entity {

    /**
     * Fired when the audio filter is successfuly attached to a given bus.
     * When this is called, the audio filter is expected to be ready in the sense
     * that all the underlying layers have been properly plugged and the audio
     * output bus should be affected by this audio filter's worklet.
     * @param bus
     */
    @event function ready(bus:Int):Void;

    static var _nextFilterId:Int = 1;

    /**
     * The unique id of this filter
     */
    public final filterId:Int;

    /**
     * The bus this filter is attached to (-1 if not attached)
     */
    public var bus:Int = -1;

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
            app.backend.audio.filterParamsChanged(bus, filterId);
        }
    }

    public function new() {
        super();
        filterId = _nextFilterId++;
    }

    /**
     * Called when filter is attached to a bus
     */
    @:allow(ceramic.Audio)
    function attach(bus:Int):Void {
        this.bus = bus;
    }

    /**
     * Called when filter is detached from a bus
     */
    @:allow(ceramic.Audio)
    function detach(bus:Int):Void {
        this.bus = -1;
    }

    /**
     * Return the class that should be used to instanciate audio filter worklets
     */
    @:allow(ceramic.Audio)
    public abstract function workletClass():Class<AudioFilterWorklet>;

    override function destroy() {
        if (bus != -1) {
            audio.removeFilter(this);
        }
        super.destroy();
    }

}
