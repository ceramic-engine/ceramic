package backend;

import ceramic.Path;
import ceramic.WaitCallbacks;
import unityengine.AudioClip;

using StringTools;

#if !no_backend_docs
/**
 * Unity backend implementation for audio playback and management.
 * 
 * This class provides the bridge between Ceramic's audio system and Unity's
 * AudioSource/AudioClip system. It handles:
 * - Loading audio resources from Unity's Resources folder
 * - Playing, pausing, and controlling audio playback
 * - Managing audio buses with effects processing
 * - Audio filter worklet integration for DSP effects
 * - Resource lifecycle management with reference counting
 * 
 * The implementation uses Unity's built-in audio system while providing
 * Ceramic's unified audio API, including support for:
 * - Multiple audio buses with independent effects chains
 * - Real-time audio filtering via worklets
 * - 3D spatial audio via pan controls
 * - Pitch shifting and time stretching
 * 
 * @see AudioResourceImpl The Unity-specific audio resource wrapper
 * @see AudioHandleImpl The Unity-specific playback handle
 * @see AudioSources Unity audio source pool manager
 */
#end
class Audio implements spec.Audio {

/// Lifecycle

    #if !no_backend_docs
    /**
     * Create a new Unity audio backend instance.
     * Initializes the audio system but doesn't create any Unity objects yet.
     */
    #end
    public function new() {}

/// Public API

    #if !no_backend_docs
    /**
     * Load an audio file from Unity's Resources folder or file system.
     * 
     * The loading process:
     * 1. Normalizes the path (absolute or relative to assets)
     * 2. Checks if already loaded (returns cached with increased retain count)
     * 3. Checks if currently loading (adds callback to queue)
     * 4. Loads via Unity's Resources.Load<AudioClip> API
     * 5. Caches the result and notifies all waiting callbacks
     * 
     * File extensions are automatically stripped for Unity Resources API.
     * HTTP/HTTPS URLs are not currently supported.
     * 
     * @param path Path to the audio file (relative to Resources or absolute)
     * @param options Loading options (currently unused)
     * @param _done Callback with loaded AudioResource or null on failure
     */
    #end
    public function load(path:String, ?options:LoadAudioOptions, _done:AudioResource->Void):Void {

        var done = function(resource:AudioResource) {
            ceramic.App.app.onceImmediate(function() {
                _done(resource);
                _done = null;
            });
        };

        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        if (path.startsWith('http://') || path.startsWith('https://')) {
            // Not implemented (yet?)
            done(null);
            return;
        }

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

        // Create callbacks list with first entry
        loadingAudioCallbacks.set(path, [function(resource:AudioResource) {
            if (resource != null) {
                var retain = loadedAudioRetainCount.exists(path) ? loadedAudioRetainCount.get(path) : 0;
                loadedAudioRetainCount.set(path, retain + 1);
            }
            done(resource);
        }]);

        // Load
        function doLoad() {

            // Load audio from Unity API
            var extension = Path.extension(path);
            if (soundExtensions == null)
                soundExtensions = ceramic.App.app.backend.info.soundExtensions();
            var unityPath = path;
            if (extension != null && soundExtensions.indexOf(extension.toLowerCase()) != -1) {
                unityPath = unityPath.substr(0, unityPath.length - extension.length - 1);
            }
            var unityResource:AudioClip = untyped __cs__('UnityEngine.Resources.Load<UnityEngine.AudioClip>({0})', unityPath);

            if (unityResource != null) {

                function doCreate() {
                    var resource = new AudioResourceImpl(path, unityResource);

                    loadedAudioResources.set(path, resource);
                    var callbacks = loadingAudioCallbacks.get(path);
                    loadingAudioCallbacks.remove(path);
                    for (callback in callbacks) {
                        callback(resource);
                    }
                }

                doCreate();
            }
            else {

                function doFail() {
                    var callbacks = loadingAudioCallbacks.get(path);
                    loadingAudioCallbacks.remove(path);
                    for (callback in callbacks) {
                        callback(null);
                    }
                }

                doFail();
            }
        }

        doLoad();

    }

    var nextSamplesBufferIndex:Int = 0;

    #if !no_backend_docs
    /**
     * Create an audio resource from raw PCM sample data.
     * 
     * This method creates a Unity AudioClip from the provided samples and
     * wraps it in an AudioResource. Supports both interleaved and planar
     * audio formats. The resource is automatically cached with a unique ID.
     * 
     * @param buffer Raw PCM samples as 32-bit floats
     * @param samples Number of samples per channel
     * @param channels Number of audio channels (1=mono, 2=stereo)
     * @param sampleRate Sample rate in Hz (e.g., 44100, 48000)
     * @param interleaved true if samples are interleaved, false if planar
     * @return Created AudioResource or null on failure
     */
    #end
    public function createFromSamplesBuffer(buffer:Float32Array, samples:Int, channels:Int, sampleRate:Float, interleaved:Bool):AudioResource {

        var id = 'samples:' + (nextSamplesBufferIndex++);

        var unityResource = AudioClip.Create(
            id, samples, channels, Std.int(sampleRate), false
        );

        if (unityResource != null) {

            if (interleaved) {
                unityResource.SetData(buffer, 0);
            }
            else {
                // Convert planar to interleaved
                var interleavedBuffer = new Float32Array(samples * channels);
                for (i in 0...samples) {
                    for (j in 0...channels) {
                        var planarIndex = j * samples + i;
                        var interleavedIndex = i * channels + j;
                        interleavedBuffer[interleavedIndex] = buffer[planarIndex];
                    }
                }
                unityResource.SetData(interleavedBuffer, 0);
            }

            var resource = new AudioResourceImpl(id, unityResource);
            loadedAudioResources.set(id, resource);
            loadedAudioRetainCount.set(id, 1);
            return resource;
        }

        return null;
    }

    #if !no_backend_docs
    /**
     * Get the duration of an audio resource in seconds.
     * @param audio The audio resource
     * @return Duration in seconds
     */
    #end
    inline public function getDuration(audio:AudioResource):Float {

        return (audio:AudioResourceImpl).unityResource.length;

    }

    #if !no_backend_docs
    /**
     * Resume the audio context (required for web, no-op for Unity).
     * Unity doesn't have the same audio context restrictions as web browsers,
     * so this always succeeds immediately.
     * @param done Callback with success status (always true)
     */
    #end
    inline public function resumeAudioContext(done:Bool->Void):Void {

        done(true);

    }

    #if !no_backend_docs
    /**
     * Destroy an audio resource and release its memory.
     * Uses reference counting - only unloads from Unity when retain count reaches 0.
     * @param audio The audio resource to destroy
     */
    #end
    inline public function destroy(audio:AudioResource):Void {

        var id = (audio:AudioResourceImpl).path;
        if (loadedAudioRetainCount.get(id) > 1) {
            loadedAudioRetainCount.set(id, loadedAudioRetainCount.get(id) - 1);
        }
        else {
            loadedAudioResources.remove(id);
            loadedAudioRetainCount.remove(id);
            untyped __cs__('UnityEngine.Resources.UnloadAsset({0})', (audio:AudioResourceImpl).unityResource);
        }

    }

    #if !no_backend_docs
    /**
     * Create a muted audio handle (not implemented in Unity backend).
     * @param audio The audio resource
     * @return Always returns null
     */
    #end
    public function mute(audio:AudioResource):AudioHandle {

        return null;

    }

    #if !no_backend_docs
    /**
     * Play an audio resource with specified parameters.
     * Creates a new AudioHandle that controls the playback instance.
     * 
     * @param audio The audio resource to play
     * @param volume Volume level (0.0 to 1.0)
     * @param pan Stereo pan (-1.0 = left, 0.0 = center, 1.0 = right)
     * @param pitch Pitch multiplier (1.0 = normal)
     * @param position Start position in seconds
     * @param loop Whether to loop the playback
     * @param bus Audio bus index for routing and effects
     * @return Handle for controlling the playback
     */
    #end
    public function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false, bus:Int = 0):AudioHandle {

        var handle = new AudioHandleImpl(audio, bus, busHasFilter[bus] == true);

        handle.volume = volume;
        handle.pan = pan;
        handle.pitch = pitch;
        handle.position = position;
        handle.loop = loop;

        handle.play();

        return handle;

    }

    #if !no_backend_docs
    /**
     * Pause audio playback.
     * @param handle The audio handle to pause
     */
    #end
    public function pause(handle:AudioHandle):Void {

        (handle:AudioHandleImpl).pause();

    }

    #if !no_backend_docs
    /**
     * Resume paused audio playback.
     * @param handle The audio handle to resume
     */
    #end
    public function resume(handle:AudioHandle):Void {

        (handle:AudioHandleImpl).resume();

    }

    #if !no_backend_docs
    /**
     * Stop audio playback completely.
     * @param handle The audio handle to stop
     */
    #end
    public function stop(handle:AudioHandle):Void {

        (handle:AudioHandleImpl).stop();

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

    #if !no_backend_docs
    /**
     * Check if hot reload is supported for audio paths.
     * Unity backend doesn't support hot reload.
     * @return Always false
     */
    #end
    inline public function supportsHotReloadPath():Bool {

        return false;

    }

    #if !no_backend_docs
    /**
     * Add an audio filter to a specific bus.
     * 
     * This creates or updates the filter chain for the specified bus.
     * Filters are processed in the order they were added. The implementation:
     * 1. Marks the bus as having filters
     * 2. Creates Unity bus filter if needed
     * 3. Initializes the filter worklet for DSP processing
     * 4. Synchronizes filter parameters
     * 
     * Thread-safe with spin locks for audio thread coordination.
     * 
     * @param bus The audio bus index
     * @param filter The audio filter to add
     * @param onReady Callback when filter is ready for processing
     */
    #end
    public function addFilter(bus:Int, filter:ceramic.AudioFilter, onReady:(bus:Int)->Void):Void {

        busHasFilter[bus] = true;

        audioFiltersLock.acquire();

        final wait = new WaitCallbacks(() -> onReady(bus));
        final filterWorkletReady = wait.callback();
        final busFilterReady = wait.callback();

        var createUnityBusFilter = false;

        var filters = filterIdsByBus[bus];
        if (filters == null) {
            filters = [];
            filterIdsByBus[bus] = filters;
            filterLocksByBus[bus] = new ceramic.SpinLock();
            createUnityBusFilter = true;
        }
        final filterWorkletClass = filter.workletClass();
        filters.push({
            id: filter.filterId,
            filter: filter,
            workletClass: filterWorkletClass
        });

        audioFiltersLock.release();

        if (createUnityBusFilter) {
            AudioSources.shared.createBusFilter(
                bus
            );
        }

        audioFiltersLock.acquire();
        final byBusLock = filterLocksByBus[bus];
        byBusLock.acquire();
        audioFiltersLock.release();
        postWorkletSyncCallbacks.push(filterWorkletReady);
        byBusLock.release();

        audioFiltersLock.acquire();

        // Trigger ready if the bus filter is already created
        final hasBusFilter = activeBusFilters.length > bus ? (activeBusFilters[bus] ?? false) : false;
        if (hasBusFilter) {
            audioFiltersLock.release();
            busFilterReady();
        }
        else {
            if (busFilterReadyCallbacks[bus] == null) {
                busFilterReadyCallbacks[bus] = [];
            }
            busFilterReadyCallbacks[bus].push(busFilterReady);
            audioFiltersLock.release();
        }

    }

    #if !no_backend_docs
    /**
     * Remove an audio filter from a bus.
     * Cleans up the filter worklet and updates the filter chain.
     * 
     * @param bus The audio bus index
     * @param filterId The unique ID of the filter to remove
     */
    #end
    public function removeFilter(bus:Int, filterId:Int):Void {

        audioFiltersLock.acquire();

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

        audioFiltersLock.release();

        if (resolvedInfo != null) {
            if (resolvedInfo.worklet != null) {
                ceramic.AudioFilters.destroyWorklet(
                    bus,
                    resolvedInfo.id
                );
            }
            resolvedInfo = null;
        }

    }

    #if !no_backend_docs
    /**
     * Notify that filter parameters have changed and need syncing.
     * The actual parameter update happens in the next audio processing callback.
     * 
     * @param bus The audio bus index
     * @param filterId The filter whose parameters changed
     */
    #end
    public function filterParamsChanged(bus:Int, filterId:Int):Void {

        audioFiltersLock.acquire();

        var filters = filterIdsByBus[bus];
        if (filters != null) {
            final byBusLock = filterLocksByBus[bus];
            byBusLock.acquire();
            audioFiltersLock.release();

            for (i in 0...filters.length) {
                final filterInfo = filters[i];
                if (filterInfo.id == filterId) {
                    filterInfo.paramsDirty = true;
                    break;
                }
            }

            byBusLock.release();
        }
        else {
            audioFiltersLock.release();
        }

    }

    #if !no_backend_docs
    /**
     * Called from Unity audio thread when a bus filter is created.
     * Marks the bus as active and notifies any waiting callbacks.
     * 
     * @param bus The audio bus index
     * @param instanceId Unity instance ID (unused)
     */
    #end
    static function _unityFilterCreate(bus:Int, instanceId:Int):Void {
        // Already acquired
        //audioFiltersLock.acquire();

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

        //audioFiltersLock.release();
    }

    #if !no_backend_docs
    /**
     * Execute callbacks in the main thread.
     * Used to safely notify from audio thread context.
     * 
     * @param toNotify Array of callbacks to execute
     */
    #end
    static function _notifyCallbacksInMainThread(toNotify:Array<()->Void>):Void {
        ceramic.Runner.runInMain(() -> {
            for (i in 0...toNotify.length) {
                final cb = toNotify[i];
                cb();
            }
        });
    }

    #if !no_backend_docs
    /**
     * Called from Unity audio thread when a bus filter is destroyed.
     * Marks the bus as inactive.
     * 
     * @param bus The audio bus index
     * @param instanceId Unity instance ID (unused)
     */
    #end
    static function _unityFilterDestroy(bus:Int, instanceId:Int):Void {
        audioFiltersLock.acquire();
        activeBusFilters[bus] = false;
        audioFiltersLock.release();
    }

    #if !no_backend_docs
    /**
     * Audio processing callback from Unity's audio thread.
     * 
     * This is called for each audio buffer that needs processing. It:
     * 1. Ensures the bus filter is marked as created
     * 2. Creates worklets for any new filters
     * 3. Syncs filter parameters if they've changed
     * 4. Processes the audio through all active filter worklets
     * 
     * Thread-safe with careful lock management to avoid audio glitches.
     * 
     * @param bus The audio bus being processed
     * @param instanceId Unity instance ID
     * @param aBuffer Audio sample buffer to process
     * @param aSamples Number of samples in the buffer
     * @param aChannels Number of audio channels
     * @param aSamplerate Sample rate in Hz
     * @param time Current audio time
     */
    #end
    static function _unityFilterProcess(bus:Int, instanceId:Int, aBuffer:Float32Array, aSamples:Int, aChannels:Int, aSamplerate:Single, time:Float):Void {

        audioFiltersLock.acquire();

        if (activeBusFilters[bus] != true) {
            _unityFilterCreate(bus, instanceId);
        }

        var postSyncCbs:Array<()->Void> = null;

        var filters = filterIdsByBus[bus];
        if (filters != null) {

            final byBusLock = filterLocksByBus[bus];
            byBusLock.acquire();
            audioFiltersLock.release();

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

            byBusLock.release();
        }
        else {
            audioFiltersLock.release();
        }

        // Make sure worklets are in sync
        ceramic.AudioFilters.syncWorklets();

        // Notify worklet post-sync callbacks
        if (postSyncCbs != null) {
            _notifyCallbacksInMainThread(postSyncCbs);
        }

        // Do the actual processing
        ceramic.AudioFilters.processBusAudioWorklets(
            bus, aBuffer, aSamples, aChannels, aSamplerate, time
        );

    }

/// Internal

    // Thread synchronization for audio filter management

    static final audioFiltersLock = new ceramic.SpinLock();
    static final filterLocksByBus:Array<ceramic.SpinLock> = [];

    static final filterIdsByBus:Array<Array<AudioFilterInfo>> = [];

    static final activeBusFilters:Array<Bool> = [];

    // Only used in main thread so no lock needed for this one
    static final busHasFilter:Array<Bool> = [];

    static final busFilterReadyCallbacks:Array<Array<()->Void>> = [];

    static final postWorkletSyncCallbacks:Array<()->Void> = [];

    #if !no_backend_docs
    /** Cached list of supported sound file extensions */
    #end
    var soundExtensions:Array<String> = null;

    #if !no_backend_docs
    /** Callbacks waiting for audio resources currently being loaded */
    #end
    var loadingAudioCallbacks:Map<String,Array<AudioResource->Void>> = new Map();

    #if !no_backend_docs
    /** Cache of loaded audio resources by path */
    #end
    var loadedAudioResources:Map<String,AudioResourceImpl> = new Map();

    #if !no_backend_docs
    /** Reference count for loaded resources (for memory management) */
    #end
    var loadedAudioRetainCount:Map<String,Int> = new Map();

} //Audio