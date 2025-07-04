package ceramic;

import ceramic.Shortcuts.*;

/**
 * Base class for audio filters that can process audio buffers in real-time.
 * Subclass this to create custom audio filters.
 */
#if !macro
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
    private final paramsAcquireLock = new ceramic.SpinLock();
    #end

    private final params:Array<Float> = [];

    private var paramsChanged:Bool = false;

    private var paramsAcquired:Bool = false;

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

    private function setBool(index:Int, value:Bool):Void {
        #if sys
        paramsAcquireLock.acquire();
        #end
        var selfAcquireParams = !paramsAcquired;
        #if sys
        paramsAcquireLock.release();
        #end
        if (selfAcquireParams) {
            acquireParams();
        }
        final prevValue = params[index];
        final newValue = value ? 1.0 : 0.0;
        params[index] = newValue;
        if (newValue != prevValue) {
            paramsChanged = true;
        }
        if (selfAcquireParams) {
            releaseParams();
        }
    }

    private function setInt(index:Int, value:Int):Void {
        #if sys
        paramsAcquireLock.acquire();
        #end
        var selfAcquireParams = !paramsAcquired;
        #if sys
        paramsAcquireLock.release();
        #end
        if (selfAcquireParams) {
            acquireParams();
        }
        final prevValue = params[index];
        final newValue = value;
        params[index] = newValue;
        if (newValue != prevValue) {
            paramsChanged = true;
        }
        if (selfAcquireParams) {
            releaseParams();
        }
    }

    private function setFloat(index:Int, value:Float):Void {
        #if sys
        paramsAcquireLock.acquire();
        #end
        var selfAcquireParams = !paramsAcquired;
        #if sys
        paramsAcquireLock.release();
        #end
        if (selfAcquireParams) {
            acquireParams();
        }
        final prevValue = params[index];
        final newValue = value;
        params[index] = newValue;
        if (newValue != prevValue) {
            paramsChanged = true;
        }
        if (selfAcquireParams) {
            releaseParams();
        }
    }

    public function acquireParams():Void {
        #if sys
        paramsLock.acquire();
        paramsAcquireLock.acquire();
        #end
        paramsChanged = false;
        paramsAcquired = true;
        #if sys
        paramsAcquireLock.release();
        #end
    }

    public function releaseParams():Void {
        var notifyChanged = paramsChanged;
        #if sys
        paramsAcquireLock.acquire();
        #end
        paramsChanged = false;
        paramsAcquired = false;
        #if sys
        paramsAcquireLock.acquire();
        paramsLock.release();
        #end
        if (notifyChanged) {
            app.backend.audio.filterParamsChanged(bus, filterId);
        }
    }

    public function new() {
        super();
        filterId = _nextFilterId++;
        _initDefaultParamValues();
    }

    @:noCompletion private function _initDefaultParamValues():Void {
        // Internal, handled by macro
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

    /**
     * Return the number of parameters this filter has.
     * (automatically generated from fields marked with `@param`, no need to override id)
     */
    @:allow(ceramic.Audio)
    public function numParams():Int {
        return 0;
    }

    override function destroy() {
        if (bus != -1) {
            audio.removeFilter(this);
        }
        super.destroy();
    }

}
