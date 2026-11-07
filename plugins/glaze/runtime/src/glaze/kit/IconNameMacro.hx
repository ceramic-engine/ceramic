// Ported from gpui-kit 0.8.1: crates/assets/build.rs (generation of IconName from the bundled SVG files)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from a Rust build script to a Haxe build macro for Ceramic. See NOTICE.md.
package gpui.component;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
#end

/**
 * Generates the variants of `IconName` from the SVG files of the plugin's
 * `assets/icons` directory, like gpui-kit's `crates/assets/build.rs`:
 * `arrow-down.svg` becomes `ArrowDown = "icons/arrow-down.svg"`, in
 * variant-name order, plus `ALL` (every variant).
 */
class IconNameMacro {

    #if macro
    public static function build():Array<Field> {
        final fields = Context.getBuildFields();
        final pos = Context.currentPos();

        // runtime/src/gpui/component -> plugin root
        final here = haxe.io.Path.directory(FileSystem.absolutePath(Context.getPosInfos(pos).file));
        final dir = haxe.io.Path.normalize(here + '/../../../../assets/icons');
        if (!FileSystem.exists(dir)) {
            Context.error('Missing icon directory: $dir', pos);
        }
        Context.registerModuleDependency(Context.getLocalModule(), dir);

        final icons:Array<{variant:String, path:String}> = [];
        final seen = new Map<String, Bool>();
        for (file in FileSystem.readDirectory(dir)) {
            if (!StringTools.endsWith(file, '.svg'))
                continue;
            final stem = file.substr(0, file.length - 4);
            var variant = '';
            for (part in ~/[-_.]/g.split(stem)) {
                if (part.length == 0)
                    continue;
                variant += part.charAt(0).toUpperCase() + part.substr(1).toLowerCase();
            }
            if (!~/^[A-Za-z][A-Za-z0-9]*$/.match(variant)) {
                Context.error('invalid icon name: $stem', pos);
            }
            if (seen.exists(variant)) {
                Context.error('duplicate icon variant: $stem', pos);
            }
            seen.set(variant, true);
            icons.push({variant: variant, path: 'icons/$file'});
        }
        // Rust sorts the variants in a BTreeMap (byte order)
        icons.sort((a, b) -> a.variant < b.variant ? -1 : (a.variant > b.variant ? 1 : 0));

        for (icon in icons) {
            fields.push({
                name: icon.variant,
                access: [APublic, AStatic, AInline],
                kind: FVar(macro :gpui.component.IconName, macro cast $v{icon.path}),
                pos: pos
            });
        }

        final allExprs:Array<Expr> = [for (icon in icons) macro $i{icon.variant}];
        fields.push({
            name: 'ALL',
            doc: 'Every bundled icon in variant-name order.',
            access: [APublic, AStatic, AFinal],
            kind: FVar(macro :Array<gpui.component.IconName>, macro $a{allExprs}),
            pos: pos
        });

        return fields;
    }
    #end

}
