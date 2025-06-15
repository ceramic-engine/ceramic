package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

class AudioFiltersMacro {

    #if (macro && web)
    static var filterReferences:Array<{
        pack: Array<String>,
        name: String,
        filePath: String,
        hash: String,
        min: Int,
        max: Int
    }> = [];
    static var workletReferences:Array<{
        pack: Array<String>,
        name: String,
        filePath: String,
        hash: String,
        min: Int,
        max: Int
    }> = [];
    static var fileHashes:Map<String,String> = new Map();

    static function getHash(filePath:String):String {
        var hash = fileHashes.get(filePath);
        if (hash == null) {
            hash = haxe.crypto.Md5.encode(sys.io.File.getContent(filePath));
            fileHashes.set(filePath, hash);
        }
        return hash;
    }
    #end

    public static function init():Void {

        #if web
        var isCompletion = Context.defined('completion');
        if (!isCompletion) {
            Context.onAfterGenerate(function() {
                var targetPath = DefinesMacro.jsonDefinedValue('target_path');
                if (targetPath != null) {
                    filterReferences.sort(function(a, b) {
                        if (a.filePath < b.filePath) return -1;
                        if (a.filePath > b.filePath) return 1;
                        if (a.hash < b.hash) return -1;
                        if (a.hash > b.hash) return 1;
                        return 0;
                    });
                    workletReferences.sort(function(a, b) {
                        if (a.filePath < b.filePath) return -1;
                        if (a.filePath > b.filePath) return 1;
                        if (a.hash < b.hash) return -1;
                        if (a.hash > b.hash) return 1;
                        return 0;
                    });
                    if (!sys.FileSystem.exists(haxe.io.Path.join([targetPath, 'audio-filters']))) {
                        sys.FileSystem.createDirectory(haxe.io.Path.join([targetPath, 'audio-filters']));
                    }
                    sys.io.File.saveContent(haxe.io.Path.join([targetPath, 'audio-filters', 'info.json']), haxe.Json.stringify({
                        filters: filterReferences,
                        worklets: workletReferences
                    }));
                }
            });
        }
        #end

    }

    macro static public function buildFilter():Array<Field> {

        #if (web && ceramic_build_audio_worklets)
        return [];
        #elseif web
        final classRef = Context.getLocalClass().get();
        final classPos = Context.getPosInfos(classRef.pos);
        final filePath = Path.join([Sys.getCwd(), Context.getPosInfos(Context.currentPos()).file]);
        filterReferences.push({
            pack: [].concat(classRef.pack ?? []),
            name: classRef.name,
            filePath: filePath,
            hash: getHash(filePath),
            min: classPos.min,
            max: classPos.max
        });
        return Context.getBuildFields();
        #else
        return Context.getBuildFields();
        #end

    }

    macro static public function buildWorklet():Array<Field> {

        #if (web && ceramic_build_audio_worklets)
        return Context.getBuildFields();
        #elseif web
        var fields:Array<Field> = [];
        for (field in Context.getBuildFields()) {
            if (field.name == 'process') {
                fields.push({
                    name: field.name,
                    meta: field.meta,
                    pos: field.pos,
                    kind: switch field.kind {
                        case FFun(f):
                            FFun({
                                args: f.args,
                                params: f.params,
                                expr: macro {},
                                ret: null
                            });
                        case _: field.kind;
                    },
                    access: field.access
                });
            }
        }
        final classRef = Context.getLocalClass().get();
        final classPos = Context.getPosInfos(classRef.pos);
        final filePath = Path.join([Sys.getCwd(), Context.getPosInfos(Context.currentPos()).file]);
        workletReferences.push({
            pack: [].concat(classRef.pack ?? []),
            name: classRef.name,
            filePath: filePath,
            hash: getHash(filePath),
            min: classPos.min,
            max: classPos.max
        });
        return fields;
        #else
        return Context.getBuildFields();
        #end

    }

}