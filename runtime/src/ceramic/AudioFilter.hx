package ceramic;

import ceramic.Shortcuts.*;

/**
 * Base class for audio filters that can process audio buffers in real-time.
 * 
 * AudioFilter is an abstract class for creating custom audio effects that can be
 * attached to audio buses for real-time processing. Filters process audio data
 * as it flows through the bus, allowing effects like reverb, distortion, EQ, etc.
 * 
 * To create a custom filter:
 * 1. Extend this class
 * 2. Mark parameters with `@param` metadata
 * 3. Implement the `workletClass()` method
 * 4. Create a corresponding AudioFilterWorklet class
 * 
 * The macro system automatically generates getters/setters for `@param` fields
 * and handles thread-safe parameter updates.
 * 
 * @example
 * ```haxe
 * class MyFilter extends AudioFilter {
 *     @param public var frequency:Float = 1000;
 *     @param public var resonance:Float = 1;
 *     
 *     override function workletClass():Class<AudioFilterWorklet> {
 *         return MyFilterWorklet;
 *     }
 * }
 * 
 * // Use the filter
 * var filter = new MyFilter();
 * app.audio.addFilter(filter, 0); // Add to master bus
 * ```
 * 
 * @see AudioFilterWorklet
 * @see LowPassFilter
 * @see HighPassFilter
 */
#if !macro
@:autoBuild(ceramic.macros.AudioFiltersMacro.buildFilter())
#end
abstract class AudioFilter extends Entity {

    /**
     * Fired when the audio filter is successfully attached to a given bus.
     * When this event is emitted, the filter is fully initialized and processing audio.
     * The underlying audio worklet has been created and connected to the audio graph.
     * @param bus The bus index this filter is now attached to
     */
    @event function ready(bus:Int):Void;

    static var _nextFilterId:Int = 1;

    /**
     * The unique identifier for this filter instance.
     * Automatically assigned on creation.
     */
    public final filterId:Int;

    /**
     * The bus index this filter is currently attached to.
     * -1 means the filter is not attached to any bus.
     * Read-only - use Audio.addFilter/removeFilter to change.
     */
    public var bus:Int = -1;

    /**
     * Whether this filter is currently processing audio.
     * Set to false to bypass the filter while keeping it attached.
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
     * Get a boolean parameter at the given position.
     * Used internally by generated property getters.
     * @param index Parameter index (0-based)
     * @return Boolean value (false if null)
     */
    private function getBool(index:Int):Bool {
        final val:Null<Float> = params[index];
        return val != null ? val != 0 : false;
    }

    /**
     * Get an integer parameter at the given position.
     * Used internally by generated property getters.
     * @param index Parameter index (0-based)
     * @return Integer value (0 if null)
     */
    private function getInt(index:Int):Int {
        final val:Null<Float> = params[index];
        return val != null ? Std.int(val) : 0;
    }

    /**
     * Get a float parameter at the given position.
     * Used internally by generated property getters.
     * @param index Parameter index (0-based)
     * @return Float value (0.0 if null)
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
        if (notifyChanged && bus >= 0) {
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
     * Return the AudioFilterWorklet class that implements the actual audio processing.
     * This method must be overridden by subclasses to specify their worklet implementation.
     * The worklet class handles the real-time audio processing on the audio thread.
     * @return The worklet class to instantiate for this filter
     */
    @:allow(ceramic.Audio)
    public abstract function workletClass():Class<AudioFilterWorklet>;

    /**
     * Return the number of parameters this filter has.
     * This is automatically generated by the macro system based on `@param` fields.
     * Subclasses should not override this method.
     * @return Number of parameters
     */
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
