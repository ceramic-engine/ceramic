package ceramic.macros;

import ceramic.macros.AssetsMacro;
import ceramic.macros.MacroCache;

import haxe.macro.Context;
import haxe.macro.Expr;
import ceramic.Path;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;

using StringTools;

class TilemapMacros {

    macro static public function buildNames():Array<Field> {

        var fields = Context.getBuildFields();
        var pos = Context.currentPos();
        var assetsPath = Context.definedValue('assets_path');
        var ceramicPluginsAssetsPathsRaw = Context.definedValue('ceramic_plugins_assets_paths');
        var ceramicAssetsPath = Context.definedValue('ceramic_assets_path');

        AssetsMacro.initData(assetsPath, ceramicPluginsAssetsPathsRaw, ceramicAssetsPath);

        var nameFields = AssetsMacro.computeNames(fields, pos, 'tilemap', ['tmx']);

        for (field in nameFields) {
            fields.push(field);
        }

        return fields;

    } //buildNames

} //TilemapMacros
