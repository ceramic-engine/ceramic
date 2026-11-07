package testing;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Embeds, at compile time, data produced by the original GPUI through the
 * reference harness (copies of the golden truths `test/golden/gpui/*.json`
 * of glaze-golden, in `tests/unit/data/golden`), so unit tests can compare
 * the port with it.
 */
class GlazeTruth {

    /**
     * Returns the content of `tests/unit/data/golden/<name>` as a string literal.
     */
    macro public static function load(name:String):Expr {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('testing/GlazeTruth.hx')));
        final path = haxe.io.Path.normalize(haxe.io.Path.join([dir, '..', '..', 'data', 'golden', name]));
        if (!sys.FileSystem.exists(path)) {
            Context.error('Missing GPUI reference data: $path (run the reference harness)', Context.currentPos());
        }
        Context.registerModuleDependency(Context.getLocalModule(), path);
        return macro $v{sys.io.File.getContent(path)};
    }

}
