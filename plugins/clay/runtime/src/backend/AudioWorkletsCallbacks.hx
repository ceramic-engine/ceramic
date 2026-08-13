package backend;

#if (cpp && ceramic_standalone_audio_worklets)

/**
 * The C++-level audio engine callbacks of the `audio_worklets` library,
 * exposed as `cpp.Callable` values that can be handed to the clay/soloud
 * bus filter API. These are raw C function pointers: when the audio
 * engine invokes them, no haxe/hxcpp code is involved at all.
 */
@:cppInclude('audio_worklets.h')
class AudioWorkletsCallbacks {

    public static function createFunc():cpp.Callable<(busIndex:Int, instanceId:Int)->Void> {
        return untyped __cpp__('::audio_worklets_clay_create');
    }

    public static function destroyFunc():cpp.Callable<(busIndex:Int, instanceId:Int)->Void> {
        return untyped __cpp__('::audio_worklets_clay_destroy');
    }

    public static function filterFunc():cpp.Callable<(busIndex:Int, instanceId:Int, aBuffer:cpp.RawPointer<cpp.Float32>, aSamples:cpp.UInt32, aChannels:cpp.UInt32, aSamplerate:cpp.Float32, time:cpp.Float64)->Void> {
        return untyped __cpp__('::audio_worklets_clay_process');
    }

}

#end
