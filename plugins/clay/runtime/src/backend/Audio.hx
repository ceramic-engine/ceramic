package backend;

import ceramic.Path;
import ceramic.Shortcuts.*;
import clay.Clay;
import clay.Immediate;

using StringTools;

class Audio implements spec.Audio {

/// Internal

    var loopingStreams:Map<AudioHandle,Bool> = new Map();
    var loopHandles:Map<AudioHandle,AudioHandle> = new Map();

/// Lifecycle

    public function new() {}

/// Public API

    public function load(path:String, ?options:LoadAudioOptions, _done:AudioResource->Void):Void {

        var synchronous = options != null && options.loadMethod == SYNC;
        var immediate = options != null ? options.immediate : null;
        var done = function(resource:AudioResource) {
            final fn = function() {
                _done(resource);
                _done = null;
            };
            if (immediate != null)
                immediate.push(fn);
            else
                ceramic.App.app.onceImmediate(fn);
        };

        var isStream:Bool = (options != null && options.stream == true);

        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        // Is resource already loaded?
        if (loadedAudioResources.exists(path)) {
            loadedAudioRetainCount.set(path, loadedAudioRetainCount.get(path) + 1);
            var existing = loadedAudioResources.get(path);
            done(existing);
            return;
        }

        // Is resource currently loading?
        if (loadingAudioCallbacks.exists(path)) {
            // Yes, just bind it
            loadingAudioCallbacks.get(path).push(function(resource:AudioResource) {
                if (resource != null) {
                    var retain = loadedAudioRetainCount.exists(path) ? loadedAudioRetainCount.get(path) : 0;
                    loadedAudioRetainCount.set(path, retain + 1);
                }
                done(resource);
            });
            return;
        }

        // Remove ?something in path
        var cleanedPath = path;
        var questionMarkIndex = cleanedPath.indexOf('?');
        if (questionMarkIndex != -1) {
            cleanedPath = cleanedPath.substr(0, questionMarkIndex);
        }

        // Create callbacks list with first entry
        loadingAudioCallbacks.set(path, [function(resource:AudioResource) {
            if (resource != null) {
                var retain = loadedAudioRetainCount.exists(path) ? loadedAudioRetainCount.get(path) : 0;
                loadedAudioRetainCount.set(path, retain + 1);
            }
            done(resource);
        }]);

        var fullPath = Clay.app.assets.fullPath(cleanedPath);

        function doFail() {

            var callbacks = loadingAudioCallbacks.get(path);
            loadingAudioCallbacks.remove(path);
            for (callback in callbacks) {
                try {
                    callback(null);
                }
                catch (e:Dynamic) {
                    ceramic.App.app.onceImmediate(() -> {
                        throw e;
                    });
                }
            }

        }

        // Load audio
        Clay.app.audio.loadData(fullPath, isStream, null, !synchronous, function(audioData) {

            if (audioData == null) {
                doFail();
                return;
            }

            // Create audio source
            var resource = new clay.audio.AudioSource(Clay.app, audioData);

            // Success
            loadedAudioResources.set(path, resource);
            var callbacks = loadingAudioCallbacks.get(path);
            loadingAudioCallbacks.remove(path);
            for (callback in callbacks) {
                callback(resource);
            }
        });

        // Needed to ensure a synchronous load will be done before the end of the frame
        if (immediate != null) {
            immediate.push(Immediate.flush);
        }
        else {
            ceramic.App.app.onceImmediate(Immediate.flush);
        }

    }

    inline public function getDuration(resource:AudioResource):Float {

        return (resource:clay.audio.AudioSource).getDuration();

    }

    #if web
    public function resumeAudioContext(done:Bool->Void):Void {

        var webAudio:clay.web.WebAudio = cast Clay.app.audio;
        if (webAudio != null) {
            try {
                var context:Dynamic = webAudio.context;
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

        var id:String = null;
        for (key => val in loadedAudioResources) {
            if (val == audio) {
                id = key;
            }
        }
        if (id == null) {
            log.error('Failed to destroy audio resource: $audio because id could not be resolved');
        }
        else {
            if (loadedAudioRetainCount.get(id) > 1) {
                loadedAudioRetainCount.set(id, loadedAudioRetainCount.get(id) - 1);
            }
            else {
                loadedAudioResources.remove(id);
                loadedAudioRetainCount.remove(id);
                (audio:clay.audio.AudioSource).destroy();
            }
        }

    }

    inline public function mute(audio:AudioResource):AudioHandle {

        return -1;

    }

    public function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false):AudioHandle {

        if (!Clay.app.audio.active) return -1;

        var audioResource:clay.audio.AudioSource = audio;
        var isStream = audioResource.data.isStream;

        // These options are ignored on streamed sounds
        if (isStream) {
            position = 0;
            pitch = 1;
            pan = 0;
        }

        var handle:AudioHandle = null;
        if (loop) {

            #if (cpp && ceramic_use_openal)
            if (isStream) {

                // At the moment, looping a stream doesn't seem reliable if just relying on openal implementation.
                // When looping a stream, let's manage ourselve the loop by
                // checking the position and playing again from start.

                var duration = audioResource.getDuration();
                handle = Clay.app.audio.play(audioResource, volume, false);
                var firstHandle = handle;
                loopingStreams.set(handle, true);
                var pos:Float = 0;

                var onUpdate = null;
                onUpdate = function(delta) {

                    if (!Clay.app.audio.active) return;

                    if (loopingStreams.exists(handle)) {

                        var playing = loopingStreams.get(handle);
                        if (playing) {

                            var instance = Clay.app.audio.instanceOf(handle);
                            if (instance != null) {
                                pos = Clay.app.audio.positionOf(handle);
                                if (pos < duration) volume = Clay.app.audio.volumeOf(handle);

                                if (pos >= duration - 1.0/60) {
                                    // End of loop, start from 0 again
                                    loopingStreams.remove(handle);
                                    Clay.app.audio.stop(handle);
                                    handle = Clay.app.audio.play(audioResource, volume, false);
                                    loopingStreams.set(handle, true);
                                    loopHandles.set(firstHandle, handle);
                                }
                            }
                            else {
                                // Sound instance was destroyed when looping (it can happen), restore it
                                // Not perfect: the stream is resumed from the beginning regardless
                                // of where it was stopped.
                                loopingStreams.remove(handle);
                                handle = Clay.app.audio.play(audioResource, volume, false);
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
                handle = Clay.app.audio.loop(audioResource, volume, false);
            #if (cpp && ceramic_use_openal)
            }
            #end

        } else {
            handle = Clay.app.audio.play(audioResource, volume, false);
        }

        if (pan != 0) {
            Clay.app.audio.pan(handle, pan);
        }
        if (pitch != 1) Clay.app.audio.pitch(handle, pitch);
        if (position != 0) Clay.app.audio.position(handle, position);

        return handle;

    }

    public function pause(handle:AudioHandle):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
            if (handle == null || (handle:Int) == -1) return;
        }

        if (loopingStreams.exists(handle)) {
            loopingStreams.set(handle, false);
        }

        Clay.app.audio.pause(handle);

    }

    public function resume(handle:AudioHandle):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
            if (handle == null || (handle:Int) == -1) return;
        }

        if (loopingStreams.exists(handle)) {
            loopingStreams.set(handle, true);
        }

        Clay.app.audio.unPause(handle);

    }

    public function stop(handle:AudioHandle):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        if (loopHandles.exists(handle)) {
            var prevHandle = handle;
            handle = loopHandles.get(handle);
            loopHandles.remove(prevHandle);
        }

        loopingStreams.remove(handle);

        if (handle == null || (handle:Int) == -1) return;
        Clay.app.audio.stop(handle);

    }

    public function getVolume(handle:AudioHandle):Float {

        if (!Clay.app.audio.active) return 0;
        if (handle == null || (handle:Int) == -1) return 0;

        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
            if (handle == null || (handle:Int) == -1) return 0;
        }

        return Clay.app.audio.volumeOf(handle);

    }

    public function setVolume(handle:AudioHandle, volume:Float):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        Clay.app.audio.volume(handle, volume);

    }

    public function getPan(handle:AudioHandle):Float {

        if (!Clay.app.audio.active) return 0;
        if (handle == null || (handle:Int) == -1) return 0;

        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        return Clay.app.audio.panOf(handle);

    }

    public function setPan(handle:AudioHandle, pan:Float):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
        }

        // Forbid changing pan of streaming sounds
        var instance = Clay.app.audio.instanceOf(handle);
        if (instance != null && instance.source.data.isStream) return;

        Clay.app.audio.pan(handle, pan);

    }

    public function getPitch(handle:AudioHandle):Float {

        if (!Clay.app.audio.active) return 1;
        if (handle == null || (handle:Int) == -1) return 1;

        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
            if (handle == null || (handle:Int) == -1) return 1;
        }

        return Clay.app.audio.pitchOf(handle);

    }

    public function setPitch(handle:AudioHandle, pitch:Float):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
            if (handle == null || (handle:Int) == -1) return;
        }

        // Forbid changing pitch of streaming sounds
        var instance = Clay.app.audio.instanceOf(handle);
        if (instance != null && instance.source.data.isStream) return;

        Clay.app.audio.pitch(handle, pitch);

    }

    public function getPosition(handle:AudioHandle):Float {

        if (!Clay.app.audio.active) return 0;
        if (handle == null || (handle:Int) == -1) return 0;

        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
            if (handle == null || (handle:Int) == -1) return 0;
        }

        return Clay.app.audio.positionOf(handle);

    }

    public function setPosition(handle:AudioHandle, position:Float):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        if (loopHandles.exists(handle)) {
            handle = loopHandles.get(handle);
            if (handle == null || (handle:Int) == -1) return;
        }

        // Forbid changing position of streaming sounds
        var instance = Clay.app.audio.instanceOf(handle);
        if (instance != null && instance.source.data.isStream) return;

        Clay.app.audio.position(handle, position);

    }

/// Internal

    var loadingAudioCallbacks:Map<String,Array<AudioResource->Void>> = new Map();

    var loadedAudioResources:Map<String,AudioResource> = new Map();

    var loadedAudioRetainCount:Map<String,Int> = new Map();

} //Audio