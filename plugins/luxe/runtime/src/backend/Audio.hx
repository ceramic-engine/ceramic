package backend;

import ceramic.Path;

using StringTools;

class Audio implements spec.Audio {

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

        // Remove ?something in path
        var cleanedPath = path;
        var questionMarkIndex = cleanedPath.indexOf('?');
        if (questionMarkIndex != -1) {
            cleanedPath = cleanedPath.substr(0, questionMarkIndex);
        }

        Luxe.resources.load_audio(cleanedPath, {
            is_stream: options != null ? options.stream : false
        })
        .then(function(audio:AudioResource) {
            done(audio);
        },
        function(_) {
            done(null);
        });

    }

    inline public function getDuration(audio:AudioResource):Float {

        return (audio:luxe.resource.Resource.AudioResource).source.duration();
        
    }

    #if web
    public function resumeAudioContext(done:Bool->Void):Void {

        var webAudio:snow.modules.webaudio.Audio = cast Luxe.snow.audio.module;
        if (webAudio != null) {
            try {
                var context:Dynamic = @:privateAccess webAudio.context;
                context.resume().then(() -> {
                    done(true);
                }, () -> {
                    done(false);
                });
            }
            catch (e:Dynamic) {
                ceramic.Shortcuts.log.error('Failed to resume audio context: $e');
            }
        }

    }
    #else
    public function resumeAudioContext(done:Bool->Void):Void {
        done(true);
    }
    #end

    inline public function supportsHotReloadPath():Bool {
        
        return true;

    }

    inline public function destroy(audio:AudioResource):Void {

        (audio:luxe.resource.Resource.AudioResource).destroy(true);

    }

    inline public function mute(audio:AudioResource):AudioHandle {

        return -1;

    }

    public function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false):AudioHandle {

        if (!Luxe.audio.active) return -1;

        var audioResource:luxe.resource.Resource.AudioResource = audio;
        var isStream = audioResource.source.data.is_stream;
        volume = toBackendVolume(volume);

        // These options are ignored on streamed sounds
        // at the moment
        if (isStream) {
            position = 0;
            pitch = 1;
            pan = 0;
        }

        var handle:AudioHandle = null;
        if (loop) {

            #if cpp
            if (isStream) {

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
                ceramic.App.app.onUpdate(null, onUpdate);

            } else {
            #end
                handle = Luxe.audio.loop(audioResource.source, volume, false);
            #if cpp
            }
            #end

        } else {
            handle = Luxe.audio.play(audioResource.source, volume, false);
        }

        if (pan != 0) Luxe.audio.pan(handle, pan);
        if (pitch != 1) Luxe.audio.pitch(handle, pitch);
        if (position != 0) Luxe.audio.position(handle, position);

        return handle;

    }

    public function pause(handle:AudioHandle):Void {
                    
        if (!Luxe.audio.active) return;
        if ((handle:Int) == -1) return;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        if (loopingStreams.exists(handle)) {
            loopingStreams.set(handle, false);
        }

        Luxe.audio.pause(handle);

    }

    public function resume(handle:AudioHandle):Void {
                    
        if (!Luxe.audio.active) return;
        if ((handle:Int) == -1) return;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        if (loopingStreams.exists(handle)) {
            loopingStreams.set(handle, true);
        }

        Luxe.audio.unpause(handle);

    }

    public function stop(handle:AudioHandle):Void {
                    
        if (!Luxe.audio.active) return;
        if ((handle:Int) == -1) return;
        
        if (loopHandles.exists(handle)) {
            var prevHandle = handle;
            handle = loopHandles.get(handle);
            loopHandles.remove(prevHandle);
        }

        loopingStreams.remove(handle);

        Luxe.audio.stop(handle);

    }

    public function getVolume(handle:AudioHandle):Float {
                    
        if (!Luxe.audio.active) return 0;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        return fromBackendVolume(Luxe.audio.volume_of(handle));

    }

    public function setVolume(handle:AudioHandle, volume:Float):Void {
                    
        if (!Luxe.audio.active) return;
        if ((handle:Int) == -1) return;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        Luxe.audio.volume(handle, toBackendVolume(volume));

    }

    public function getPan(handle:AudioHandle):Float {
                    
        if (!Luxe.audio.active) return 0;
        if ((handle:Int) == -1) return 0;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        return Luxe.audio.pan_of(handle);

    }

    public function setPan(handle:AudioHandle, pan:Float):Void {
                    
        if (!Luxe.audio.active) return;
        if ((handle:Int) == -1) return;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        Luxe.audio.pan(handle, pan);

    }

    public function getPitch(handle:AudioHandle):Float {
                    
        if (!Luxe.audio.active) return 1;
        if ((handle:Int) == -1) return 1;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        return Luxe.audio.pitch_of(handle);

    }

    public function setPitch(handle:AudioHandle, pitch:Float):Void {
                    
        if (!Luxe.audio.active) return;
        if ((handle:Int) == -1) return;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        Luxe.audio.pitch(handle, pitch);

    }

    public function getPosition(handle:AudioHandle):Float {
                    
        if (!Luxe.audio.active) return 0;
        if ((handle:Int) == -1) return 0;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        return Luxe.audio.position_of(handle);

    }

    public function setPosition(handle:AudioHandle, position:Float):Void {
                    
        if (!Luxe.audio.active) return;
        if ((handle:Int) == -1) return;
        
        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        Luxe.audio.position(handle, position);

    }

    inline function toBackendVolume(volume:Float):Float {
#if !ceramic_audio_volume_linear
        return volume < 1.0 ? volume * volume : volume * 1.0;
#else
        return volume * 1.0;
#end

    }

    inline function fromBackendVolume(volume:Float):Float {

#if !ceramic_audio_volume_linear
        return volume < 1.0 ? Math.sqrt(volume) : volume * 1.0;
#else
        return volume * 1.0;
#end

    }

} //Audio