package backend;

import backend.AudioFilterBuffer;
import ceramic.Path;
import ceramic.Shortcuts.*;
import ceramic.WaitCallbacks;
import clay.Clay;
import clay.Immediate;

using StringTools;

/**
 * Clay backend audio implementation providing comprehensive sound management.
 * 
 * This class handles:
 * - Audio resource loading and caching with reference counting
 * - Sound playback control (play, pause, stop, loop)
 * - Audio properties manipulation (volume, pan, pitch, position)
 * - Streaming audio support for large files
 * - Real-time audio filters and effects processing
 * - Multi-bus audio system for grouping and mixing
 * - Web Audio context management for browser compatibility
 * - Platform-specific optimizations (native vs web)
 * 
 * The audio system uses Clay's underlying audio engine which supports:
 * - On web: Web Audio API with AudioWorklet support
 * - On native: Custom audio mixing with SDL audio backend
 * 
 * Audio resources are cached and reference counted to avoid redundant loading
 * and ensure proper memory management.
 */
class Audio implements spec.Audio {

/// Lifecycle

    /**
     * Creates a new Audio backend instance.
     */
    public function new() {}

/// Public API

    /**
     * Loads an audio resource from a file path or URL.
     * 
     * The method handles:
     * - Local file loading (relative to assets path)
     * - URL loading (http/https)
     * - Cached resource reuse with reference counting
     * - Asynchronous and synchronous loading modes
     * - Streaming mode for large audio files
     * 
     * @param path The path to the audio file (relative to assets or absolute/URL)
     * @param options Optional loading configuration:
     *                - loadMethod: SYNC for synchronous loading, ASYNC (default) for asynchronous
     *                - stream: true to stream large files instead of loading entirely in memory
     *                - immediate: Custom immediate callback queue for synchronization
     * @param _done Callback invoked with the loaded resource or null on failure
     */
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

    var nextSamplesBufferIndex:Int = 0;

    /**
     * Creates an audio resource from raw PCM sample data.
     * 
     * This is useful for:
     * - Procedurally generated audio
     * - Audio synthesis
     * - Converting from other audio formats
     * 
     * @param buffer The raw PCM samples as 32-bit floats
     * @param samples Number of sample frames (total samples / channels)
     * @param channels Number of audio channels (1 for mono, 2 for stereo)
     * @param sampleRate Sample rate in Hz (e.g., 44100, 48000)
     * @param interleaved Whether samples are interleaved (LRLRLR) or planar (LLL...RRR...)
     * @return The created audio resource, or null on failure
     */
    public function createFromSamplesBuffer(buffer:Float32Array, samples:Int, channels:Int, sampleRate:Float, interleaved:Bool):AudioResource {

        var id = 'samples:' + (nextSamplesBufferIndex++);

        var audioData = Clay.app.audio.dataFromPCM(
            id, buffer, samples, channels, sampleRate, interleaved
        );

        if (audioData != null) {
            var resource = new clay.audio.AudioSource(Clay.app, audioData);
            loadedAudioResources.set(id, resource);
            loadedAudioRetainCount.set(id, 1);
            return resource;
        }

        return null;

    }

    /**
     * Gets the duration of an audio resource in seconds.
     * 
     * @param resource The audio resource to query
     * @return Duration in seconds, or 0 if unknown
     */
    inline public function getDuration(resource:AudioResource):Float {

        return (resource:clay.audio.AudioSource).getDuration();

    }

    #if web
    /**
     * Resumes the Web Audio context after user interaction.
     * 
     * Modern browsers require user interaction before playing audio.
     * This method resumes a suspended audio context, typically called
     * after the first user click or touch.
     * 
     * @param done Callback with success status
     */
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
    /**
     * No-op on native platforms where audio context is always active.
     * @param done Always called with true
     */
    public function resumeAudioContext(done:Bool->Void):Void {
        done(true);
    }
    #end

    /**
     * Indicates whether this backend supports hot-reloading audio files.
     * @return true (Clay backend supports audio hot-reload)
     */
    inline public function supportsHotReloadPath():Bool {

        return true;

    }

    /**
     * Destroys an audio resource and frees associated memory.
     * 
     * Uses reference counting - the resource is only truly destroyed
     * when all references are released.
     * 
     * @param audio The audio resource to destroy
     */
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

    /**
     * Creates a muted audio handle (not implemented in Clay backend).
     * @param audio The audio resource
     * @return -1 (invalid handle)
     */
    inline public function mute(audio:AudioResource):AudioHandle {

        return -1;

    }

    /**
     * Plays an audio resource with specified parameters.
     * 
     * @param audio The audio resource to play
     * @param volume Playback volume (0.0 to 1.0, default 0.5)
     * @param pan Stereo panning (-1.0 left to 1.0 right, 0 center)
     * @param pitch Playback speed/pitch multiplier (1.0 = normal)
     * @param position Start position in seconds
     * @param loop Whether to loop the audio
     * @param bus Audio bus index for routing (0 = master)
     * @return Handle for controlling this audio instance, or -1 if failed
     */
    public function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false, bus:Int = 0):AudioHandle {

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
            handle = Clay.app.audio.loop(audioResource, volume, false, bus);
        }
        else {
            handle = Clay.app.audio.play(audioResource, volume, false, bus);
        }

        if (pan != 0) {
            Clay.app.audio.pan(handle, pan);
        }
        if (pitch != 1) Clay.app.audio.pitch(handle, pitch);
        if (position != 0) Clay.app.audio.position(handle, position);

        return handle;

    }

    /**
     * Pauses audio playback.
     * @param handle The audio instance handle
     */
    public function pause(handle:AudioHandle):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        Clay.app.audio.pause(handle);

    }

    /**
     * Resumes paused audio playback.
     * @param handle The audio instance handle
     */
    public function resume(handle:AudioHandle):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        Clay.app.audio.unPause(handle);

    }

    /**
     * Stops audio playback and releases the handle.
     * @param handle The audio instance handle
     */
    public function stop(handle:AudioHandle):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        if (handle == null || (handle:Int) == -1) return;
        Clay.app.audio.stop(handle);

    }

    /**
     * Gets the current volume of an audio instance.
     * @param handle The audio instance handle
     * @return Volume level (0.0 to 1.0)
     */
    public function getVolume(handle:AudioHandle):Float {

        if (!Clay.app.audio.active) return 0;
        if (handle == null || (handle:Int) == -1) return 0;

        return Clay.app.audio.volumeOf(handle);

    }

    /**
     * Sets the volume of an audio instance.
     * @param handle The audio instance handle
     * @param volume New volume level (0.0 to 1.0)
     */
    public function setVolume(handle:AudioHandle, volume:Float):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        Clay.app.audio.volume(handle, volume);

    }

    /**
     * Gets the current stereo pan position.
     * @param handle The audio instance handle
     * @return Pan value (-1.0 left to 1.0 right, 0 center)
     */
    public function getPan(handle:AudioHandle):Float {

        if (!Clay.app.audio.active) return 0;
        if (handle == null || (handle:Int) == -1) return 0;

        return Clay.app.audio.panOf(handle);

    }

    /**
     * Sets the stereo pan position.
     * Note: Pan cannot be changed for streaming sounds.
     * @param handle The audio instance handle
     * @param pan New pan value (-1.0 left to 1.0 right, 0 center)
     */
    public function setPan(handle:AudioHandle, pan:Float):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        // Forbid changing pan of streaming sounds
        var instance = Clay.app.audio.instanceOf(handle);
        if (instance != null && instance.source.data.isStream) return;

        Clay.app.audio.pan(handle, pan);

    }

    /**
     * Gets the current pitch/speed multiplier.
     * @param handle The audio instance handle
     * @return Pitch multiplier (1.0 = normal speed)
     */
    public function getPitch(handle:AudioHandle):Float {

        if (!Clay.app.audio.active) return 1;
        if (handle == null || (handle:Int) == -1) return 1;

        return Clay.app.audio.pitchOf(handle);

    }

    /**
     * Sets the pitch/speed multiplier.
     * Note: Pitch cannot be changed for streaming sounds.
     * @param handle The audio instance handle
     * @param pitch New pitch multiplier (1.0 = normal, 2.0 = double speed)
     */
    public function setPitch(handle:AudioHandle, pitch:Float):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        // Forbid changing pitch of streaming sounds
        var instance = Clay.app.audio.instanceOf(handle);
        if (instance != null && instance.source.data.isStream) return;

        Clay.app.audio.pitch(handle, pitch);

    }

    /**
     * Gets the current playback position in seconds.
     * @param handle The audio instance handle
     * @return Position in seconds from the start
     */
    public function getPosition(handle:AudioHandle):Float {

        if (!Clay.app.audio.active) return 0;
        if (handle == null || (handle:Int) == -1) return 0;

        return Clay.app.audio.positionOf(handle);

    }

    /**
     * Sets the playback position (seeks to a time).
     * Note: Position cannot be changed for streaming sounds.
     * @param handle The audio instance handle
     * @param position New position in seconds
     */
    public function setPosition(handle:AudioHandle, position:Float):Void {

        if (!Clay.app.audio.active) return;
        if (handle == null || (handle:Int) == -1) return;

        // Forbid changing position of streaming sounds
        var instance = Clay.app.audio.instanceOf(handle);
        if (instance != null && instance.source.data.isStream) return;

        Clay.app.audio.position(handle, position);

    }

    /**
     * Adds an audio filter to a specific bus for real-time processing.
     * 
     * Filters are processed in the order they are added. The system supports:
     * - Multiple filters per bus
     * - Real-time parameter updates
     * - AudioWorklet processing on web
     * - Native filter processing on desktop/mobile
     * 
     * @param bus The audio bus to add the filter to (0 = master)
     * @param filter The audio filter instance to add
     * @param onReady Callback when the filter is ready for processing
     */
    public function addFilter(bus:Int, filter:ceramic.AudioFilter, onReady:(bus:Int)->Void):Void {
        #if sys
        audioFiltersLock.acquire();
        #end

        final wait = new WaitCallbacks(() -> onReady(bus));
        final filterWorkletReady = wait.callback();
        final busFilterReady = wait.callback();

        var createClayBusFilter = false;

        var filters = filterIdsByBus[bus];
        if (filters == null) {
            filters = [];
            filterIdsByBus[bus] = filters;
            #if sys
            filterLocksByBus[bus] = new ceramic.SpinLock();
            #end
            createClayBusFilter = true;
        }
        final filterWorkletClass = filter.workletClass();
        filters.push({
            id: filter.filterId,
            filter: filter,
            workletClass: filterWorkletClass
        });

        #if sys
        audioFiltersLock.release();
        #end

        #if web
        var addBusFilterWorklet:()->Void = function() {
            Clay.app.audio.addBusFilterWorklet(
                bus,
                filter.filterId,
                filterWorkletClass,
                () -> {
                    filterWorkletReady();
                }
            );
        };
        #end

        if (createClayBusFilter) {
            #if cpp
            Clay.app.audio.createBusFilter(
                bus,
                cpp.Callable.fromStaticFunction(_clayFilterCreate),
                cpp.Callable.fromStaticFunction(_clayFilterDestroy),
                cpp.Callable.fromStaticFunction(_clayFilterProcess)
            );
            #elseif web
            Clay.app.audio.createBusFilter(
                #if ceramic_web_minify
                "audio-worklets.min.js",
                #else
                "audio-worklets.js",
                #end
                bus,
                (bus, instanceId) -> {
                    _clayFilterCreate(bus, instanceId);
                    if (addBusFilterWorklet != null) {
                        final cb = addBusFilterWorklet;
                        addBusFilterWorklet = null;
                        cb();
                    }
                },
                _clayFilterDestroy
            );
            #end
        }

        #if sys
        audioFiltersLock.acquire();
        final byBusLock = filterLocksByBus[bus];
        byBusLock.acquire();
        audioFiltersLock.release();
        postWorkletSyncCallbacks.push(filterWorkletReady);
        byBusLock.release();
        #end

        #if sys
        audioFiltersLock.acquire();
        #end

        // Trigger ready if the bus filter is already created
        final hasBusFilter = activeBusFilters.length > bus ? (activeBusFilters[bus] ?? false) : false;
        if (hasBusFilter) {
            #if sys
            audioFiltersLock.release();
            #end

            busFilterReady();
        }
        else {
            if (busFilterReadyCallbacks[bus] == null) {
                busFilterReadyCallbacks[bus] = [];
            }
            busFilterReadyCallbacks[bus].push(busFilterReady);

            #if sys
            audioFiltersLock.release();
            #end
        }

    }

    /**
     * Removes an audio filter from a bus.
     * 
     * @param bus The audio bus containing the filter
     * @param filterId The unique ID of the filter to remove
     */
    public function removeFilter(bus:Int, filterId:Int):Void {
        #if sys
        audioFiltersLock.acquire();
        #end

        var resolvedInfo = null;
        var filters = filterIdsByBus[bus];
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

        #if web
        Clay.app.audio.destroyBusFilterWorklet(
            bus,
            filterId
        );
        #else
        if (resolvedInfo != null) {
            if (resolvedInfo.worklet != null) {
                ceramic.AudioFilters.destroyWorklet(
                    bus,
                    resolvedInfo.id
                );
            }
            resolvedInfo = null;
        }
        #end

    }

    /**
     * Notifies the audio system that filter parameters have changed.
     * 
     * This triggers an update of the filter's processing parameters.
     * On web, parameters are sent to the AudioWorklet.
     * On native, parameters are marked dirty for the next process cycle.
     * 
     * @param bus The audio bus containing the filter
     * @param filterId The unique ID of the filter that changed
     */
    public function filterParamsChanged(bus:Int, filterId:Int):Void {
        #if sys
        audioFiltersLock.acquire();
        #end

        var filters = filterIdsByBus[bus];
        if (filters != null) {
            #if sys
            final byBusLock = filterLocksByBus[bus];
            byBusLock.acquire();
            audioFiltersLock.release();
            #end

            var paramIndex:Int = 0;
            for (i in 0...filters.length) {
                final filterInfo = filters[i];
                final filter = filterInfo.filter;
                if (filterInfo.id == filterId) {
                    #if web
                    for (p in 0...filter.numParams()) {
                        Clay.app.audio.setWorkletParameterByIndexWhenReady(bus, paramIndex, @:privateAccess filter.params[p]);
                        paramIndex++;
                    }
                    #else
                    filterInfo.paramsDirty = true;
                    #end
                    break;
                }
                else {
                    paramIndex += filter.numParams();
                }
            }

            #if sys
            byBusLock.release();
            #end
        }
        #if sys
        else {
            audioFiltersLock.release();
        }
        #end

    }

    /**
     * Internal callback when Clay creates a bus filter instance.
     * Notifies waiting callbacks that the bus filter is ready.
     * @param bus The bus index
     * @param instanceId The filter instance ID
     */
    static function _clayFilterCreate(bus:Int, instanceId:Int):Void {
        #if sys
        audioFiltersLock.acquire();
        #end
        final hasBusFilter = activeBusFilters.length > bus ? (activeBusFilters[bus] ?? false) : false;
        activeBusFilters[bus] = true;
        if (!hasBusFilter) {
            if (busFilterReadyCallbacks.length > bus) {
                if (busFilterReadyCallbacks[bus].length > 0) {
                    final toNotify = [];
                    while (busFilterReadyCallbacks[bus].length > 0) {
                        toNotify.push(busFilterReadyCallbacks[bus].shift());
                    }
                    _notifyCallbacksInMainThread(toNotify);
                }
            }
        }
        #if sys
        audioFiltersLock.release();
        #end
    }

    /**
     * Executes callbacks on the main thread for thread safety.
     * @param toNotify Array of callbacks to execute
     */
    static function _notifyCallbacksInMainThread(toNotify:Array<()->Void>):Void {
        ceramic.Runner.runInMain(() -> {
            for (i in 0...toNotify.length) {
                final cb = toNotify[i];
                cb();
            }
        });
    }

    /**
     * Internal callback when Clay destroys a bus filter instance.
     * @param bus The bus index
     * @param instanceId The filter instance ID
     */
    static function _clayFilterDestroy(bus:Int, instanceId:Int):Void {
        #if sys
        audioFiltersLock.acquire();
        #end
        activeBusFilters[bus] = false;
        #if sys
        audioFiltersLock.release();
        #end
    }

    #if cpp

    /**
     * Internal audio processing callback for native platforms.
     * 
     * Called by Clay's audio thread to process audio through filters.
     * This method:
     * - Creates worklets for new filters
     * - Updates filter parameters from main thread
     * - Processes audio through all filters on the bus
     * 
     * @param bus The audio bus being processed
     * @param instanceId The filter instance ID
     * @param aBuffer Raw pointer to audio buffer
     * @param aSamples Number of sample frames to process
     * @param aChannels Number of audio channels
     * @param aSamplerate Sample rate in Hz
     * @param time Current audio time in seconds
     */
    static function _clayFilterProcess(bus:Int, instanceId:Int, aBuffer:cpp.RawPointer<cpp.Float32>, aSamples:cpp.UInt32, aChannels:cpp.UInt32, aSamplerate:cpp.Float32, time:cpp.Float64):Void {

        #if !documentation

        #if sys
        audioFiltersLock.acquire();
        #end

        var postSyncCbs:Array<()->Void> = null;

        var filters = filterIdsByBus[bus];
        if (filters != null) {
            #if sys
            final byBusLock = filterLocksByBus[bus];
            byBusLock.acquire();
            audioFiltersLock.release();
            #end

            for (i in 0...filters.length) {
                final filterInfo = filters[i];

                // Create filter worklet if needed
                if (filterInfo.worklet == null) {
                    filterInfo.worklet = ceramic.AudioFilters.createWorklet(
                        bus,
                        filterInfo.id,
                        filterInfo.workletClass
                    );
                }

                // Update worklet params from filter if needed
                if (filterInfo.paramsDirty) {
                    ceramic.AudioFilters.beginUpdateFilterWorkletParams(
                        bus,
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
                        bus,
                        filterInfo.id
                    );
                }
            }

            if (postWorkletSyncCallbacks.length > 0) {
                postSyncCbs = [];
                while (postWorkletSyncCallbacks.length > 0) {
                    postSyncCbs.push(postWorkletSyncCallbacks.shift());
                }
            }

            #if sys
            byBusLock.release();
            #end
        }
        #if sys
        else {
            audioFiltersLock.release();
        }
        #end

        // Make sure worklets are in sync
        ceramic.AudioFilters.syncWorklets();

        // Notify worklet post-sync callbacks
        if (postSyncCbs != null) {
            _notifyCallbacksInMainThread(postSyncCbs);
        }

        // Do the actual processing
        final buffer = new AudioFilterBuffer(cpp.Pointer.fromRaw(aBuffer));
        ceramic.AudioFilters.processBusAudioWorklets(
            bus, buffer, aSamples, aChannels, aSamplerate, time
        );

        #end

    }

    #end

/// Internal

    #if sys
    /** Global lock for thread-safe filter operations */
    static final audioFiltersLock = new ceramic.SpinLock();
    /** Per-bus locks for fine-grained thread safety */
    static final filterLocksByBus:Array<ceramic.SpinLock> = [];
    #end

    /** Active filters indexed by bus number */
    static final filterIdsByBus:Array<Array<AudioFilterInfo>> = [];

    /** Tracks which buses have active filters */
    static final activeBusFilters:Array<Bool> = [];

    /** Callbacks waiting for bus filter creation */
    static final busFilterReadyCallbacks:Array<Array<()->Void>> = [];

    /** Callbacks to execute after worklet synchronization */
    static final postWorkletSyncCallbacks:Array<()->Void> = [];

    /** Callbacks for audio resources currently loading */
    var loadingAudioCallbacks:Map<String,Array<AudioResource->Void>> = new Map();

    /** Cached audio resources indexed by path */
    var loadedAudioResources:Map<String,AudioResource> = new Map();

    /** Reference count for each loaded audio resource */
    var loadedAudioRetainCount:Map<String,Int> = new Map();

}
