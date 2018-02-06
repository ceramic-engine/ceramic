package backend;

import haxe.io.Path;

using StringTools;

class Audio #if !completion implements spec.Audio #end {

/// Internal

    var loopingStreams:Map<AudioHandle,Bool> = new Map();
    var loopHandles:Map<AudioHandle,AudioHandle> = new Map();

/// Lifecycle

    public function new() {}

/// Public API

    public function load(path:String, ?options:LoadAudioOptions, done:AudioResource->Void):Void {

        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        Luxe.resources.load_audio(path, {
            is_stream: options != null ? options.stream : false
        })
        .then(function(audio:AudioResource) {
            done(audio);
        },
        function(_) {
            done(null);
        });

    } //load

    inline public function destroy(audio:AudioResource):Void {

        (audio:luxe.resource.Resource.AudioResource).destroy(true);

    } //unload

    public function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false):AudioHandle {

        if (!Luxe.audio.active) return -1;

        var audioResource:luxe.resource.Resource.AudioResource = audio;
        var isStream = audioResource.source.data.is_stream;

        // These options are ignored on streamed sounds
        // at the moment
        if (isStream) {
            position = 0;
            pitch = 1;
            pan = 0;
        }

        var handle:AudioHandle = null;
        if (loop) {

            /*if (true) {

                // At the moment, looping a stream doesn't seem reliable in luxe/snow/openal.
                // When looping a stream, let's manage ourselve the loop by
                // checking the position and playing again from start.

                var duration = audioResource.source.duration();
                handle = Luxe.audio.play(audioResource.source, volume, false);
                var firstHandle = handle;
                loopingStreams.set(handle, true);
                var pos:Float = 0;

                var onUpdate = null;
                onUpdate = function(delta) {

                    if (!Luxe.audio.active) return;

                    if (loopingStreams.exists(handle)) {

                        var playing = loopingStreams.get(handle);
                        if (playing) {

                            var instance = Luxe.audio.instance_of(handle);
                            if (instance != null) {
                                pos = Luxe.audio.position_of(handle);
                                if (pos < duration) volume = Luxe.audio.volume_of(handle);

                                if (pos >= duration - 1.0/60) {
                                    // End of loop, start from 0 again
                                    loopingStreams.remove(handle);
                                    Luxe.audio.stop(handle);
                                    handle = Luxe.audio.play(audioResource.source, volume, false);
                                    loopingStreams.set(handle, true);
                                    loopHandles.set(firstHandle, handle);
                                }
                            }
                            else {
                                // Sound instance was destroyed when looping (it can happen), restore it
                                // Not perfect: the stream is resumed from the beginning regardless
                                // of where it was stopped.
                                loopingStreams.remove(handle);
                                handle = Luxe.audio.play(audioResource.source, volume, false);
                                loopingStreams.set(handle, true);
                                loopHandles.set(firstHandle, handle);
                            }
                        }

                    } else {
                        ceramic.App.app.offUpdate(onUpdate);
                    }

                };
                ceramic.App.app.onUpdate(onUpdate);

            } else {*/
                handle = Luxe.audio.loop(audioResource.source, volume, false);
            //}

        } else {
            handle = Luxe.audio.play(audioResource.source, volume, false);
        }

        if (pan != 0) Luxe.audio.pan(handle, pan);
        if (pitch != 1) Luxe.audio.pitch(handle, pitch);
        if (position != 0) Luxe.audio.position(handle, position);

        return handle;

    } //play

    public function pause(handle:AudioHandle):Void {
                    
        if (!Luxe.audio.active) return;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        if (loopingStreams.exists(handle)) {
            loopingStreams.set(handle, false);
        }

        Luxe.audio.pause(handle);

    } //pause

    public function resume(handle:AudioHandle):Void {
                    
        if (!Luxe.audio.active) return;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        if (loopingStreams.exists(handle)) {
            loopingStreams.set(handle, true);
        }

        Luxe.audio.unpause(handle);

    } //resume

    public function stop(handle:AudioHandle):Void {
                    
        if (!Luxe.audio.active) return;
        
        if (loopHandles.exists(handle)) {
            var prevHandle = handle;
            handle = loopHandles.get(handle);
            loopHandles.remove(prevHandle);
        }

        loopingStreams.remove(handle);

        Luxe.audio.stop(handle);

    } //stop

    public function getVolume(handle:AudioHandle):Float {
                    
        if (!Luxe.audio.active) return 0;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        return Luxe.audio.volume_of(handle);

    } //getVolume

    public function setVolume(handle:AudioHandle, volume:Float):Void {
                    
        if (!Luxe.audio.active) return;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        Luxe.audio.volume(handle, volume);

    } //setVolume

    public function getPan(handle:AudioHandle):Float {
                    
        if (!Luxe.audio.active) return 0;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        return Luxe.audio.pan_of(handle);

    } //getPan

    public function setPan(handle:AudioHandle, pan:Float):Void {
                    
        if (!Luxe.audio.active) return;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        Luxe.audio.pan(handle, pan);

    } //setPan

    public function getPitch(handle:AudioHandle):Float {
                    
        if (!Luxe.audio.active) return 1;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        return Luxe.audio.pitch_of(handle);

    } //getPitch

    public function setPitch(handle:AudioHandle, pitch:Float):Void {
                    
        if (!Luxe.audio.active) return;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        Luxe.audio.pitch(handle, pitch);

    } //setPitch

    public function getPosition(handle:AudioHandle):Float {
                    
        if (!Luxe.audio.active) return 0;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        return Luxe.audio.position_of(handle);

    } //getPosition

    public function setPosition(handle:AudioHandle, position:Float):Void {
                    
        if (!Luxe.audio.active) return;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        Luxe.audio.position(handle, position);

    } //setPosition

} //Audio