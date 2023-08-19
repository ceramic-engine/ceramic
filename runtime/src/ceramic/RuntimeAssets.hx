package ceramic;

import ceramic.App.app;
import ceramic.PlatformSpecific;

using StringTools;
#if (sys || node || nodejs)
import sys.FileSystem;
#end


/**
 * Runtime utilities to compute asset lists/names from raw (relative) file list.
 * Code is very similar to AssetsMacro, but for runtime execution, with any list of asset.
 */
class RuntimeAssets {

    var allAssets:Array<String> = null;

    var allAssetDirs:Array<String> = null;

    var assetsByBaseName:Map<String,Array<String>> = null;

    var assetDirsByBaseName:Map<String,Array<String>> = null;

    var cachedNames:Map<String,Array<{
        name: String,
        paths: Array<String>,
        constName: String
    }>> = new Map();

    var cachedLists:{
        all: Array<String>,
        allDirs: Array<String>,
        allByName: Map<String,Array<String>>,
        allDirsByName: Map<String,Array<String>>
    } = null;

    public var path(default, null):String = null;

    public function new(allAssets:Array<String>, ?path:String) {

        this.allAssets = allAssets;
        this.path = path;

        initData();

    }

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

    public static function fromPath(path:String):RuntimeAssets {

        #if (sys || node || nodejs || (web && ceramic_use_electron))
        return new RuntimeAssets(Files.getFlatDirectory(path), path);
        #else
        return null;
        #end

    }

/// Public API

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
            case 'font': ['fnt'];
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
     * Same as getLists(), but will transform Maps into JSON-encodable raw objects.
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

    static function isAsciiChar(c:String):Bool {

        var code = c.charCodeAt(0);
        return (code >= '0'.code && code <= '9'.code)
            || (code >= 'A'.code && code <= 'Z'.code)
            || (code >= 'a'.code && code <= 'z'.code);

    }

}
