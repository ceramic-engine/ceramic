package backend;

import backend.AudioFilterBuffer;
import ceramic.Path;
import ceramic.Shortcuts.*;
import clay.Clay;
import clay.Immediate;

using StringTools;

class Audio implements spec.Audio {

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

        var isUrl:Bool = path.startsWith('http://') || path.startsWith('https://');
        path = Path.isAbsolute(path) || isUrl ?
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
        if (!isUrl) {
            var questionMarkIndex = cleanedPath.indexOf('?');
            if (questionMarkIndex != -1) {
                cleanedPath = cleanedPath.substr(0, questionMarkIndex);
            }
        }

        // Create callbacks list with first entry
        loadingAudioCallbacks.set(path, [function(resource:AudioResource) {
            if (resource != null) {
                var retain = loadedAudioRetainCount.exists(path) ? loadedAudioRetainCount.get(path) : 0;
                loadedAudioRetainCount.set(path, retain + 1);
            }
            done(resource);
        }]);

        var fullPath = isUrl ? cleanedPath : Clay.app.assets.fullPath(cleanedPath);

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

    public function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false, channel:Int = 0):AudioHandle {

        if (!Clay.app.audio.active) return -1;

        var audioResource:clay.audio.AudioSource = audio;
        var isStream = audioResource.data.isStream;

        // These options are ignored on streamed sounds
        if (isStream) {
            position = 0;
            pitch = 1;
            pan = 0;
        }

        #if web
        // TODO audio filters
        var handle:AudioHandle = null;
        if (loop) {
            handle = Clay.app.audio.loop(audioResource, volume, false);
        }
        else {
            handle = Clay.app.audio.play(audioResource, volume, false);
        }
        #else
        var handle:AudioHandle = null;
        if (loop) {
            handle = Clay.app.audio.loop(audioResource, volume, false, channel);
        }
        else {
            handle = Clay.app.audio.play(audioResource, volume, false, channel);
        }
        #end

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

        Clay.app.audio.pause(handle);

    }

    public function resume(handle:AudioHandle):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        Clay.app.audio.unPause(handle);

    }

    public function stop(handle:AudioHandle):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        if (handle == null || (handle:Int) == -1) return;
        Clay.app.audio.stop(handle);

    }

    public function getVolume(handle:AudioHandle):Float {

        if (!Clay.app.audio.active) return 0;
        if (handle == null || (handle:Int) == -1) return 0;

        return Clay.app.audio.volumeOf(handle);

    }

    public function setVolume(handle:AudioHandle, volume:Float):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        Clay.app.audio.volume(handle, volume);

    }

    public function getPan(handle:AudioHandle):Float {

        if (!Clay.app.audio.active) return 0;
        if (handle == null || (handle:Int) == -1) return 0;

        return Clay.app.audio.panOf(handle);

    }

    public function setPan(handle:AudioHandle, pan:Float):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        // Forbid changing pan of streaming sounds
        var instance = Clay.app.audio.instanceOf(handle);
        if (instance != null && instance.source.data.isStream) return;

        Clay.app.audio.pan(handle, pan);

    }

    public function getPitch(handle:AudioHandle):Float {

        if (!Clay.app.audio.active) return 1;
        if (handle == null || (handle:Int) == -1) return 1;

        return Clay.app.audio.pitchOf(handle);

    }

    public function setPitch(handle:AudioHandle, pitch:Float):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        // Forbid changing pitch of streaming sounds
        var instance = Clay.app.audio.instanceOf(handle);
        if (instance != null && instance.source.data.isStream) return;

        Clay.app.audio.pitch(handle, pitch);

    }

    public function getPosition(handle:AudioHandle):Float {

        if (!Clay.app.audio.active) return 0;
        if (handle == null || (handle:Int) == -1) return 0;

        return Clay.app.audio.positionOf(handle);

    }

    public function setPosition(handle:AudioHandle, position:Float):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        // Forbid changing position of streaming sounds
        var instance = Clay.app.audio.instanceOf(handle);
        if (instance != null && instance.source.data.isStream) return;

        Clay.app.audio.position(handle, position);

    }

    public function addFilter(channel:Int, filter:ceramic.AudioFilter):Void {
        #if sys
        audioFiltersLock.acquire();
        #end

        var createClayChannelFilter = false;

        var filters = filterIdsByChannel[channel];
        if (filters == null) {
            filters = [];
            filterIdsByChannel[channel] = filters;
            filterLocksByChannel[channel] = new ceramic.SpinLock();
            createClayChannelFilter = true;
        }
        filters.push({
            id: filter.id,
            filter: filter,
            workletClass: filter.workletClass()
        });

        #if sys
        audioFiltersLock.release();
        #end

        if (createClayChannelFilter) {
            #if cpp
            Clay.app.audio.createChannelFilter(
                channel,
                cpp.Callable.fromStaticFunction(_clayFilterCreate),
                cpp.Callable.fromStaticFunction(_clayFilterDestroy),
                cpp.Callable.fromStaticFunction(_clayFilterProcess)
            );
            #else
            // TODO
            #end
        }

    }

    public function removeFilter(channel:Int, filterId:Int):Void {
        #if sys
        audioFiltersLock.acquire();
        #end

        var resolvedInfo = null;
        var filters = filterIdsByChannel[channel];
        if (filters != null) {
            var index = -1;
            for (i in 0...filters.length) {
                final filterInfo = filters[i];
                if (filterInfo.id == filterId) {
                    index = i;
                    resolvedInfo = filterInfo;
                    break;
                }
            }
            if (index != -1) {
                filters.splice(index, 1);
            }
        }

        #if sys
        audioFiltersLock.release();
        #end

        if (resolvedInfo != null) {
            if (resolvedInfo.worklet != null) {
                ceramic.AudioFilters.destroyWorklet(
                    channel,
                    resolvedInfo.id
                );
            }
            resolvedInfo = null;
        }
    }

    public function filterParamsChanged(channel:Int, filterId:Int):Void {
        #if sys
        audioFiltersLock.acquire();
        #end

        // TODO web

        var filters = filterIdsByChannel[channel];
        if (filters != null) {
            #if sys
            final byChannelLock = filterLocksByChannel[channel];
            byChannelLock.acquire();
            audioFiltersLock.release();
            #end

            for (i in 0...filters.length) {
                final filterInfo = filters[i];
                if (filterInfo.id == filterId) {
                    filterInfo.paramsDirty = true;
                    break;
                }
            }

            #if sys
            byChannelLock.release();
            #end
        }
        #if sys
        else {
            audioFiltersLock.release();
        }
        #end

    }

    #if cpp

    static function _clayFilterCreate(channel:Int, instanceId:Int):Void {
        // TODO
    }

    static function _clayFilterDestroy(channel:Int, instanceId:Int):Void {
        // TODO
    }

    static function _clayFilterProcess(channel:Int, instanceId:Int, aBuffer:cpp.RawPointer<cpp.Float32>, aSamples:cpp.UInt32, aChannels:cpp.UInt32, aSamplerate:cpp.Float32, time:cpp.Float64):Void {

        #if sys
        audioFiltersLock.acquire();
        #end

        var filters = filterIdsByChannel[channel];
        if (filters != null) {
            #if sys
            final byChannelLock = filterLocksByChannel[channel];
            byChannelLock.acquire();
            audioFiltersLock.release();
            #end

            for (i in 0...filters.length) {
                final filterInfo = filters[i];

                // Create filter worklet if needed
                if (filterInfo.worklet == null) {
                    filterInfo.worklet = ceramic.AudioFilters.createWorklet(
                        channel,
                        filterInfo.id,
                        filterInfo.workletClass
                    );
                }

                // Update worklet params from filter if needed
                if (filterInfo.paramsDirty) {
                    ceramic.AudioFilters.beginUpdateFilterWorkletParams(
                        channel,
                        filterInfo.id
                    );

                    filterInfo.filter.acquireParams();
                    final filterParams = @:privateAccess filterInfo.filter.params;
                    final workletParams = @:privateAccess filterInfo.worklet.params;
                    for (p in 0...filterParams.length) {
                        workletParams[p] = filterParams[p];
                    }
                    filterInfo.filter.releaseParams();

                    ceramic.AudioFilters.endUpdateFilterWorkletParams(
                        channel,
                        filterInfo.id
                    );
                }
            }

            #if sys
            byChannelLock.release();
            #end
        }
        #if sys
        else {
            audioFiltersLock.release();
        }
        #end

        // Make sure worklets are in sync
        ceramic.AudioFilters.syncWorklets();

        // Do the actual processing
        final buffer = new AudioFilterBuffer(cpp.Pointer.fromRaw(aBuffer));
        ceramic.AudioFilters.processChannelAudioWorklets(
            channel, buffer, aSamples, aChannels, aSamplerate, time
        );

    }

    #end

/// Internal

    #if sys
    static final audioFiltersLock = new ceramic.SpinLock();
    #end

    static final filterIdsByChannel:Array<Array<AudioFilterInfo>> = [];

    static final filterLocksByChannel:Array<ceramic.SpinLock> = [];

    var loadingAudioCallbacks:Map<String,Array<AudioResource->Void>> = new Map();

    var loadedAudioResources:Map<String,AudioResource> = new Map();

    var loadedAudioRetainCount:Map<String,Int> = new Map();

}
