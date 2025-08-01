package ceramic;

import ceramic.Shortcuts.*;
import haxe.DynamicAccess;
import haxe.Json;

/**
 * An asset that loads and manages fragment data from `.fragment` files.
 * 
 * Fragments in Ceramic are reusable groups of visuals and entities that can be
 * instantiated from data files. They support:
 * - Multiple visual elements and entities with properties
 * - Timeline-based animations with keyframes
 * - Components that can be attached to fragment items
 * - Hot-reloading for development
 * 
 * Fragment files can be in two formats:
 * 1. Legacy format: Direct JSON representation of FragmentData objects
 * 2. Version 1 format: Structured format with schema support that gets converted at load time
 * 
 * Example usage:
 * ```haxe
 * // Load a fragments asset
 * var fragmentsAsset = new FragmentsAsset('myFragments.fragment');
 * fragmentsAsset.onComplete(this, success -> {
 *     if (success) {
 *         // Access fragment data
 *         var menuFragment = fragmentsAsset.fragments.get('mainMenu');
 *         
 *         // Create a Fragment instance from the data
 *         var fragment = new Fragment();
 *         fragment.fragmentData = menuFragment;
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
     * 3. Detects the format version (legacy or version 1)
     * 4. Converts version 1 format to runtime format if needed
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
                    var rawFragments = Json.parse(text);
                    if (Reflect.hasField(rawFragments, 'version')) {
                        this.fragments = fromRawFragments(rawFragments);
                    }
                    else {
                        this.fragments = rawFragments;
                    }
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
     * Converts raw fragment data from the version 1 format into the runtime FragmentData format.
     * 
     * The version 1 format separates visuals and entities into different arrays and includes
     * schema information for type checking. This method:
     * - Processes the visuals and entities arrays into a unified items array
     * - Attaches schema information to each item for runtime type validation
     * - Converts color strings to Color objects
     * - Ensures all required fields have default values
     * 
     * @param rawFragments The raw fragment data loaded from a version 1 format file
     * @return A map of fragment IDs to their processed FragmentData objects
     */
    /**
     * Converts version 1 fragment format to the runtime format.
     * 
     * This method handles the transformation of the newer fragment file format
     * that includes additional metadata and schema information. It processes:
     * - Fragment metadata (id, dimensions, color, transparency)
     * - Visual and entity items with their properties
     * - Component configurations
     * - Schema references for entity types
     * 
     * @param rawFragments The raw parsed JSON data with version field
     * @return Map of fragment IDs to FragmentData objects
     */
    static function fromRawFragments(rawFragments:Dynamic):DynamicAccess<FragmentData> {

        var fragments:DynamicAccess<FragmentData> = {};

        var version = Std.int(rawFragments.version);
        if (version == 1) {
            // This is a newer fragments file format that needs to be processed
            // in order to be compatible with runtime format.
            var rawFragmentsList:Array<Dynamic> = rawFragments.fragments;
            if (rawFragmentsList != null) {
                for (rawFragment in rawFragmentsList) {

                    var fragmentData:FragmentData = {
                        id: rawFragment.id,
                        data: rawFragment.data ?? {},
                        width: rawFragment.width,
                        height: rawFragment.height,
                        components: rawFragment.components ?? {}
                    };

                    if (Reflect.hasField(rawFragment, 'color')) {
                        fragmentData.color = Color.fromString(rawFragment.color);
                    }

                    if (Reflect.hasField(rawFragment, 'transparent')) {
                        fragmentData.transparent = (rawFragment.transparent == true);
                    }

                    var schema:Dynamic = rawFragments.schema;
                    var items:Array<FragmentItem> = [];

                    if (Reflect.hasField(rawFragment, 'visuals')) {
                        var rawVisuals:Array<Dynamic> = rawFragment.visuals;
                        for (rawVisual in rawVisuals) {

                            var visualData:FragmentItem = {
                                id: rawVisual.id,
                                data: rawVisual.data ?? {},
                                entity: rawVisual.entity,
                                components: rawVisual.components ?? {},
                                props: {}
                            }

                            for (key in Reflect.fields(rawVisual)) {
                                switch key {
                                    case 'entity':
                                        final entity:String = Reflect.field(rawVisual, key);
                                        if (schema != null && entity != null && Reflect.hasField(schema, entity)) {
                                            visualData.schema = Reflect.field(schema, entity);
                                        }
                                    case 'kind' | 'id' | 'locked' | 'components' | 'data':
                                    case _:
                                        Reflect.setField(
                                            visualData.props,
                                            key,
                                            Reflect.field(rawVisual, key)
                                        );
                                }
                            }

                            items.push(visualData);
                        }
                    }

                    if (Reflect.hasField(rawFragment, 'entities')) {
                        var rawEntities:Array<Dynamic> = rawFragment.entities;
                        for (rawEntity in rawEntities) {

                            var entityData:FragmentItem = {
                                id: rawEntity.id,
                                data: rawEntity.data ?? {},
                                entity: rawEntity.entity,
                                components: rawEntity.components ?? {},
                                props: {}
                            }

                            for (key in Reflect.fields(rawEntity)) {
                                switch key {
                                    case 'entity':
                                        final entity:String = Reflect.field(rawEntity, key);
                                        if (schema != null && entity != null && Reflect.hasField(schema, entity)) {
                                            entityData.schema = Reflect.field(schema, entity);
                                        }
                                    case 'kind' | 'id' | 'locked' | 'components' | 'data':
                                    case _:
                                        Reflect.setField(
                                            entityData.props,
                                            key,
                                            Reflect.field(rawEntity, key)
                                        );
                                }
                            }

                            items.push(entityData);
                        }
                    }

                    fragmentData.items = items;
                    fragments.set(fragmentData.id, fragmentData);
                }
            }
        }
        else {
            log.warning('Unsupported fragments file version: $version');
        }

        return fragments;

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
