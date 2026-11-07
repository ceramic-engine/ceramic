package tests;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Embeds the values dumped from the original gpui-kit by
 * `reference/examples/theme_dump.rs` (tests/unit/data/gpui-kit-themes-reference.json),
 * and the theme files of `assets/themes/` (copied unmodified from gpui-kit's `themes/`).
 * Regenerate the reference with, from `reference/`:
 * `cargo run --release --example theme_dump -- ../../ceramic/plugins/glaze/tests/unit/data/gpui-kit-themes-reference.json`
 */
class ThemeReference {

    static var cached:Dynamic = null;

    public static function data():Dynamic {
        if (cached == null) {
            cached = haxe.Json.parse(content());
        }
        return cached;
    }

    static var cachedFiles:Null<Map<String, String>> = null;

    /**
     * The theme files, by file name.
     */
    public static function themeFiles():Map<String, String> {
        if (cachedFiles == null) {
            cachedFiles = new Map();
            final files:Dynamic = haxe.Json.parse(themeFilesJson());
            for (name in Reflect.fields(files)) {
                cachedFiles.set(name, Reflect.field(files, name));
            }
        }
        return cachedFiles;
    }

    static macro function content():Expr {
        final file = Context.getPosInfos(Context.currentPos()).file;
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(file));
        final path = haxe.io.Path.normalize(dir + '/../../data/gpui-kit-themes-reference.json');
        Context.registerModuleDependency('tests.ThemeReference', path);
        return macro $v{sys.io.File.getContent(path)};
    }

    static macro function themeFilesJson():Expr {
        final file = Context.getPosInfos(Context.currentPos()).file;
        final dir = haxe.io.Path.normalize(haxe.io.Path.directory(sys.FileSystem.absolutePath(file)) + '/../../../../assets/themes');
        final files:Dynamic = {};
        for (name in sys.FileSystem.readDirectory(dir)) {
            if (!StringTools.endsWith(name, '.json')) continue;
            final path = dir + '/' + name;
            Context.registerModuleDependency('tests.ThemeReference', path);
            Reflect.setField(files, name, sys.io.File.getContent(path));
        }
        return macro $v{haxe.Json.stringify(files)};
    }

}
