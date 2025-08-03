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
 * Build macros for generating compile-time constants for Loreline assets.
 * 
 * This macro scans the assets directory for Loreline files and generates
 * static constants in the Loreines class for type-safe asset references.
 * 
 * The generated constants allow referencing assets like:
 * ```haxe
 * assets.add(Loreines.STORY_INTRO);
 * ```
 * Instead of using string literals.
 */
class LorelineMacros {

    /**
     * Build macro that generates asset name constants for Loreline files.
     * Scans for .lor and .loreline files in the assets directories and
     * creates corresponding static constants.
     * @return Array of generated fields to add to the class
     */
    macro static public function buildNames():Array<Field> {

        var fields = Context.getBuildFields();
        var pos = Context.currentPos();
        var assetsPath = DefinesMacro.jsonDefinedValue('assets_path');
        var ceramicPluginsAssetsPathsRaw = Context.definedValue('ceramic_extra_assets_paths');
        var ceramicAssetsPath = DefinesMacro.jsonDefinedValue('ceramic_assets_path');

        AssetsMacro.initData(assetsPath, ceramicPluginsAssetsPathsRaw, ceramicAssetsPath);

        var nameFields = AssetsMacro.computeNames(fields, pos, 'loreline', ['lor', 'loreline']);

        for (field in nameFields) {
            fields.push(field);
        }

        return fields;

    }

}
