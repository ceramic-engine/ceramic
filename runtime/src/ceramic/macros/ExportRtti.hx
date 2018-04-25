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
class ExportRtti {

    public static function init():Void {

        var isCompletion = Context.defined('completion') || Context.defined('display');
        if (isCompletion) return;

        var rttiPath = getRttiPath();
        if (rttiPath == null) {
            return;
        }

        if (FileSystem.exists(rttiPath)) {
            deleteRecursive(rttiPath);
        }
        FileSystem.createDirectory(rttiPath);

        var rttiTypes:Map<String,Bool> = new Map();

        Context.onGenerate(function(types) {

            // Compute rtti roots
            //
            var rttiRoots:Map<String,Bool> = new Map();

            for (type in types) {
                switch (type) {
                    case TInst(t, params):
                        if (t.get().meta.has(':rtti')) {
                            rttiRoots.set(t.toString(), true);
                        }
                    default:
                }
            }

            // Compute any class that has a rtti root as superclass

            for (type in types) {
                switch (type) {
                    case TInst(t, params):
                        var tGet = t.get();
                        var typeName = t.toString();
                        if (tGet.meta.has(':rtti')) {
                            rttiTypes.set(typeName, true);
                        }
                        else {
                            while (tGet.superClass != null) {
                                var superTypeName = tGet.superClass.t.toString();
                                if (rttiRoots.exists(superTypeName)) {
                                    rttiTypes.set(typeName, true);
                                    break;
                                }
                                tGet = tGet.superClass.t.get();
                            }
                        }
                    default:
                }
            }

        });

        Context.onAfterGenerate(function() {
            
            for (typeName in rttiTypes.keys()) {
                var type = Context.getType(typeName);
                if (type != null) {
                    switch (type) {
                        case TInst(t, params):
                            if (t.get().name != 'Context') {
                                for (field in t.get().statics.get()) {
                                    if (field.name == '__rtti') {
                                        var rtti = TypedExprTools.toString(field.expr());
                                        rtti = Json.parse(rtti.substr('[Const:String] '.length));
                                        
                                        // Save result
                                        var xmlPath = Path.join([rttiPath, Md5.encode(typeName + '.xml')]);
                                        File.saveContent(xmlPath, rtti);
                                    }
                                }
                            }
                        default:
                    }
                }
            }

        });

    } //init

/// Internal

    static function getRttiPath():String {

        var targetPath = Context.definedValue('target_path');

        if (targetPath == null) {
            return null;
        }

        var cacheDir = Path.join([targetPath, '.cache']);
        if (!FileSystem.exists(cacheDir)) {
            FileSystem.createDirectory(cacheDir);
        }
        var name = 'rtti';
        return Path.join([cacheDir, name]);

    } //getRttiPath

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

    } //deleteRecursive

} //ExportRtti

#end
