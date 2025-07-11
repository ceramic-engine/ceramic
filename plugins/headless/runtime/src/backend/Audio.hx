package backend;

import ceramic.Path;

using StringTools;

class Audio implements spec.Audio {

/// Lifecycle

    public function new() {}

/// Public API

    public function load(path:String, ?options:LoadAudioOptions, _done:AudioResource->Void):Void {

        var done = function(resource:AudioResource) {
            ceramic.App.app.onceImmediate(function() {
                _done(resource);
                _done = null;
            });
        };

        done(new AudioResourceImpl());

    }

    public function createFromSamplesBuffer(buffer:Float32Array, samples:Int, channels:Int, sampleRate:Float, interleaved:Bool):AudioResource {

        return new AudioResourceImpl();

    }

    inline public function supportsHotReloadPath():Bool {

        return false;

    }

    inline public function getDuration(audio:AudioResource):Float {

        return 0;

    }

    inline public function resumeAudioContext(done:Bool->Void):Void {

        done(true);

    }

    inline public function destroy(audio:AudioResource):Void {

        //

    }

    inline public function mute(audio:AudioResource):AudioHandle {

        return null;

    }

    public function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false, channel:Int = 0):AudioHandle {

        var handle = new AudioHandleImpl();
        handle.volume = volume;
        handle.pan = pan;
        handle.pitch = pitch;
        handle.position = position;

        return handle;

    }

    public function pause(handle:AudioHandle):Void {

        //

    }

    public function resume(handle:AudioHandle):Void {

        //

    }

    public function stop(handle:AudioHandle):Void {

        //

    }

    public function getVolume(handle:AudioHandle):Float {

        return (handle:AudioHandleImpl).volume;

    }

    public function setVolume(handle:AudioHandle, volume:Float):Void {

        (handle:AudioHandleImpl).volume = volume;

    }

    public function getPan(handle:AudioHandle):Float {

        return (handle:AudioHandleImpl).pan;

    }

    public function setPan(handle:AudioHandle, pan:Float):Void {

        (handle:AudioHandleImpl).pan = pan;

    }

    public function getPitch(handle:AudioHandle):Float {

        return (handle:AudioHandleImpl).pitch;

    }

    public function setPitch(handle:AudioHandle, pitch:Float):Void {

        (handle:AudioHandleImpl).pitch = pitch;

    }

    public function getPosition(handle:AudioHandle):Float {

        return (handle:AudioHandleImpl).position;

    }

    public function setPosition(handle:AudioHandle, position:Float):Void {

        (handle:AudioHandleImpl).position = position;

    }

    public function addFilter(bus:Int, filter:ceramic.AudioFilter, onReady:(bus:Int)->Void):Void {}

    public function removeFilter(channel:Int, filterId:Int):Void {}

    public function filterParamsChanged(channel:Int, filterId:Int):Void {}

}