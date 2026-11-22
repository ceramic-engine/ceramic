package ceramic;

import ceramic.Shortcuts.*;
import haxe.DynamicAccess;
import haxe.Json;

/**
 * An asset that loads and manages fragment data from `.fragments` files.
 * 
 * Fragments in Ceramic are reusable groups of visuals and entities that can be
 * instantiated from data files. They support:
 * - Multiple visual elements and entities with properties
 * - Timeline-based animations with keyframes
 * - Components that can be attached to fragment items
 * - Hot-reloading for development
 * 
 * A fragments file is a JSON object that maps fragment ids to `FragmentData`:
 * ```json
 * {
 *   "mainMenu": { "width": 800, "height": 600, "items": [...] },
 *   "settings": { "width": 800, "height": 600, "items": [...] }
 * }
 * ```
 * 
 * A `Fragment` created with `Fragment.loadFromAsset()` (or `Scene.loadFragment()`)
 * follows the asset: it is updated when the file is reloaded.
 * 
 * Example usage:
 * ```haxe
 * // Load a fragments asset
 * var fragmentsAsset = new FragmentsAsset('myFragments');
 * fragmentsAsset.onComplete(this, success -> {
 *     if (success) {
 *         // Access fragment data
 *         var menuFragment = fragmentsAsset.fragments.get('mainMenu');
 *         
 *         // Create a Fragment instance from the data
 *         var fragment = new Fragment();
 *         fragment.fragmentData = menuFragment;
 *         screen.add(fragment);
 *     }
 * });
 * fragmentsAsset.load();
 * ```
 * 
 * @see Fragment The runtime representation of fragment data
 * @see FragmentData The data structure for fragments
 * @see FragmentItem Individual items within a fragment
 */
class FragmentsAsset extends Asset {

    /**
     * A map of fragment IDs to their corresponding FragmentData objects.
     * This property is populated after successfully loading the fragments file.
     * Each fragment can be accessed by its ID and used to create Fragment instances.
     * 
     * The property is observable, so you can react to changes when fragments are loaded:
     * ```haxe
     * fragmentsAsset.onFragmentsChange(this, (fragments, prevFragments) -> {
     *     if (fragments != null) {
     *         // Fragments loaded successfully
     *         for (id in fragments.keys()) {
     *             trace('Loaded fragment: ' + id);
     *         }
     *     }
     * });
     * ```
     */
    @observe public var fragments:DynamicAccess<FragmentData> = null;

    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('fragments', name, variant, options #if ceramic_debug_entity_allocs , pos #end);

    }

    /**
     * Loads the fragments file from the specified path.
     * 
     * The loading process:
     * 1. Loads the JSON file as text
     * 2. Parses the JSON data
     * 
     * Supports hot-reload on platforms that allow it - the file will be
     * automatically reloaded when it changes on disk.
     */
    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load fragments asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        // Add reload count if any
        var backendPath = path;
        var realPath = Assets.realAssetPath(backendPath, runtimeAssets);
        var assetReloadedCount = Assets.getReloadCount(realPath);
        if (app.backend.texts.supportsHotReloadPath() && assetReloadedCount > 0) {
            realPath += '?hot=' + assetReloadedCount;
            backendPath += '?hot=' + assetReloadedCount;
        }

        var loadOptions:AssetOptions = {};
        if (owner != null) {
            loadOptions.immediate = owner.immediate;
            loadOptions.loadMethod = owner.loadMethod;
        }

        log.info('Load fragments $backendPath');
        app.backend.texts.load(realPath, loadOptions, function(text) {

            if (text != null) {
                try {
                    var rawFragments:DynamicAccess<FragmentData> = Json.parse(text);
                    for (id in rawFragments.keys()) {
                        // The id of a fragment is its key in the file
                        var fragmentData = rawFragments.get(id);
                        if (fragmentData != null && fragmentData.id == null) {
                            fragmentData.id = id;
                        }
                    }
                    this.fragments = rawFragments;
                } catch (e:Dynamic) {
                    status = BROKEN;
                    log.error('Failed to parse fragments at path: $path');
                    emitComplete(false);
                    return;
                }
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                log.error('Failed to load fragments at path: $path');
                emitComplete(false);
            }

        });

    }

    /**
     * Called when asset files change on disk (hot-reload support).
     * Automatically reloads the fragments file if it has been modified.
     * @param newFiles Map of current files and their modification times
     * @param previousFiles Map of previous files and their modification times
     */
    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.texts.supportsHotReloadPath())
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
            log.info('Reload fragments (file has changed)');
            load();
        }

    }

    /**
     * Destroys the fragments asset and clears the loaded fragment data from memory.
     */
    override function destroy():Void {

        super.destroy();

        fragments = null;

    }

}
