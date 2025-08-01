package ceramic;

import ceramic.Path;
import ceramic.Shortcuts.*;

/**
 * Asset type for loading audio/sound files.
 * 
 * Supports various audio formats depending on the backend:
 * - Web: MP3, OGG, WAV, M4A
 * - Native: MP3, OGG, WAV, FLAC
 * 
 * Features:
 * - Streaming support for large audio files
 * - Hot reload during development
 * - Automatic format fallback (tries alternative formats if one fails)
 * 
 * @example
 * ```haxe
 * var assets = new Assets();
 * assets.addSound('music/background');
 * assets.addSound('sfx/jump', null, {stream: true});
 * assets.load();
 * 
 * // Play loaded sound
 * var sound = assets.sound('sfx/jump');
 * sound.play();
 * ```
 */
class SoundAsset extends Asset {

    /// Events

    /**
     * Emitted when the sound is replaced (e.g., during hot reload).
     * @param newSound The newly loaded sound
     * @param prevSound The previous sound being replaced
     */
    @event function replaceSound(newSound:Sound, prevSound:Sound);

    /**
     * Whether this sound should be streamed from disk rather than loaded into memory.
     * Useful for large audio files like background music.
     * Note: Streaming support depends on the backend.
     */
    public var stream:Bool = false;

    /**
     * The loaded Sound instance.
     * Observable property that updates when the sound is loaded or replaced.
     * Null until the asset is successfully loaded.
     */
    @observe public var sound:Sound = null;

    /**
     * Create a new sound asset.
     * @param name Sound file name (with or without extension)
     * @param variant Optional variant suffix
     * @param options Loading options including:
     *                - stream: Whether to stream the audio
     *                - volume: Initial volume (0.0 to 1.0)
     */
    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('sound', name, variant, options #if ceramic_debug_entity_allocs , pos #end);

    }

    /**
     * Load the sound file.
     * Tries multiple file formats if available, falling back to alternatives on failure.
     * Emits complete event when finished.
     */
    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load sound asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        var loadOptions:AssetOptions = {};
        if (owner != null) {
            loadOptions.immediate = owner.immediate;
            loadOptions.loadMethod = owner.loadMethod;
        }
        if (options != null) {
            for (key in Reflect.fields(options)) {
                Reflect.setField(loadOptions, key, Reflect.field(options, key));
            }
        }

        // Add reload count if any
        var remainingPaths = [].concat(allPaths);

        function handleBackendResponse(audio:backend.AudioResource) {

            if (audio != null) {

                var prevSound = this.sound;

                var newSound = new Sound(audio);
                newSound.asset = this;
                this.sound = newSound;

                if (prevSound != null) {
                    // When replacing the sound, emit an event to notify about it
                    emitReplaceSound(this.sound, prevSound);

                    // Destroy previous sound
                    prevSound.asset = null;
                    prevSound.destroy();
                }

                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                log.error('Failed to load audio at path: $path');
                emitComplete(false);
            }

        }

        function doLoad(path:String) {

            var backendPath = path;
            var realPath = Assets.realAssetPath(backendPath, runtimeAssets);
            var assetReloadedCount = Assets.getReloadCount(realPath);
            if (app.backend.texts.supportsHotReloadPath() && assetReloadedCount > 0) {
                realPath += '?hot=' + assetReloadedCount;
                backendPath += '?hot=' + assetReloadedCount;
            }

            log.info('Load sound $backendPath');

            var ext = ceramic.Path.extension(realPath);
            if (ext != null)
                ext = ext.toLowerCase();

            app.backend.audio.load(realPath, loadOptions, function(audio) {

                if (audio != null || remainingPaths.length == 0) {
                    handleBackendResponse(audio);
                }
                else {
                    var nextPath = remainingPaths.shift();
                    log.warning('Failed to load $path. Try $nextPath...');
                    doLoad(nextPath);
                }

            });

        }

        if (remainingPaths.length > 0)
            doLoad(remainingPaths.shift());
        else {
            status = BROKEN;
            log.error('Failed to load audio at path: $path');
            emitComplete(false);
        }

    }

    /**
     * Handle file system changes for hot reload.
     * Automatically reloads the sound when the source file is modified.
     */
    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.audio.supportsHotReloadPath())
            return;

        var previousTime:Float = -1;
        if (previousFiles.exists(path)) {
            previousTime = previousFiles.get(path);
        }
        var newTime:Float = -1;
        if (newFiles.exists(path)) {
            newTime = newFiles.get(path);
        }

        if (newTime != previousTime) {
            log.info('Reload sound (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        if (sound != null) {
            sound.destroy();
            sound = null;
        }

    }

}
