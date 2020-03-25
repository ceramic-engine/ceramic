package ceramic.macros;

#if macro

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.TypedExprTools;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.io.Path;
import haxe.Json;
import haxe.crypto.Md5;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/** Export Runtime Type Information into external XML files. */
class ExportInfo {

    public static function init(infoPath:String):Void {

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> BEGIN ExportInfo.init()');
        #end

        var isCompletion = Context.defined('completion') || Context.defined('display');
        if (isCompletion) return;

        if (infoPath == null) {
            return;
        }

        if (FileSystem.exists(infoPath)) {
            deleteRecursive(infoPath);
        }
        FileSystem.createDirectory(infoPath);

        var infoTypes:Map<String,Bool> = new Map();

        Context.onGenerate(function(types) {

            // Compute info roots
            //
            var infoRoots:Map<String,Bool> = new Map();

            for (type in types) {
                switch (type) {
                    case TInst(t, params):
                        if (t.get().meta.has('info')) {
                            infoRoots.set(t.toString(), true);
                        }
                    default:
                }
            }

            /*
            // Compute any class that has a info root as superclass

            for (type in types) {
                switch (type) {
                    case TInst(t, params):
                        var tGet = t.get();
                        var typeName = t.toString();
                        if (tGet.meta.has('info')) {
                            infoTypes.set(typeName, true);
                        }
                        else {
                            while (tGet.superClass != null) {
                                var superTypeName = tGet.superClass.t.toString();
                                if (infoRoots.exists(superTypeName)) {
                                    infoTypes.set(typeName, true);
                                    break;
                                }
                                tGet = tGet.superClass.t.get();
                            }
                        }
                    default:
                }
            }
            */

        });

        Context.onAfterGenerate(function() {
            
            for (typeName in infoTypes.keys()) {
                var type = null;
                try {
                    type = Context.getType(typeName);
                }
                catch (e:Dynamic) {}
                if (type != null) {
                    switch (type) {
                        case TInst(t, params):
                            if (t.get().name != 'Context') {
                                for (field in t.get().statics.get()) {
                                    if (field.name == '__info') {
                                        var info = TypedExprTools.toString(field.expr());
                                        info = Json.parse(info.substr('[Const:String] '.length));
                                        
                                        // Save result
                                        var xmlPath = Path.join([infoPath, Md5.encode(typeName + '.xml')]);
                                        File.saveContent(xmlPath, info);
                                    }
                                }
                            }
                        default:
                    }
                }
            }

        });

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> END ExportInfo.init()');
        #end

    }

/// Internal

    /*
    static function getRttiPath():String {

        var targetPath = Context.definedValue('target_path');

        if (targetPath == null) {
            return null;
        }

        var cacheDir = Path.join([targetPath, '.cache']);
        if (!FileSystem.exists(cacheDir)) {
            FileSystem.createDirectory(cacheDir);
        }
        var name = 'info';
        return Path.join([cacheDir, name]);

    }
    */

    public static function deleteRecursive(toDelete:String):Void {

        if (FileSystem.isDirectory(toDelete)) {

            for (name in FileSystem.readDirectory(toDelete)) {

                var path = Path.join([toDelete, name]);
                if (FileSystem.isDirectory(path)) {
                    deleteRecursive(path);
                } else {
                    FileSystem.deleteFile(path);
                }
            }

            FileSystem.deleteDirectory(toDelete);

        }
        else {

            FileSystem.deleteFile(toDelete);

        }

    }

}

#end
