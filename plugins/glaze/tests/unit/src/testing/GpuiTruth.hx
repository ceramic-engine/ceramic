package testing;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Embeds, at compile time, data produced by the original GPUI through the
 * reference harness (`test/golden/gpui/*.json`), so unit tests can compare
 * the port with it.
 */
class GpuiTruth {

    /**
     * Returns the content of `test/golden/gpui/<name>` as a string literal.
     */
    macro public static function load(name:String):Expr {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('testing/GpuiTruth.hx')));
        final path = haxe.io.Path.normalize(haxe.io.Path.join([dir, '..', '..', '..', 'golden', 'gpui', name]));
        if (!sys.FileSystem.exists(path)) {
            Context.error('Missing GPUI reference data: $path (run the reference harness)', Context.currentPos());
        }
        Context.registerModuleDependency(Context.getLocalModule(), path);
        return macro $v{sys.io.File.getContent(path)};
    }

}
