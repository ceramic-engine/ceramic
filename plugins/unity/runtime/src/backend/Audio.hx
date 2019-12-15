package backend;

import ceramic.Path;

using StringTools;

class Audio implements spec.Audio {

/// Lifecycle

    public function new() {}

/// Public API

    public function load(path:String, ?options:LoadAudioOptions, done:AudioResource->Void):Void {

        done(new AudioResourceImpl());

    } //load

    inline public function destroy(audio:AudioResource):Void {

        //

    } //unload

    public function mute(audio:AudioResource):AudioHandle {

        return null;

    } //mute

    public function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false):AudioHandle {

        var handle = new AudioHandleImpl();
        handle.volume = volume;
        handle.pan = pan;
        handle.pitch = pitch;
        handle.position = position;

        return handle;

    } //play

    public function pause(handle:AudioHandle):Void {
                    
        //

    } //pause

    public function resume(handle:AudioHandle):Void {
                    
        //

    } //resume

    public function stop(handle:AudioHandle):Void {
                    
        //

    } //stop

    public function getVolume(handle:AudioHandle):Float {

        return (handle:AudioHandleImpl).volume;

    } //getVolume

    public function setVolume(handle:AudioHandle, volume:Float):Void {
                    
        (handle:AudioHandleImpl).volume = volume;

    } //setVolume

    public function getPan(handle:AudioHandle):Float {
                    
        return (handle:AudioHandleImpl).pan;

    } //getPan

    public function setPan(handle:AudioHandle, pan:Float):Void {
                    
        (handle:AudioHandleImpl).pan = pan;

    } //setPan

    public function getPitch(handle:AudioHandle):Float {
                    
        return (handle:AudioHandleImpl).pitch;

    } //getPitch

    public function setPitch(handle:AudioHandle, pitch:Float):Void {
                    
        (handle:AudioHandleImpl).pitch = pitch;

    } //setPitch

    public function getPosition(handle:AudioHandle):Float {
                    
        return (handle:AudioHandleImpl).position;

    } //getPosition

    public function setPosition(handle:AudioHandle, position:Float):Void {
                    
        (handle:AudioHandleImpl).position = position;

    } //setPosition

} //Audio