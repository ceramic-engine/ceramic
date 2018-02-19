package plugin.spine.macros;

import ceramic.macros.AssetsMacro;
import ceramic.macros.MacroCache;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.io.Path;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;

using StringTools;

class SpineMacros {

    macro static public function buildNames():Array<Field> {

        var cacheKey = Context.getLocalClass().toString() + '#SpineMacros.buildNames()';
        var cacheData:Map<String,{animations:Array<{name:String,constName:String}>}> = MacroCache.get(cacheKey);

        var fields = Context.getBuildFields();
        var pos = Context.currentPos();
        var assetsPath = Context.definedValue('assets_path');
        var ceramicAssetsPath = Context.definedValue('ceramic_assets_path');

        AssetsMacro.initData(assetsPath, ceramicAssetsPath);
        var nameFields = AssetsMacro.computeNames(fields, pos, 'spine', ['spine'], true);

        // Compute cached data
        if (cacheData == null) {
            cacheData = new Map();
            for (field in nameFields) {
            
                var spineDir = field.doc;
                if (FileSystem.exists(Path.join([assetsPath, spineDir]))) {
                    spineDir = Path.join([assetsPath, spineDir]);
                }
                else if (FileSystem.exists(Path.join([ceramicAssetsPath, spineDir]))) {
                    spineDir = Path.join([ceramicAssetsPath, spineDir]);
                }
                else {
                    continue;
                }

                var jsonPath = null;
                for (file in FileSystem.readDirectory(spineDir)) {
                    if (file.toLowerCase().endsWith('.json')) {
                        jsonPath = Path.join([spineDir, file]);
                        break;
                    }
                }

                if (jsonPath == null) {
                    continue;
                }

                var info = {
                    animations: []
                };

                var jsonData = Json.parse(File.getContent(jsonPath));
                var animations = Reflect.fields(jsonData.animations);

                var entries = [];
                for (animName in animations) {
                    var constName = AssetsMacro.toAssetConstName(animName);
                    if (!constName.startsWith('_')) {
                        info.animations.push({
                            name: animName,
                            constName: constName
                        });
                    }
                }

                cacheData.set(field.name, info);
            }
        }

        // Assets by base name
        //
        var idsEntries = [];

        // We let assets macro do default work but want to extend
        // informations to available animations inside each spine export
        for (field in nameFields) {

            var info = cacheData.get(field.name);

            if (info == null) {
                fields.push(field);
                continue;
            }

            var entries = [];
            for (animInfo in info.animations) {
                entries.push({
                    expr: {
                        expr: EConst(CString(animInfo.name)),
                        pos: pos
                    },
                    field: animInfo.constName
                });
            }

            switch(field.kind) {
                case FProp(_, _, _, expr):
                    idsEntries.push({expr: EBinop(OpArrow, {expr: EConst(CString(field.name)), pos: pos}, expr), pos: pos});
                default:
            }

            field.kind = FProp('default', 'null', null, { expr: EObjectDecl(entries), pos: pos });

            fields.push(field);

        }

        var idsExpr = idsEntries.length == 0 ? (macro new Map()) : {expr: EArrayDecl(idsEntries), pos: pos};
        var idsField = {
            pos: pos,
            name: '_ids',
            kind: FProp('default', 'null', macro :Map<String,String>, idsExpr),
            access: [AStatic, APrivate],
            doc: '',
            meta: [{
                name: ':noCompletion',
                params: [],
                pos: pos
            }]
        };
        fields.push(idsField);

        MacroCache.set(cacheKey, cacheData);

        return fields;

    } //buildNames

}