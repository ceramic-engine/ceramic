package ceramic.macros;

#if macro

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

typedef MacroCacheEntry = {

    var time:Int;

    var value:Dynamic;

} //MacroCacheEntry

class MacroCache {

    static var entries:Map<String,MacroCacheEntry>;

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

    } //init

    public static function get(key:String):Dynamic {

        if (entries == null) {
            loadEntries();
        }

        return entries != null ? entries.get(key) : null;

    } //get

    public static function set(key:String, value:Dynamic):Void {

        if (entries == null) return;
        entries.set(key, value);

    } //set

/// Internal

    static function getCacheFilePath():String {

        var targetPath = Context.definedValue('target_path');

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
                    // Faile to parse cache
                    Sys.println('Error when loading macro cache: ' + e);
                }
            }
        } else {
            entries = new Map();
        }

    } //loadEntries

} //MacroCache

#end
