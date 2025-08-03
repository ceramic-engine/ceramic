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
 * Build macro for generating sprite asset name constants.
 * Creates compile-time constants for all sprite assets found in the project.
 * 
 * This macro scans for files with sprite extensions (.sprite, .ase, .aseprite)
 * and generates string constants that can be used with the Assets API.
 * 
 * Example:
 * ```haxe
 * // If you have assets/character.sprite
 * assets.add(Sprites.CHARACTER); // Generated constant
 * ```
 */
class SpriteMacros {

    /**
     * Build sprite name constants from asset files.
     * Called by the build system to generate compile-time constants.
     * @return Array of generated fields to add to the type
     */
    macro static public function buildNames():Array<Field> {

        var fields = Context.getBuildFields();
        var pos = Context.currentPos();
        var assetsPath = DefinesMacro.jsonDefinedValue('assets_path');
        var ceramicPluginsAssetsPathsRaw = Context.definedValue('ceramic_extra_assets_paths');
        var ceramicAssetsPath = DefinesMacro.jsonDefinedValue('ceramic_assets_path');

        AssetsMacro.initData(assetsPath, ceramicPluginsAssetsPathsRaw, ceramicAssetsPath);

        // Generate name fields for sprite assets with supported extensions
        var nameFields = AssetsMacro.computeNames(fields, pos, 'sprite', ['sprite', 'ase', 'aseprite']);

        for (field in nameFields) {
            fields.push(field);
        }

        return fields;

    }

}
