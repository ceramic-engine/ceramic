package ceramic.macros;

import ceramic.Path;
import ceramic.macros.AssetsMacro;
import ceramic.macros.MacroCache;
import haxe.Json;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * Build macro for generating compile-time constants for Spine assets and their animations.
 *
 * This macro scans Spine JSON files in the assets directory and creates typed constants
 * for each Spine asset and its animations. This provides compile-time safety and
 * auto-completion when referencing Spine animations in code.
 *
 * ## Generated Structure
 *
 * For each Spine asset, generates:
 * - A constant for the asset itself
 * - Nested constants for each animation within the asset
 *
 * ## Usage Example
 *
 * ```haxe
 * // Assuming you have a Spine asset at assets/spine/hero/hero.json
 * // with animations "walk", "run", and "jump"
 *
 * var spine = new Spine();
 * spine.spineData = assets.spine(Spines.HERO);
 * spine.animation = Spines.HERO.WALK;
 * ```
 *
 * @see Spine
 * @see SpineAsset
 */
class SpineMacros {

    /**
     * Build macro that generates compile-time constants for Spine assets and animations.
     *
     * This macro:
     * 1. Scans the assets directory for Spine folders
     * 2. Reads each Spine JSON file to extract animation names
     * 3. Generates typed constants for assets and their animations
     * 4. Caches the results to improve compilation performance
     *
     * The generated constants follow the naming convention:
     * - Asset constants use UPPER_CASE names
     * - Animation constants are nested within their asset constant
     *
     * @return Array of generated field definitions with Spine constants
     */
    macro static public function buildNames():Array<Field> {

        var cacheKey = Context.getLocalClass().toString() + '#SpineMacros.buildNames()';
        var cacheData:Map<String,{animations:Array<{name:String,constName:String}>}> = MacroCache.get(cacheKey);

        var fields = Context.getBuildFields();
        var pos = Context.currentPos();
        var assetsPath = DefinesMacro.jsonDefinedValue('assets_path');
        var ceramicPluginsAssetsPathsRaw = Context.definedValue('ceramic_extra_assets_paths');
        var ceramicPluginsAssetsPaths:Array<String> = [];
        if (ceramicPluginsAssetsPathsRaw != null) {
            ceramicPluginsAssetsPaths = Json.parse(Json.parse(ceramicPluginsAssetsPathsRaw));
        }
        var ceramicAssetsPath = DefinesMacro.jsonDefinedValue('ceramic_assets_path');

        AssetsMacro.initData(assetsPath, ceramicPluginsAssetsPathsRaw, ceramicAssetsPath);
        var nameFields = AssetsMacro.computeNames(fields, pos, 'spine', ['spine'], true);

        // Compute cached data
        if (cacheData == null) {
            cacheData = new Map();
            for (field in nameFields) {

                var spineDir = field.doc;
                var hasFile = false;
                if (FileSystem.exists(Path.join([assetsPath, spineDir]))) {
                    spineDir = Path.join([assetsPath, spineDir]);
                    hasFile = true;
                }
                else {
                    for (pluginAssetsPath in ceramicPluginsAssetsPaths) {
                        if (FileSystem.exists(Path.join([pluginAssetsPath, spineDir]))) {
                            spineDir = Path.join([pluginAssetsPath, spineDir]);
                            hasFile = true;
                            break;
                        }
                    }

                    if (!hasFile && FileSystem.exists(Path.join([ceramicAssetsPath, spineDir]))) {
                        spineDir = Path.join([ceramicAssetsPath, spineDir]);
                        hasFile = true;
                    }
                }

                if (!hasFile) {
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

    }

}