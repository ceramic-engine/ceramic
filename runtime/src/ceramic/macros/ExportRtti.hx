package ceramic.macros;

#if macro

import haxe.Json;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.crypto.Md5;
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.TypedExprTools;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * Exports Runtime Type Information (RTTI) for classes marked with @:rtti metadata.
 * RTTI allows runtime introspection of class structure, including fields, methods,
 * and their types. This is essential for features like serialization, debugging tools,
 * and dynamic type inspection.
 * 
 * The macro:
 * - Identifies all classes with @:rtti metadata
 * - Includes subclasses of @:rtti classes automatically
 * - Extracts RTTI XML data from compiled classes
 * - Saves RTTI files with MD5-hashed names for cache invalidation
 * 
 * RTTI files are stored in the .cache/rtti directory and can be loaded
 * at runtime for reflection purposes.
 */
class ExportRtti {

    /**
     * Initializes the RTTI export process.
     * Called during compilation to extract and save RTTI data for marked classes.
     * The process runs in two phases:
     * 1. onGenerate: Identifies which types need RTTI exported
     * 2. onAfterGenerate: Extracts and saves the actual RTTI data
     */
    public static function init():Void {

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> BEGIN ExportRtti.init()');
        #end

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

        #if ceramic_debug_macro
        trace(Context.getLocalClass() + ' -> END ExportRtti.build()');
        #end

    }

/// Internal

    /**
     * Determines the path for storing RTTI files.
     * Creates a .cache/rtti directory in the target output path.
     * 
     * @return Path to RTTI directory or null if target path not defined
     */
    static function getRttiPath():String {

        var targetPath = DefinesMacro.jsonDefinedValue('target_path');

        if (targetPath == null) {
            return null;
        }

        var cacheDir = Path.join([targetPath, '.cache']);
        if (!FileSystem.exists(cacheDir)) {
            FileSystem.createDirectory(cacheDir);
        }
        var name = 'rtti';
        return Path.join([cacheDir, name]);

    }

    /**
     * Recursively deletes a file or directory and all its contents.
     * Used to clean up previous RTTI exports before generating new ones.
     * 
     * @param toDelete Path to file or directory to delete
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
