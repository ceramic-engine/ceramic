package ceramic;

import ceramic.App.app;
import ceramic.Platform;

using StringTools;
#if (sys || node || nodejs)
import sys.FileSystem;
#end


/**
 * Runtime utilities to compute asset lists/names from raw (relative) file list.
 * 
 * RuntimeAssets provides runtime access to asset information that is normally
 * generated at compile-time by AssetsMacro. This allows dynamic asset discovery
 * and loading, particularly useful for:
 * - Hot-reloading during development
 * - Dynamic content loading
 * - User-generated content
 * - Asset browsing tools
 * 
 * The class processes a flat list of asset paths and organizes them by:
 * - Base name (filename without extension and density suffix)
 * - Asset kind (image, sound, text, etc.)
 * - Directory structure
 * 
 * It also handles density variants (e.g., @2x, @3x) and provides
 * constant-style names for programmatic access.
 * 
 * ```haxe
 * // Create from a directory path
 * var runtimeAssets = RuntimeAssets.fromPath('assets/');
 * 
 * // Get all image asset names
 * var imageNames = runtimeAssets.getNames('image');
 * for (entry in imageNames) {
 *     trace('Image: ${entry.name} at ${entry.paths}');
 * }
 * 
 * // Get organized asset lists
 * var lists = runtimeAssets.getLists();
 * trace('All assets: ${lists.all}');
 * trace('Assets for "player": ${lists.allByName.get("player")}');
 * ```
 * 
 * @see Assets
 * @see AssetsMacro
 */
class RuntimeAssets {

    var transformedDir:String = null;
    var didQueryTransformedDir:Int = 0;
    var pendingTransformedDirCallbacks:Array<(transformedDir:String)->Void> = null;
    
    /**
     * Requests the transformed assets directory path asynchronously.
     * This is the temporary directory where processed assets are stored.
     * 
     * The method caches the result after the first query to avoid repeated
     * platform calls. Multiple simultaneous requests are queued and resolved
     * together.
     * 
     * @param callback Function called with the transformed directory path (may be null if unavailable)
     */
    public function requestTransformedDir(callback:(transformedDir:String)->Void):Void {
        if (didQueryTransformedDir == 2) {
            app.onceImmediate(() -> callback(transformedDir));
        }
        else if (didQueryTransformedDir == 1) {
            if (pendingTransformedDirCallbacks == null) {
                pendingTransformedDirCallbacks = [];
            }
            pendingTransformedDirCallbacks.push(callback);
        }
        else {
            didQueryTransformedDir = 1;
            Platform.runCeramic(['tmp', 'dir'], (code, out, err) -> {
                if (code == 0) {
                    var result = out.trim();
                    if (result.length > 0 && Files.exists(result)) {
                        transformedDir = result;
                    }
                }
                else {
                    app.logger.error('Failed to resolve tmp dir: $code / $err');
                }
                didQueryTransformedDir = 2;
                callback(transformedDir);
                if (pendingTransformedDirCallbacks != null) {
                    var transformedDirCallbacks = pendingTransformedDirCallbacks;
                    pendingTransformedDirCallbacks = null;
                    for (cb in transformedDirCallbacks) {
                        cb(transformedDir);
                    }
                }
            });
        }
    }

    /** All asset file paths in the collection */
    var allAssets:Array<String> = null;

    /** All unique directory paths containing assets */
    var allAssetDirs:Array<String> = null;

    /** Map of base names to their file variants (including density variants) */
    var assetsByBaseName:Map<String,Array<String>> = null;

    /** Map of base directory names to their path variants */
    var assetDirsByBaseName:Map<String,Array<String>> = null;

    /** Cache of computed asset names by kind and options */
    var cachedNames:Map<String,Array<{
        name: String,
        paths: Array<String>,
        constName: String
    }>> = new Map();

    /** Cache of computed asset lists */
    var cachedLists:{
        all: Array<String>,
        allDirs: Array<String>,
        allByName: Map<String,Array<String>>,
        allDirsByName: Map<String,Array<String>>
    } = null;

    /**
     * The root path of the assets directory, if created from a path.
     * Will be null if created with a pre-computed asset list.
     */
    public var path(default, null):String = null;

    /**
     * Creates a new RuntimeAssets instance with a pre-computed list of asset paths.
     * 
     * @param allAssets Array of relative asset paths (e.g., ["images/player.png", "sounds/jump.ogg"])
     * @param path Optional root path where these assets are located
     */
    public function new(allAssets:Array<String>, ?path:String) {

        this.allAssets = allAssets;
        this.path = path;

        initData();

    }

    /**
     * Resets the runtime assets with a new list of files.
     * Clears all caches and recomputes the asset organization.
     * 
     * @param allAssets New array of asset paths
     * @param path Optional new root path
     */
    public function reset(allAssets:Array<String>, ?path:String) {

        this.allAssets = allAssets;
        this.path = path;

        allAssetDirs = null;
        assetsByBaseName = null;
        assetDirsByBaseName = null;
        cachedNames = new Map();
        cachedLists = null;

        initData();

    }

    /**
     * Creates a RuntimeAssets instance by scanning a directory path.
     * Only available on platforms with file system access.
     * 
     * @param path The directory path to scan for assets
     * @return RuntimeAssets instance, or null if file system access is not available
     */
    public static function fromPath(path:String):RuntimeAssets {

        #if (sys || node || nodejs || (web && ceramic_use_electron))
        return new RuntimeAssets(Files.getFlatDirectory(path), path);
        #else
        return null;
        #end

    }

/// Public API

    /**
     * Gets all asset names of a specific kind with their paths and constant names.
     * 
     * This method finds all assets matching the specified kind and optional extensions,
     * returning structured information about each unique asset (by base name).
     * 
     * @param kind Asset type: 'image', 'text', 'sound', 'shader', 'font', 'atlas', 'database', 'fragments'
     * @param extensions Optional additional file extensions to include (beyond the defaults for the kind)
     * @param dir Whether to search for directories instead of files
     * @return Array of asset entries with:
     *         - name: Base name without extension or density suffix
     *         - paths: All file paths for this asset (including variants)
     *         - constName: Constant-style name for code generation (e.g., "PLAYER_SPRITE")
     */
    public function getNames(kind:String, ?extensions:Array<String>, dir:Bool = false):Array<{
        name: String,
        paths: Array<String>,
        constName: String
    }> {

        var cacheKey = kind + '|' + (extensions != null ? extensions.join(',') : '') + (dir ? '|1' : '|0');
        var cached = cachedNames.get(cacheKey);
        if (cached != null) return cached;

        var entries = [];

        if (extensions == null) extensions = [];
        extensions = extensions.concat(switch (kind) {
            #if plugin_ase
            case 'image': app.backend.info.imageExtensions().concat(['ase', 'aseprite']);
            #else
            case 'image': app.backend.info.imageExtensions();
            #end
            case 'text': app.backend.info.textExtensions();
            case 'sound': app.backend.info.soundExtensions();
            case 'shader': app.backend.info.shaderExtensions();
            case 'font': ['fnt', 'ttf', 'otf'];
            case 'atlas': ['atlas'];
            case 'database': ['csv'];
            case 'fragments': ['fragments'];
            default: [];
        });

        if (extensions.length == 0) return entries;

        var used = new Map<String,String>();
        var fileList = dir ? allAssetDirs : allAssets;

        for (ext in extensions) {

            for (name in fileList) {

                var lowerName = name.toLowerCase();
                var dotIndex = lowerName.lastIndexOf('.');
                var fileExt = null;
                var baseName = null;
                var fieldName = null;

                if (dotIndex != -1) {
                    fileExt = lowerName.substr(dotIndex + 1);

                    if (fileExt == ext) {

                        var truncatedName = name.substr(0, dotIndex);
                        var baseAtIndex = truncatedName.lastIndexOf('@');
                        if (baseAtIndex == -1) baseAtIndex = dotIndex;

                        baseName = name.substr(0, cast Math.min(baseAtIndex, dotIndex));
                        fieldName = toAssetConstName(baseName);

                        if (fieldName != null && !used.exists(fieldName) && fileExt != null) {
                            used.set(fieldName, baseName);
                        }
                    }
                }
            }
        }

        // Add fields
        var byBaseName = dir ? assetDirsByBaseName : assetsByBaseName;
        for (fieldName in used.keys()) {
            var value = kind + ':' + used.get(fieldName);

            var fieldDoc = [];
            var files = byBaseName.get(used.get(fieldName));
            for (file in files) {
                for (ext in extensions) {
                    if (file.endsWith('.$ext')) {
                        fieldDoc.push(file);
                        break;
                    }
                }
            }

            var entry = {
                name: used.get(fieldName),
                constName: fieldName,
                paths: fieldDoc
            };

            entries.push(entry);
        }

        cachedNames.set(cacheKey, entries);

        return entries;

    }

    /**
     * Gets organized lists of all assets in various formats.
     * 
     * Returns a comprehensive view of all assets organized by:
     * - Complete file lists
     * - Directory lists
     * - Files grouped by base name
     * - Directories grouped by base name
     * 
     * The results are cached for performance.
     * 
     * @return Object containing:
     *         - all: Array of all asset file paths
     *         - allDirs: Array of all directory paths containing assets
     *         - allByName: Map of base names to their file variants
     *         - allDirsByName: Map of base directory names to their variants
     */
    public function getLists():{
        all: Array<String>,
        allDirs: Array<String>,
        allByName: Map<String,Array<String>>,
        allDirsByName: Map<String,Array<String>>
    } {

        if (cachedLists != null) return cachedLists;

        var result = {
            all: [],
            allDirs: [],
            allByName: new Map(),
            allDirsByName: new Map()
        };

        // All assets
        //
        for (name in allAssets) {
            result.all.push(name);
        }

        // All asset dirs
        //
        for (name in allAssetDirs) {
            result.allDirs.push(name);
        }

        // Assets by base name
        //
        for (baseName in assetsByBaseName.keys()) {
            var list = [].concat(assetsByBaseName.get(baseName));
            result.allByName.set(baseName, list);
        }

        // Asset dirs by base name
        //
        for (baseName in assetDirsByBaseName.keys()) {
            var list = [].concat(assetDirsByBaseName.get(baseName));
            result.allDirsByName.set(baseName, list);
        }

        cachedLists = result;

        return result;

    }

    /**
     * Same as getLists(), but transforms Maps into JSON-encodable objects.
     * 
     * This is useful when you need to serialize the asset lists to JSON
     * or send them over a network, as Maps cannot be directly JSON-encoded.
     * 
     * @return Same structure as getLists() but with Maps converted to Dynamic objects
     */
    public function getEncodableLists():{
        all: Array<String>,
        allDirs: Array<String>,
        allByName: Dynamic<Array<String>>,
        allDirsByName: Dynamic<Array<String>>
    } {

        var lists = getLists();

        var allByNameEncodable:Dynamic<Array<String>> = {};
        for (key in lists.allByName.keys()) {
            Reflect.setField(allByNameEncodable, key, lists.allByName.get(key));
        }

        var allDirsByNameEncodable:Dynamic<Array<String>> = {};
        for (key in lists.allDirsByName.keys()) {
            Reflect.setField(allDirsByNameEncodable, key, lists.allDirsByName.get(key));
        }

        return {
            all: lists.all,
            allDirs: lists.allDirs,
            allByName: allByNameEncodable,
            allDirsByName: allDirsByNameEncodable
        };

    }

/// Internal

    /**
     * Converts an asset path to a constant-style name suitable for code generation.
     * 
     * Transformation rules:
     * - Slashes (/) become double underscores (__)
     * - Dots (.) become single underscores (_)
     * - camelCase becomes CAMEL_CASE
     * - Special characters are replaced with underscores
     * - Result is all uppercase
     * 
     * @param input Asset path (e.g., "sprites/player.png")
     * @return Constant name (e.g., "SPRITES__PLAYER")
     */
    static function toAssetConstName(input:String):String {

        var res = new StringBuf();
        var len = input.length;
        var i = 0;
        var canAddSpace = false;

        while (i < len) {

            var c = input.charAt(i);
            if (c == '/') {
                res.add('__');
                canAddSpace = false;
            }
            else if (c == '.') {
                res.add('_');
                canAddSpace = false;
            }
            else if (isAsciiChar(c)) {

                var uc = c.toUpperCase();
                var isUpperCase = (c == uc);

                if (canAddSpace && isUpperCase) {
                    res.add('_');
                    canAddSpace = false;
                }

                res.add(uc);
                canAddSpace = !isUpperCase;
            }
            else {
                res.add('_');
                canAddSpace = false;
            }

            i++;
        }

        var str = res.toString();
        if (str.endsWith('_')) str = str.substr(0, str.length - 1);

        return str;

    }

    /**
     * Initializes internal data structures from the asset list.
     * 
     * This method:
     * - Extracts all unique directories from file paths
     * - Groups files by their base names (without extensions/variants)
     * - Groups directories by their base names
     * - Prepares the data for efficient querying
     */
    function initData() {

        // Compute data
        //
        var usedPaths:Map<String,Bool> = new Map();

        for (asset in allAssets) {
            usedPaths.set(asset, true);
        }

        var usedDirs:Map<String,Bool> = new Map();
        allAssetDirs = [];
        for (asset in allAssets) {
            var lastSlash = asset.lastIndexOf('/');
            if (lastSlash != -1) {
                var dir = asset.substr(0, lastSlash);
                while (!usedDirs.exists(dir)) {
                    allAssetDirs.push(dir);
                    usedDirs.set(dir, true);
                    lastSlash = dir.lastIndexOf('/');
                    if (lastSlash == -1) break;
                    dir = dir.substr(0, lastSlash);
                }
            }
        }

        if (assetsByBaseName == null) {

            assetsByBaseName = new Map();

            for (name in allAssets) {
                var dotIndex = name.lastIndexOf('.');
                var truncatedName = name.substr(0, dotIndex);
                var baseAtIndex = truncatedName.lastIndexOf('@');
                if (baseAtIndex == -1) baseAtIndex = dotIndex;

                var baseName = name.substr(0, cast Math.min(baseAtIndex, dotIndex));
                if (!assetsByBaseName.exists(baseName)) {
                    assetsByBaseName.set(baseName, []);
                }
                var list = assetsByBaseName.get(baseName);
                list.push(name);
            }
        }

        if (assetDirsByBaseName == null) {

            assetDirsByBaseName = new Map();

            for (name in allAssetDirs) {
                var dotIndex = name.lastIndexOf('.');
                var truncatedName = name.substr(0, dotIndex);
                var baseAtIndex = truncatedName.lastIndexOf('@');
                if (baseAtIndex == -1) baseAtIndex = dotIndex;

                var baseName = name.substr(0, cast Math.min(baseAtIndex, dotIndex));
                if (!assetDirsByBaseName.exists(baseName)) {
                    assetDirsByBaseName.set(baseName, []);
                }
                var list = assetDirsByBaseName.get(baseName);
                list.push(name);
            }
        }

    }

    /**
     * Checks if a character is a valid ASCII alphanumeric character.
     * Used for generating valid constant names.
     * 
     * @param c Single character string
     * @return True if the character is 0-9, A-Z, or a-z
     */
    static function isAsciiChar(c:String):Bool {

        var code = c.charCodeAt(0);
        return (code >= '0'.code && code <= '9'.code)
            || (code >= 'A'.code && code <= 'Z'.code)
            || (code >= 'a'.code && code <= 'z'.code);

    }

}
