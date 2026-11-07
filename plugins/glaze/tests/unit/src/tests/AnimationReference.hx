package tests;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Embeds the values dumped from the original GPUI by
 * `reference/examples/animation_dump.rs` (tests/unit/data/gpui-animation-reference.json).
 * Regenerate with, from `reference/`:
 * `cargo run --release --example animation_dump -- ../../ceramic/plugins/glaze/tests/unit/data/gpui-animation-reference.json`
 */
class AnimationReference {

    static var cached:Dynamic = null;

    public static function data():Dynamic {
        if (cached == null) {
            cached = haxe.Json.parse(content());
        }
        return cached;
    }

    static macro function content():Expr {
        final file = Context.getPosInfos(Context.currentPos()).file;
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(file));
        final path = haxe.io.Path.normalize(dir + '/../../data/gpui-animation-reference.json');
        Context.registerModuleDependency('tests.AnimationReference', path);
        return macro $v{sys.io.File.getContent(path)};
    }

}
