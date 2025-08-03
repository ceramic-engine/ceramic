package ceramic.macros;

#if macro

import haxe.Json;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;

/**
 * Cache entry structure for storing macro-computed values.
 */
typedef MacroCacheEntry = {

    /**
     * Timestamp when the entry was created or last updated.
     */
    var time:Int;

    /**
     * The cached value, can be any type.
     */
    var value:Dynamic;

}

/**
 * Provides persistent caching functionality for macro-time computations.
 * 
 * This utility helps improve compilation performance by caching expensive
 * macro computations between builds. The cache is particularly useful during
 * IDE completion requests where macros would otherwise need to recompute
 * values repeatedly.
 * 
 * ## Features
 * 
 * - Persistent cache stored in `.cache/macro-cache` within the target directory
 * - Automatic serialization/deserialization of cached values
 * - Cache is loaded during completion requests, cleared during full builds
 * - Thread-safe file operations with error handling
 * 
 * ## Usage
 * 
 * ```haxe
 * // In a macro:
 * var cachedValue = MacroCache.get("myExpensiveComputation");
 * if (cachedValue == null) {
 *     cachedValue = performExpensiveComputation();
 *     MacroCache.set("myExpensiveComputation", cachedValue);
 * }
 * ```
 * 
 * ## Implementation Details
 * 
 * - Cache is only available in macro context (#if macro)
 * - Uses Haxe serialization for storing complex data structures
 * - Automatically saves cache after code generation
 * - Handles file system errors gracefully
 * 
 * @see ceramic.macros.AssetsMacro For an example of cache usage
 * @see ceramic.macros.CollectionsMacro For another cache usage example
 */
class MacroCache {

    static var entries:Map<String,MacroCacheEntry>;

    /**
     * Initializes the macro cache system.
     * 
     * This method should be called early in the macro process to set up
     * cache loading and saving. It:
     * - Loads existing cache during completion requests
     * - Sets up automatic cache saving after code generation
     * - Creates cache directory if it doesn't exist
     * 
     * No-op if target_path is not defined.
     */
    public static function init():Void {

        var cacheFilePath = getCacheFilePath();
        if (cacheFilePath == null) {
            return;
        }

        loadEntries();

        var isCompletion = Context.defined('completion');
        Context.onAfterGenerate(function() {

            if (isCompletion && FileSystem.exists(cacheFilePath)) {
                return;
            }

            try {
                var serializer = new Serializer();
                serializer.serialize(entries);
                File.saveContent(cacheFilePath, serializer.toString());

            } catch (e:Dynamic) {
                Sys.println('Error when saving macro cache: ' + e);
            }
        });

    }

    /**
     * Retrieves a value from the cache.
     * 
     * If the cache hasn't been loaded yet, it will be loaded automatically.
     * 
     * @param key The cache key to look up
     * @return The cached value, or null if not found
     */
    public static function get(key:String):Dynamic {

        if (entries == null) {
            loadEntries();
        }

        return entries != null ? entries.get(key) : null;

    }

    /**
     * Stores a value in the cache.
     * 
     * The value will be automatically serialized and persisted after
     * code generation completes.
     * 
     * @param key The cache key
     * @param value The value to cache (must be serializable)
     */
    public static function set(key:String, value:Dynamic):Void {

        if (entries == null) return;
        entries.set(key, value);

    }

// Internal helpers

    /**
     * Determines the file path for the cache file.
     * 
     * @return Path to the cache file, or null if target_path is not defined
     */
    static function getCacheFilePath():String {

        var targetPath = DefinesMacro.jsonDefinedValue('target_path');

        if (targetPath == null) {
            return null;
        }

        var cacheDir = Path.join([targetPath, '.cache']);
        if (!FileSystem.exists(cacheDir)) {
            FileSystem.createDirectory(cacheDir);
        }
        var name = 'macro-cache';
        return Path.join([cacheDir, name]);

    }

    /**
     * Loads cache entries from disk.
     * 
     * During completion requests, attempts to load the existing cache.
     * During full builds, initializes an empty cache.
     * Handles deserialization errors gracefully.
     */
    static function loadEntries():Void {

        var isCompletion = Context.defined('completion');
        var cacheFilePath = getCacheFilePath();

        if (cacheFilePath == null) {
            return;
        }

        if (isCompletion) {
            if (FileSystem.exists(cacheFilePath)) {
                try {
                    var content = File.getContent(cacheFilePath);
                    var unserializer = new Unserializer(content);
                    entries = unserializer.unserialize();

                } catch (e:Dynamic) {
                    // Failed to parse cache
                    Sys.println('Error when loading macro cache: ' + e);
                }
            }
        } else {
            entries = new Map();
        }

    }

}

#end
