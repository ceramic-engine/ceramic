package backend;

import ceramic.Path;
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

        var handle = new AudioHandleImpl(audio);

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

        // TODO

    }

    public function removeFilter(channel:Int, filterId:Int):Void {

        // TODO

    }

    public function filterParamsChanged(channel:Int, filterId:Int):Void {

        // TODO

    }

/// Internal

    var soundExtensions:Array<String> = null;

    var loadingAudioCallbacks:Map<String,Array<AudioResource->Void>> = new Map();

    var loadedAudioResources:Map<String,AudioResourceImpl> = new Map();

    var loadedAudioRetainCount:Map<String,Int> = new Map();

} //Audio