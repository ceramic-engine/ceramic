package backend;

import ceramic.AudioFilterBuffer;
import ceramic.AudioFilterWorklet;

/**
 * Standalone audio worklet host (pure C++ context, transpiled by
 * reflaxe.CPP — no hxcpp, no GC).
 *
 * This is the haxe side of the `libaudio_worklets` library: the C ABI
 * glue (`audio_worklets.h` / `audio_worklets.cpp`) forwards into these
 * static functions. Worklet instances are created through a generated
 * factory (a plain switch of constructor calls emitted in the generated
 * `Main.hx`), because reflection is not available in this context.
 *
 * Threading model (mirrors the hxcpp host):
 * - `addBusFilter` / `destroyBusFilter` / `setParams` are called from the
 *   game/main thread.
 * - `syncWorklets` and `processBus` are called from the audio thread.
 *
 * This code is compiled lock-free (the `ceramic.AudioFilters` locking is
 * only enabled in the hxcpp context): the embedding C++ glue
 * (`audio_worklets.cpp`) provides the synchronization around these
 * functions, with the same granularity as the hxcpp host — per-bus spin
 * locks for the params, a control spin lock for the worklet lists, and a
 * lock-free dirty fast path on the audio thread.
 */
class Audio {

    static var _factory:Null<(className:String, filterId:Int, bus:Int)->Null<AudioFilterWorklet>> = null;

    static var _worklets:Array<AudioFilterWorklet> = [];

    /**
     * Registers the generated worklet factory. Called by the generated
     * `main()` — which the embedding code must run once at startup
     * (the C glue does it in `audio_worklets_init()`).
     */
    public static function init(factory:(className:String, filterId:Int, bus:Int)->Null<AudioFilterWorklet>):Void {

        _factory = factory;

    }

    /**
     * Creates a worklet for the given class name and queues it for
     * processing on the given bus.
     * @return `true` if the class name was resolved by the factory
     */
    public static function addBusFilter(bus:Int, filterId:Int, className:String):Bool {

        if (_factory == null) return false;
        final worklet = _factory(className, filterId, bus);
        if (worklet == null) return false;

        _worklets.push(worklet);
        @:privateAccess ceramic.AudioFilters.addWorklet(worklet);
        return true;

    }

    /**
     * Queues the removal of the worklet associated with the given filter.
     */
    public static function destroyBusFilter(bus:Int, filterId:Int):Void {

        @:privateAccess ceramic.AudioFilters.destroyWorklet(bus, filterId);

        var i = _worklets.length - 1;
        while (i >= 0) {
            final worklet = _worklets[i];
            if (worklet.filterId == filterId && worklet.bus == bus) {
                _worklets.splice(i, 1);
            }
            i--;
        }

    }

    /**
     * Updates the parameters of the worklet associated with the given
     * filter (thread-safe with regard to the audio thread, using the same
     * locking protocol as the hxcpp host).
     */
    public static function setParams(bus:Int, filterId:Int, values:cxx.CArray<cxx.num.Float32>, count:Int):Void {

        final worklet = findWorklet(bus, filterId);
        if (worklet == null) return;

        @:privateAccess ceramic.AudioFilters.beginUpdateFilterWorkletParams(bus, filterId);
        final params = @:privateAccess worklet.params;
        // The worklet allocated exactly as many params as it declares
        final total = count < params.length ? count : params.length;
        for (i in 0...total) {
            params[i] = values[i];
        }
        @:privateAccess ceramic.AudioFilters.endUpdateFilterWorkletParams(bus, filterId);

    }

    /**
     * Whether the worklet of the given filter has been synchronized into
     * the active processing list (i.e. the filter is effectively
     * processing audio). Polled by the host to emit its `ready` event.
     */
    public static function isFilterReady(bus:Int, filterId:Int):Bool {

        final byBus = @:privateAccess ceramic.AudioFilters.workletsByBus;
        if (bus < byBus.length) {
            final worklets = byBus[bus];
            if (worklets != null) {
                for (i in 0...worklets.length) {
                    if (worklets[i].filterId == filterId) return true;
                }
            }
        }
        return false;

    }

    /**
     * Synchronizes pending worklet additions/removals into the active
     * per-bus processing lists. Called from the audio thread, only when
     * worklets were added or removed (the glue keeps a dirty flag).
     */
    public static function syncWorklets():Void {

        @:privateAccess ceramic.AudioFilters.syncWorklets();

    }

    /**
     * Processes one audio chunk through all the worklets of the given
     * bus. Called from the audio thread.
     * @param buffer Planar float32 samples (one channel block after another)
     */
    public static function processBus(bus:Int, buffer:cxx.CArray<cxx.num.Float32>, samples:Int, channels:Int, sampleRate:Float, time:Float):Void {

        @:privateAccess ceramic.AudioFilters.processBusAudioWorklets(
            bus, new AudioFilterBuffer(buffer), samples, channels, sampleRate, time
        );

    }

    static function findWorklet(bus:Int, filterId:Int):Null<AudioFilterWorklet> {

        for (i in 0..._worklets.length) {
            final worklet = _worklets[i];
            if (worklet.filterId == filterId && worklet.bus == bus) {
                return worklet;
            }
        }
        return null;

    }

}
