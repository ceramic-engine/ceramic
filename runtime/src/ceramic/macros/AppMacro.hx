package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;

using StringTools;

class AppMacro {

    static var rawInfo:String;

    static public function setInfo(rawInfo:String):Void {

        AppMacro.rawInfo = rawInfo;

    } //setInfo

    macro static public function build():Array<Field> {

        var fields = Context.getBuildFields();

        var data:Dynamic = convertArrays(Json.parse(AppMacro.rawInfo));
        var expr = Context.makeExpr(data, Context.currentPos());

         // Load collection types from ceramic.yml
        if (data.collections != null) {
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
        }

         // Load editable types from ceramic.yml
        if (data.editable != null) {
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
        }

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
