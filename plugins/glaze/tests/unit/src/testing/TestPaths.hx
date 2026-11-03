package testing;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Paths of the unit test project, resolved at compile time.
 */
class TestPaths {

    /**
     * `test/unit/out` (the build output folder of the unit tests), absolute:
     * tests that write files put them there.
     */
    macro public static function unitOutDir():Expr {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('testing/TestPaths.hx')));
        return macro $v{haxe.io.Path.normalize(haxe.io.Path.join([dir, '..', '..', 'out']))};
    }

}
