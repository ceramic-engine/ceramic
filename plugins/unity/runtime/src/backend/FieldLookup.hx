package backend;

import haxe.crypto.Md5;
import unityengine.TextAsset;
import cs.NativeArray;

using StringTools;

@:keep @:keepSub
class FieldLookup {

    // Placeholder method to be called just to ensure code from this class will be kept and not removed by dce
    @:keep public static function keep():Void {}

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
