package backend;

import ceramic.Path;

using StringTools;

class Audio implements spec.Audio {

/// Lifecycle

    public function new() {}

/// Public API

    public function load(path:String, ?options:LoadAudioOptions, done:AudioResource->Void):Void {

        done(new AudioResourceImpl());

    }

    inline public function getDuration(audio:AudioResource):Float {

        return 0;
        
    }

    inline public function destroy(audio:AudioResource):Void {

        //

    }

    public function mute(audio:AudioResource):AudioHandle {

        return null;

    }

    public function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false):AudioHandle {

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

    inline public function supportsHotReloadPath():Bool {
        
        return false;

    }

} //Audio