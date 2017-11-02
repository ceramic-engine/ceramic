package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;

using StringTools;

class AppMacro {

    static var computedInfo:Dynamic;
    
    static public function getComputedInfo(rawInfo:String):Dynamic {

        if (AppMacro.computedInfo == null) AppMacro.computedInfo = computeInfo(rawInfo);
        return AppMacro.computedInfo;

    } //getComputedInfo

    macro static public function build():Array<Field> {

        var fields = Context.getBuildFields();

        var data = getComputedInfo(Context.definedValue('app_info'));
        
        var expr = Context.makeExpr(data, Context.currentPos());

        fields.push({
            pos: Context.currentPos(),
            name: 'info',
            kind: FVar(null, expr),
            access: [APublic],
            doc: 'App info extracted from `ceramic.yml`',
            meta: []
        });

        return fields;

    } //build

    static function computeInfo(rawInfo:String):Dynamic {

        var data:Dynamic = {};

        if (rawInfo != null) {
            // AppMacro.rawInfo can be null when running stuff like "go to definition" from compiler
            data = convertArrays(Json.parse(Json.parse(rawInfo)));
        }

        // Add required info
        if (data.collections == null) data.collections = {};
        if (data.editable == null) data.editable = [];

        // Load editable types from ceramic.yml
        for (key in Reflect.fields(data.editable)) {
            var val = Reflect.field(data.editable, key);
            if (Std.is(val, String)) {
                Context.getType(val);
            }
            else {
                for (k in Reflect.fields(val)) {
                    var v = Reflect.field(val, k);
                    Context.getType(v);
                }
            }
        }

        // Load collection types from ceramic.yml
        for (key in Reflect.fields(data.collections)) {
            var val = Reflect.field(data.collections, key);
            if (Std.is(val, String)) {
                Context.getType(val);
            }
            else {
                for (k in Reflect.fields(val)) {
                    var v = Reflect.field(val, k);
                    Context.getType(v);
                }
            }
        }

        return data;

    } //computeInfo

    static function convertArrays(data:Dynamic):Dynamic {

        var newData:Dynamic = {};

        for (key in Reflect.fields(data)) {

            var val = Reflect.field(data, key);
            
            if (Std.is(val, Array)) {
                var items:Dynamic = {};
                var list:Array<Dynamic> = val;
                var i = 0;
                for (item in list) {
                    Reflect.setField(items, 'item$i', item);
                    i++;
                }
                Reflect.setField(newData, key, items);
            }
            else if (val == null || Std.is(val, String) || Std.is(val, Int) || Std.is(val, Float) || Std.is(val, Bool)) {
                Reflect.setField(newData, key, val);
            }
            else {
                Reflect.setField(newData, key, convertArrays(val));
            }

        }

        return newData;

    } //convertArrays

} //AppMacro
