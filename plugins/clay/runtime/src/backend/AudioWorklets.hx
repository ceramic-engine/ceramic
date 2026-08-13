package backend;

#if (cpp && ceramic_standalone_audio_worklets)

/**
 * Bindings to the standalone `audio_worklets` library (plain C++
 * transpiled from the worklet haxe sources by reflaxe.CPP + a C ABI
 * glue), used when `ceramic_standalone_audio_worklets` is enabled.
 *
 * In that mode, audio worklet processing runs entirely outside of the
 * hxcpp runtime: the audio thread executes only plain C++ and is never
 * attached to hxcpp (no GC interaction, no GC pauses).
 *
 * All the functions below are called from the main thread; the audio
 * thread side is wired directly at the C++ level through the
 * `audio_worklets_clay_*` callbacks (see `busFilterCallbacks()`).
 */
@:keep
@:include('audio_worklets.h')
@:build(backend.AudioWorkletsLinc.xml('audio_worklets', '../../../audio/'))
extern class AudioWorklets {

    /**
     * Initializes the library (runs the generated haxe main(), which
     * registers the generated worklet factory). Call once.
     */
    @:native('audio_worklets_init')
    static function init():Void;

    /**
     * Creates a worklet of the given class (fully qualified haxe class
     * name) and queues it for processing on the given bus.
     * Returns 1 on success, 0 if the class name is unknown.
     */
    @:native('audio_worklets_add_bus_filter')
    static function addBusFilter(bus:Int, filterId:Int, workletClass:cpp.ConstCharStar):Int;

    /**
     * Queues the removal of the worklet associated with the given filter.
     */
    @:native('audio_worklets_destroy_bus_filter')
    static function destroyBusFilter(bus:Int, filterId:Int):Void;

    /**
     * Updates the worklet parameter values of the given filter
     * (values are copied; safe with regard to the audio thread).
     */
    @:native('audio_worklets_set_params')
    static function setParams(bus:Int, filterId:Int, values:cpp.RawConstPointer<cpp.Float32>, count:Int):Void;

    /**
     * Returns 1 once the worklet of the given filter has been
     * synchronized into the active processing list.
     */
    @:native('audio_worklets_filter_ready')
    static function filterReady(bus:Int, filterId:Int):Int;

    /**
     * Returns 1 while the audio engine has an active bus filter
     * instance on the given bus (see `audio_worklets_clay_create`).
     */
    @:native('audio_worklets_clay_bus_ready')
    static function clayBusReady(bus:Int):Int;

}

#end
