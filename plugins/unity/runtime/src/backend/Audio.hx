package backend;

import ceramic.Path;
import ceramic.WaitCallbacks;
import unityengine.AudioClip;

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

    inline public function getDuration(audio:AudioResource):Float {

        return (audio:AudioResourceImpl).unityResource.length;

    }

    inline public function resumeAudioContext(done:Bool->Void):Void {

        done(true);

    }

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

    public function mute(audio:AudioResource):AudioHandle {

        return null;

    }

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

    public function pause(handle:AudioHandle):Void {

        (handle:AudioHandleImpl).pause();

    }

    public function resume(handle:AudioHandle):Void {

        (handle:AudioHandleImpl).resume();

    }

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

    inline public function supportsHotReloadPath():Bool {

        return false;

    }

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

    static function _notifyCallbacksInMainThread(toNotify:Array<()->Void>):Void {
        ceramic.Runner.runInMain(() -> {
            for (i in 0...toNotify.length) {
                final cb = toNotify[i];
                cb();
            }
        });
    }

    static function _unityFilterDestroy(bus:Int, instanceId:Int):Void {
        audioFiltersLock.acquire();
        activeBusFilters[bus] = false;
        audioFiltersLock.release();
    }

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

    static final audioFiltersLock = new ceramic.SpinLock();
    static final filterLocksByBus:Array<ceramic.SpinLock> = [];

    static final filterIdsByBus:Array<Array<AudioFilterInfo>> = [];

    static final activeBusFilters:Array<Bool> = [];

    // Only used in main thread so no lock needed for this one
    static final busHasFilter:Array<Bool> = [];

    static final busFilterReadyCallbacks:Array<Array<()->Void>> = [];

    static final postWorkletSyncCallbacks:Array<()->Void> = [];

    var soundExtensions:Array<String> = null;

    var loadingAudioCallbacks:Map<String,Array<AudioResource->Void>> = new Map();

    var loadedAudioResources:Map<String,AudioResourceImpl> = new Map();

    var loadedAudioRetainCount:Map<String,Int> = new Map();

} //Audio