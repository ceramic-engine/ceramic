// Ported from gpui-kit 0.8.1: crates/assets/build.rs (generation of IconName from the bundled SVG files)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from a Rust build script to a Haxe build macro for Ceramic. See NOTICE.md.
package glaze.kit;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
#end

/**
 * Generates the variants of `IconName` from the SVG files of the plugin's
 * `resources/icons` directory: `arrow-down.svg` becomes
 * `ArrowDown = "icons/arrow-down.svg"`, in variant-name order, plus `ALL`
 * (every variant).
 *
 * The SVG files of the project's icon directories are added the same way:
 * `resources/glaze/icons`, then the directories listed in `glaze.icons` of
 * its `ceramic.yml` (given by the glaze tools plugin in the
 * `glaze_icons_paths` define). A file with the name of an icon already
 * added replaces it.
 *
 * The content of every SVG file is embedded in the code (`embeddedSvgs()`,
 * in the order of `ALL`), and added to the asset source of the app when the
 * kit initializes: icons draw at once on every target, nothing to preload.
 */
class IconNameMacro {

    #if macro
    public static function build():Array<Field> {
        final fields = Context.getBuildFields();
        final pos = Context.currentPos();

        // runtime/src/glaze/kit -> plugin root
        final here = haxe.io.Path.directory(FileSystem.absolutePath(Context.getPosInfos(pos).file));
        final pluginDir = haxe.io.Path.normalize(here + '/../../../../resources/icons');
        if (!FileSystem.exists(pluginDir)) {
            Context.error('Missing icon directory: $pluginDir', pos);
        }

        // Icon file path (`icons/<file>`) -> file on disk, the project's last
        final files = new Map<String, String>();
        addDirectory(pluginDir, files);
        final projectPaths:Null<String> = ceramic.macros.DefinesMacro.jsonDefinedValue('glaze_icons_paths');
        if (projectPaths != null) {
            final dirs:Array<String> = haxe.Json.parse(projectPaths);
            for (dir in dirs) {
                if (FileSystem.exists(dir) && FileSystem.isDirectory(dir))
                    addDirectory(dir, files);
            }
        }

        final icons:Array<{variant:String, path:String, file:String}> = [];
        final seen = new Map<String, String>();
        for (path => file in files) {
            final stem = haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(path));
            var variant = '';
            for (part in ~/[-_.]/g.split(stem)) {
                if (part.length == 0)
                    continue;
                variant += part.charAt(0).toUpperCase() + part.substr(1).toLowerCase();
            }
            if (!~/^[A-Za-z][A-Za-z0-9]*$/.match(variant)) {
                Context.error('invalid icon name: $file', pos);
            }
            if (seen.exists(variant)) {
                Context.error('duplicate icon variant $variant: $file and ${seen.get(variant)}', pos);
            }
            seen.set(variant, file);
            icons.push({variant: variant, path: path, file: file});
        }
        // Rust sorts the variants in a BTreeMap (byte order)
        icons.sort((a, b) -> a.variant < b.variant ? -1 : (a.variant > b.variant ? 1 : 0));

        for (icon in icons) {
            fields.push({
                name: icon.variant,
                access: [APublic, AStatic, AInline],
                kind: FVar(macro :glaze.kit.IconName, macro cast $v{icon.path}),
                pos: pos
            });
        }

        final allExprs:Array<Expr> = [for (icon in icons) macro $i{icon.variant}];
        fields.push({
            name: 'ALL',
            doc: 'Every icon (bundled and project icons) in variant-name order.',
            access: [APublic, AStatic, AFinal],
            kind: FVar(macro :Array<glaze.kit.IconName>, macro $a{allExprs}),
            pos: pos
        });

        final svgExprs:Array<Expr> = [];
        for (icon in icons) {
            Context.registerModuleDependency(Context.getLocalModule(), icon.file);
            final bytes = sys.io.File.getBytes(icon.file);
            if (!UnicodeString.validate(bytes, haxe.io.Encoding.UTF8)) {
                Context.error('icon is not UTF-8 text: ${icon.file}', pos);
            }
            svgExprs.push(macro $v{bytes.toString()});
        }
        fields.push({
            name: 'embeddedSvgs',
            doc: 'The content of every icon of `ALL`, in the same order (embedded at compile time).',
            meta: [{name: ':noCompletion', pos: pos}],
            access: [APublic, AStatic],
            kind: FFun({args: [], ret: macro :Array<String>, expr: macro return $a{svgExprs}}),
            pos: pos
        });

        return fields;
    }

    /**
     * Adds the SVG files of `dir` to `files`, and makes the module depend on
     * the directory (a file added or removed rebuilds it).
     */
    static function addDirectory(dir:String, files:Map<String, String>):Void {
        Context.registerModuleDependency(Context.getLocalModule(), dir);
        for (file in FileSystem.readDirectory(dir)) {
            if (StringTools.endsWith(file, '.svg'))
                files.set('icons/$file', haxe.io.Path.join([dir, file]));
        }
    }
    #end

}
