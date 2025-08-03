package ceramic.macros;

import haxe.Json;
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;

using StringTools;

/**
 * Build macro that processes ceramic.yml configuration and generates app metadata at compile time.
 * This macro is responsible for extracting app information from the project configuration
 * and making it available as static properties on the App class.
 * 
 * The macro processes collections defined in ceramic.yml, ensuring their types are resolved
 * at compile time, and converts the configuration data into a format suitable for runtime use.
 */
class AppMacro {

    /**
     * Cached computed info to avoid reprocessing during the same compilation.
     */
    static var computedInfo:Dynamic;

    /**
     * Gets the computed app information from raw JSON string.
     * Results are cached after first computation to improve build performance.
     * @param rawInfo JSON string containing app configuration from ceramic.yml
     * @return Processed app configuration object
     */
    static public function getComputedInfo(rawInfo:String):Dynamic {

        if (AppMacro.computedInfo == null) AppMacro.computedInfo = computeInfo(rawInfo);
        return AppMacro.computedInfo;

    }

    /**
     * Build macro that adds app configuration data as a static field to the App class.
     * This macro:
     * - Loads collection types defined in ceramic.yml to ensure they're compiled
     * - Converts configuration arrays to objects for easier access
     * - Adds an 'info' field containing all app metadata
     * 
     * @return Modified fields array with added 'info' field
     */
    macro static public function build():Array<Field> {

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> BEGIN AppMacro.build()');
        #end

        var fields = Context.getBuildFields();

        var data = getComputedInfo(Context.definedValue('app_info'));

        // Load collection types from ceramic.yml
        for (key in Reflect.fields(data.collections)) {
            var val:Dynamic = Reflect.field(data.collections, key);
            if (Std.isOfType(val, String)) {
                Context.getType(val);
            }
            else {
                for (k in Reflect.fields(val)) {
                    var v:Dynamic = Reflect.field(val, k);
                    if (v.type == null) v.type = 'ceramic.CollectionEntry';
                    Context.getType(v.type);
                }
            }
        }

        var expr = Context.makeExpr(data, Context.currentPos());

        fields.push({
            pos: Context.currentPos(),
            name: 'info',
            kind: FVar(null, expr),
            access: [APublic],
            doc: 'App info extracted from `ceramic.yml`',
            meta: [{
                name: ':dox',
                params: [macro hide],
                pos: Context.currentPos()
            }]
        });

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> END AppMacro.build()');
        #end

        return fields;

    }

    /**
     * Processes raw app info JSON string into a structured object.
     * Handles double JSON parsing (the raw info is JSON-encoded twice) and
     * converts arrays to objects for easier compile-time access.
     * 
     * @param rawInfo Double-encoded JSON string from ceramic.yml configuration
     * @return Processed configuration object with arrays converted to objects
     */
    static function computeInfo(rawInfo:String):Dynamic {

        var data:Dynamic = {};

        if (rawInfo != null) {
            // AppMacro.rawInfo can be null when running stuff like "go to definition" from compiler
            data = convertArrays(Json.parse(Json.parse(rawInfo)));
        }

        // Add required info
        if (data.collections == null) data.collections = {};

        return data;

    }

    /**
     * Recursively converts arrays in configuration data to objects.
     * This transformation is necessary because Haxe macros work better with
     * object fields than array indices when generating compile-time code.
     * 
     * Arrays are converted to objects with keys like "item0", "item1", etc.
     * 
     * @param data Configuration data that may contain arrays
     * @return Transformed data with arrays converted to objects
     */
    static function convertArrays(data:Dynamic):Dynamic {

        var newData:Dynamic = {};

        for (key in Reflect.fields(data)) {

            var val:Dynamic = Reflect.field(data, key);

            if (Std.isOfType(val, Array)) {
                var items:Dynamic = {};
                var list:Array<Dynamic> = val;
                var i = 0;
                for (item in list) {
                    Reflect.setField(items, 'item$i', item);
                    i++;
                }
                Reflect.setField(newData, key, items);
            }
            else if (val == null || Std.isOfType(val, String) || Std.isOfType(val, Int) || Std.isOfType(val, Float) || Std.isOfType(val, Bool)) {
                Reflect.setField(newData, key, val);
            }
            else {
                Reflect.setField(newData, key, convertArrays(val));
            }

        }

        return newData;

    }

}
