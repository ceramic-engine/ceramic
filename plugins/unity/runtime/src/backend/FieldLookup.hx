package backend;

import haxe.crypto.Md5;
import unityengine.TextAsset;
import cs.NativeArray;

using StringTools;

#if !no_backend_docs
/**
 * Handles runtime field lookup for reflection in Unity builds.
 * 
 * This class is critical for maintaining reflection capabilities in Unity
 * where aggressive code stripping might remove field information. It loads
 * pre-generated lookup tables from Resources that map field names to IDs
 * and vice versa, enabling dynamic field access at runtime.
 * 
 * The lookup tables are generated during the build process and contain:
 * - `lookup_i`: Field ID mappings (integers)
 * - `lookup_s`: Field name mappings (strings)
 * 
 * Each lookup file is validated using MD5 hashes to ensure data integrity.
 * This system allows Ceramic to maintain its dynamic capabilities while
 * working within Unity's AOT compilation constraints.
 * 
 * @see backend.Backend.init() Ensures this class is retained by calling keep()
 */
#end
@:keep @:keepSub
class FieldLookup {

    #if !no_backend_docs
    /**
     * Placeholder method to prevent dead code elimination.
     * Must be called during initialization to ensure this class
     * and its methods are retained in the final build.
     */
    #end
    @:keep public static function keep():Void {}

    #if !no_backend_docs
    /**
     * Loads field ID lookup table from Resources.
     * 
     * The lookup_i file contains integer field IDs, one per line.
     * These IDs are used for fast field access without string comparisons.
     * 
     * @param numFields Expected number of fields in the lookup table
     * @param hash MD5 hash to validate the loaded data
     * @return Native array containing field IDs in order
     * @throws String if the hash doesn't match (data corruption)
     */
    #end
    @:keep public static function loadFieldIds(numFields:Int, hash:String):NativeArray<Int> {

        var result:NativeArray<Int> = new NativeArray(numFields);

        var textAsset:TextAsset = untyped __cs__('UnityEngine.Resources.Load<UnityEngine.TextAsset>("lookup_i")');
        
        if (Md5.encode(textAsset.text) != hash) {
            throw "Invalid field lookup ids";
        }
        
        var items = textAsset.text.split("\n");

        var i = 0;
        for (item in items) {
            result[i] = Std.int(Std.parseInt(item));
            i++;
        }

        untyped __cs__('UnityEngine.Resources.UnloadAsset({0})', textAsset);

        return result;

    }

    #if !no_backend_docs
    /**
     * Loads field name lookup table from Resources.
     * 
     * The lookup_s file contains field names as strings, one per line.
     * These names correspond to the IDs loaded by loadFieldIds().
     * 
     * @param numFields Expected number of fields in the lookup table
     * @param hash MD5 hash to validate the loaded data
     * @return Native array containing field names in order
     * @throws String if the hash doesn't match (data corruption)
     */
    #end
    @:keep public static function loadFieldNames(numFields:Int, hash:String):NativeArray<String> {

        var result:NativeArray<String> = new NativeArray(numFields);

        var textAsset:TextAsset = untyped __cs__('UnityEngine.Resources.Load<UnityEngine.TextAsset>("lookup_s")');
        
        if (Md5.encode(textAsset.text) != hash) {
            throw "Invalid field lookup names";
        }
        
        var items = textAsset.text.split("\n");

        var i = 0;
        for (item in items) {
            result[i] = item;
            i++;
        }

        untyped __cs__('UnityEngine.Resources.UnloadAsset({0})', textAsset);

        return result;

    }

}
