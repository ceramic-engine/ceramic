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
 * Build macro that generates compile-time constants for tilemap asset names.
 * This macro scans the project's assets directory for tilemap files and creates
 * static string constants for each one, enabling type-safe asset references.
 *
 * The macro looks for:
 * - TMX files (Tiled Map Editor format)
 * - LDTK files (LDtk level editor format, when plugin_ldtk is enabled)
 *
 * ## Generated Constants
 *
 * ## Usage Example:
 * ```haxe
 * // Although you can reference plain strings:
 * assets.tilemap("open-world/level_1");
 *
 * // This macro allows you to use compile-time checked constants instead:
 * assets.tilemap(Tilemaps.OPEN_WORLD__LEVEL_1);
 * ```
 *
 * The constants follow the naming pattern:
 * - Path separators become underscores
 * - All uppercase
 * - Prefixed with asset type
 *
 * @see AssetsMacro The base macro for asset name generation
 * @see TilemapAsset For tilemap asset loading
 */
class TilemapMacros {

    /**
     * Build macro that generates static constants for all tilemap assets.
     * Called at compile-time when building the Tilemaps class.
     *
     * The macro:
     * 1. Scans configured asset directories for tilemap files
     * 2. Generates a static inline constant for each tilemap
     * 3. Adds the constants to the class being built
     *
     * Supported file extensions:
     * - .tmx (Tiled Map Editor)
     * - .ldtk (LDtk editor, when plugin_ldtk is enabled)
     *
     * @return Array of generated field definitions to add to the class
     */
    macro static public function buildNames():Array<Field> {

        var fields = Context.getBuildFields();
        var pos = Context.currentPos();
        var assetsPath = DefinesMacro.jsonDefinedValue('assets_path');
        var ceramicPluginsAssetsPathsRaw = Context.definedValue('ceramic_extra_assets_paths');
        var ceramicAssetsPath = DefinesMacro.jsonDefinedValue('ceramic_assets_path');

        AssetsMacro.initData(assetsPath, ceramicPluginsAssetsPathsRaw, ceramicAssetsPath);

        // Compute name fields for tilemap assets
        // Includes .tmx files by default, and .ldtk files when the LDtk plugin is enabled
        var nameFields = AssetsMacro.computeNames(fields, pos, 'tilemap', ['tmx' #if plugin_ldtk , 'ldtk' #end]);

        for (field in nameFields) {
            fields.push(field);
        }

        return fields;

    }

}
