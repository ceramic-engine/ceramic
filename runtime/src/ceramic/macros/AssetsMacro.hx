package ceramic.macros;

import haxe.Json;
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;

using StringTools;

/**
 * Build macro that generates compile-time constants for all project assets.
 * This macro scans the assets directory and creates type-safe string constants
 * for each asset file, allowing compile-time verification of asset references.
 * 
 * The macro supports multiple asset sources:
 * - Project-specific assets (highest priority)
 * - Plugin-provided assets (medium priority)
 * - Ceramic default assets (lowest priority)
 * 
 * Asset constants are generated based on file paths, with special handling for:
 * - Density variants (@2x, @3x, etc.)
 * - Directory hierarchies (converted to double underscores)
 * - File extensions (filtered by asset type)
 */
class AssetsMacro {

    /**
     * Backend information provider for platform-specific asset extensions.
     */
    public static var backendInfo:backend.Info = null;

    /**
     * Complete list of all asset file paths discovered during compilation.
     */
    public static var allAssets:Array<String> = null;

    /**
     * Complete list of all asset directory paths.
     */
    public static var allAssetDirs:Array<String> = null;

    /**
     * Map of asset base names to all variants (different densities, extensions).
     */
    public static var assetsByBaseName:Map<String,Array<String>> = null;

    /**
     * Map of directory base names to all matching directories.
     */
    public static var assetDirsByBaseName:Map<String,Array<String>> = null;

    /**
     * Regular expression to match valid ASCII characters for constant names.
     */
    public static var reAsciiChar = ~/^[a-zA-Z0-9]$/;

    /**
     * Regular expression to match valid constant name start characters.
     */
    public static var reConstStart = ~/^[a-zA-Z_]$/;

    /**
     * Generates static constants for assets of a specific type.
     * Creates fields like `PLAYER_SPRITE` for "player.png" assets.
     * 
     * @param kind Asset type: 'image', 'text', 'sound', 'shader', 'font', 'atlas', 'database', 'fragments'
     * @param extensions Additional file extensions to include beyond defaults
     * @param dir Whether to generate constants for directories instead of files
     * @return Array of generated fields to add to the class
     */
    macro static public function buildNames(kind:String, ?extensions:Array<String>, dir:Bool = false):Array<Field> {

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> BEGIN AssetsMacro.buildNames($kind, $extensions, $dir)');
        #end

        initData(DefinesMacro.jsonDefinedValue('assets_path'), Context.definedValue('ceramic_extra_assets_paths'), DefinesMacro.jsonDefinedValue('ceramic_assets_path'));

        var fields = Context.getBuildFields();
        var pos = Context.currentPos();

        for (field in computeNames(fields, pos, kind, extensions, dir)) {
            fields.push(field);
        }

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> END AssetsMacro.buildNames()');
        #end

        return fields;

    }

    /**
     * Computes asset name constants for a specific asset type.
     * Processes discovered assets and generates static fields with AssetId typing.
     * 
     * @param inFields Existing fields (unused but kept for API compatibility)
     * @param pos Source position for generated fields
     * @param kind Asset type determining default extensions
     * @param extensions Additional extensions to include
     * @param dir Whether to process directories instead of files
     * @return Array of generated constant fields
     */
    static public function computeNames(inFields:Array<Field>, pos:Position, kind:String, ?extensions:Array<String>, dir:Bool = false):Array<Field> {

        if (extensions == null) extensions = [];
        extensions = extensions.concat(switch (kind) {
            #if plugin_ase
            case 'image': backendInfo.imageExtensions().concat(['ase', 'aseprite']);
            #else
            case 'image': backendInfo.imageExtensions();
            #end
            case 'text': backendInfo.textExtensions();
            case 'sound': backendInfo.soundExtensions();
            case 'shader': backendInfo.shaderExtensions();
            case 'font': ['fnt', 'ttf', 'otf'];
            case 'atlas': ['atlas'];
            case 'database': ['csv'];
            case 'fragments': ['fragments'];
            default: [];
        });

        var fields = [];
        if (extensions.length == 0) return fields;

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

                        baseName = name.substr(0, Std.int(Math.min(baseAtIndex, dotIndex)));
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

            var expr = { expr: ECast({ expr: EConst(CString(value)), pos: pos }, null), pos: pos };

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

            var field = {
                pos: pos,
                name: fieldName,
                kind: FProp('default', 'null', macro :ceramic.AssetId<String>, expr),
                access: [AStatic, APublic],
                doc: fieldDoc.join(', '),
                meta: []
            };

            fields.push(field);
        }

        return fields;

    }

    /**
     * Generates static arrays and maps containing all discovered assets.
     * Creates fields for:
     * - `all`: Array of all asset paths
     * - `allDirs`: Array of all directory paths
     * - `allByName`: Map of base names to asset variants
     * - `allDirsByName`: Map of base names to directory variants
     * 
     * @return Array of generated fields for asset listings
     */
    macro static public function buildLists():Array<Field> {

        initData(DefinesMacro.jsonDefinedValue('assets_path'), Context.definedValue('ceramic_extra_assets_paths'), DefinesMacro.jsonDefinedValue('ceramic_assets_path'));

        var fields = Context.getBuildFields();
        var pos = Context.currentPos();

        // All assets
        //
        var exprEntries = [];

        for (name in allAssets) {
            exprEntries.push({expr: EConst(CString(name)), pos: pos});
        }

        var expr = {expr: EArrayDecl(exprEntries), pos: pos};

        var field = {
            pos: pos,
            name: 'all',
            kind: FProp('default', 'null', macro :Array<String>, expr),
            access: [AStatic, APublic],
            doc: 'All asset file paths array',
            meta: []
        };

        fields.push(field);

        // All asset dirs
        //
        var exprEntries = [];

        for (name in allAssetDirs) {
            exprEntries.push({expr: EConst(CString(name)), pos: pos});
        }

        var expr = {expr: EArrayDecl(exprEntries), pos: pos};

        var field = {
            pos: pos,
            name: 'allDirs',
            kind: FProp('default', 'null', macro :Array<String>, expr),
            access: [AStatic, APublic],
            doc: 'All asset directory paths array',
            meta: []
        };

        fields.push(field);

        // Assets by base name
        //
        var exprEntries = [];

        for (baseName in assetsByBaseName.keys()) {
            var list = assetsByBaseName.get(baseName);
            var listExprs = [];

            for (entry in list) {
                listExprs.push({expr: EConst(CString(entry)), pos: pos});
            }

            exprEntries.push({expr: EBinop(OpArrow, {expr: EConst(CString(baseName)), pos: pos}, {expr: EArrayDecl(listExprs), pos: pos}), pos: pos});
        }

        var expr = exprEntries.length == 0 ? (macro new Map()) : {expr: EArrayDecl(exprEntries), pos: pos};

        var field = {
            pos: pos,
            name: 'allByName',
            kind: FProp('default', 'null', macro :Map<String,Array<String>>, expr),
            access: [AStatic, APublic],
            doc: 'Assets by base name',
            meta: []
        };

        fields.push(field);

        // Asset dirs by base name
        //
        var exprEntries = [];

        for (baseName in assetDirsByBaseName.keys()) {
            var list = assetDirsByBaseName.get(baseName);
            var listExprs = [];

            for (entry in list) {
                listExprs.push({expr: EConst(CString(entry)), pos: pos});
            }

            exprEntries.push({expr: EBinop(OpArrow, {expr: EConst(CString(baseName)), pos: pos}, {expr: EArrayDecl(listExprs), pos: pos}), pos: pos});
        }

        var expr = exprEntries.length == 0 ? (macro new Map()) : {expr: EArrayDecl(exprEntries), pos: pos};

        var field = {
            pos: pos,
            name: 'allDirsByName',
            kind: FProp('default', 'null', macro :Map<String,Array<String>>, expr),
            access: [AStatic, APublic],
            doc: 'Asset directories by base name',
            meta: []
        };

        fields.push(field);

        return fields;

    }

    /**
     * Initializes asset discovery by scanning all asset directories.
     * Processes assets in priority order: project > plugins > ceramic defaults.
     * Builds maps of assets by base name for efficient lookup.
     * 
     * @param assetsPath Project's main assets directory
     * @param ceramicPluginsAssetsPathsRaw JSON-encoded array of plugin asset paths
     * @param ceramicAssetsPath Ceramic's default assets directory
     */
    public static function initData(assetsPath:String, ceramicPluginsAssetsPathsRaw:String, ceramicAssetsPath:String):Void {

        if (backendInfo == null) backendInfo = new backend.Info();

        var ceramicPluginsAssetsPaths:Array<String> = [];
        if (ceramicPluginsAssetsPathsRaw != null) {
            ceramicPluginsAssetsPaths = Json.parse(Json.parse(ceramicPluginsAssetsPathsRaw));
        }

        if (allAssets == null) {

            var usedPaths:Map<String,Bool> = new Map();

            // Project assets
            //
            if (FileSystem.exists(assetsPath)) {
                allAssets = getFlatDirectory(assetsPath);
            } else {
                allAssets = [];
            }

            for (asset in allAssets) {
                usedPaths.set(asset, true);
            }

            // Plugins assets
            //
            for (pluginAssetsPath in ceramicPluginsAssetsPaths) {
                if (FileSystem.exists(pluginAssetsPath)) {
                    for (asset in getFlatDirectory(pluginAssetsPath)) {
                        if (!usedPaths.exists(asset)) {
                            allAssets.push(asset);
                            usedPaths.set(asset, true);
                        }
                    }
                }
            }

            // Default assets
            //
            if (FileSystem.exists(ceramicAssetsPath)) {
                for (asset in getFlatDirectory(ceramicAssetsPath)) {
                    if (!usedPaths.exists(asset)) {
                        allAssets.push(asset);
                        usedPaths.set(asset, true);
                    }
                }
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
        }

        if (assetsByBaseName == null) {

            assetsByBaseName = new Map();

            for (name in allAssets) {
                var dotIndex = name.lastIndexOf('.');
                var truncatedName = name.substr(0, dotIndex);
                var baseAtIndex = truncatedName.lastIndexOf('@');
                if (baseAtIndex == -1) baseAtIndex = dotIndex;
                var baseName = name.substr(0, Std.int(Math.min(baseAtIndex, dotIndex)));
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

                var baseName = name.substr(0, Std.int(Math.min(baseAtIndex, dotIndex)));
                if (!assetDirsByBaseName.exists(baseName)) {
                    assetDirsByBaseName.set(baseName, []);
                }
                var list = assetDirsByBaseName.get(baseName);
                list.push(name);
            }
        }

    }

    /**
     * Converts an asset path to a valid Haxe constant name.
     * Transformation rules:
     * - Slashes become double underscores
     * - Dots become single underscores
     * - camelCase is converted to CAMEL_CASE
     * - Non-alphanumeric characters become underscores
     * - Result is always uppercase
     * 
     * @param input Asset path to convert
     * @return Valid Haxe constant name
     */
    public static function toAssetConstName(input:String):String {

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
            else if (reAsciiChar.match(c)) {

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
        if (!reConstStart.match(str.charAt(0))) str = '_' + str;
        if (str.endsWith('_')) str = str.substr(0, str.length - 1);

        return str;

    }

    /**
     * Recursively retrieves all files in a directory as a flat array.
     * Excludes system files like .DS_Store by default.
     * 
     * @param dir Directory to scan
     * @param excludeSystemFiles Whether to exclude system files
     * @param subCall Internal flag for recursive calls
     * @return Array of file paths relative to the initial directory
     */
    static function getFlatDirectory(dir:String, excludeSystemFiles:Bool = true, subCall:Bool = false):Array<String> {

        var result:Array<String> = [];

        for (name in FileSystem.readDirectory(dir)) {

            if (excludeSystemFiles && name == '.DS_Store') continue;

            var path = Path.join([dir, name]);
            if (FileSystem.isDirectory(path)) {
                result = result.concat(getFlatDirectory(path, excludeSystemFiles, true));
            } else {
                result.push(path);
            }
        }

        if (!subCall) {
            var prevResult = result;
            result = [];
            var prefix = Path.normalize(dir);
            if (!prefix.endsWith('/')) prefix += '/';
            for (item in prevResult) {
                result.push(item.substr(prefix.length));
            }
        }

        return result;

    }

}