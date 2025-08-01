package ceramic;

import ceramic.Shortcuts.*;
import haxe.DynamicAccess;

/**
 * Asset for loading CSV database files.
 * 
 * DatabaseAsset loads CSV (Comma-Separated Values) files and parses them
 * into an array of dynamic objects, where each row becomes an object with
 * properties based on the CSV headers.
 * 
 * Features:
 * - Automatic CSV parsing with header detection
 * - Support for both comma and semicolon separators
 * - Quoted string handling with escape sequences
 * - Hot-reload support for database files
 * - Each row accessible as a dynamic object
 * 
 * CSV Format:
 * - First row must contain column headers (field names)
 * - Supports comma (,) or semicolon (;) as separators
 * - String values can be quoted with double quotes
 * - Use "" to escape quotes within quoted strings
 * 
 * @example
 * ```haxe
 * // Load a CSV database
 * var dbAsset = new DatabaseAsset('enemies');
 * dbAsset.path = 'data/enemies.csv';
 * dbAsset.onComplete(this, success -> {
 *     if (success) {
 *         // Access the parsed data
 *         for (row in dbAsset.database) {
 *             trace('Enemy: ${row.get("name")} HP: ${row.get("hp")}');
 *         }
 *         
 *         // Find specific entries
 *         var boss = dbAsset.database.find(row -> row.get("type") == "boss");
 *     }
 * });
 * assets.addAsset(dbAsset);
 * assets.load();
 * ```
 * 
 * Example CSV content:
 * ```csv
 * name,hp,damage,type
 * Goblin,10,5,normal
 * Orc,20,10,normal
 * "Dragon King",100,50,boss
 * ```
 * 
 * @see Asset
 * @see Csv
 */
class DatabaseAsset extends Asset {

    /**
     * The parsed database as an array of dynamic objects.
     * Each object represents a row, with properties matching the CSV headers.
     * Will be null until the asset is successfully loaded.
     * 
     * Access values using the get() method:
     * ```haxe
     * var name = row.get("name");
     * var hp = Std.parseInt(row.get("hp"));
     * ```
     */
    @observe public var database:Array<DynamicAccess<String>> = null;

    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('database', name, variant, options #if ceramic_debug_entity_allocs , pos #end);

    }

    /**
     * Loads the CSV database file from the specified path.
     * 
     * The file is loaded as text and then parsed using the CSV parser.
     * The parsing automatically detects whether comma or semicolon is used
     * as the separator based on the first line.
     * 
     * On success, the database property will contain the parsed data.
     * On failure (file not found or parse error), the asset status becomes BROKEN.
     */
    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load database asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        var loadOptions:AssetOptions = {};
        if (owner != null) {
            loadOptions.immediate = owner.immediate;
            loadOptions.loadMethod = owner.loadMethod;
        }

        // Add reload count if any
        var backendPath = path;
        var realPath = Assets.realAssetPath(backendPath, runtimeAssets);
        var assetReloadedCount = Assets.getReloadCount(realPath);
        if (app.backend.texts.supportsHotReloadPath() && assetReloadedCount > 0) {
            realPath += '?hot=' + assetReloadedCount;
            backendPath += '?hot=' + assetReloadedCount;
        }

        log.info('Load database $backendPath');
        app.backend.texts.load(realPath, loadOptions, function(text) {

            if (text != null) {
                try {
                    this.database = Csv.parse(text);
                } catch (e:Dynamic) {
                    status = BROKEN;
                    log.error('Failed to parse database at path: $path');
                    emitComplete(false);
                    return;
                }
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                log.error('Failed to load database at path: $path');
                emitComplete(false);
            }

        });

    }

    /**
     * Called when asset files change on disk (hot-reload support).
     * Automatically reloads the database if its CSV file has been modified.
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
            log.info('Reload database (file has changed)');
            load();
        }

    }

    /**
     * Destroys the database asset and clears the loaded data from memory.
     */
    override function destroy():Void {

        super.destroy();

        database = null;

    }

}
