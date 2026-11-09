package testing;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Embeds, at compile time, data files of the bench as string literals.
 */
class BenchData {

    /**
     * The bench project's folder (`tests/bench`).
     */
    macro public static function benchDir():Expr {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('testing/BenchData.hx')));
        return macro $v{haxe.io.Path.normalize(haxe.io.Path.join([dir, '..', '..']))};
    }

    /**
     * A file of the unit tests' data folder (`tests/unit/data/<path>`).
     */
    macro public static function load(path:String):Expr {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('testing/BenchData.hx')));
        return embed(haxe.io.Path.join([dir, '..', '..', '..', 'unit', 'data', path]));
    }

    /**
     * A file of the bench's data folder (`tests/bench/data/<path>`).
     */
    macro public static function loadBench(path:String):Expr {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('testing/BenchData.hx')));
        return embed(haxe.io.Path.join([dir, '..', '..', 'data', path]));
    }

    /**
     * A TextMate grammar bundled with Glaze (`plugins/glaze/assets/glaze/grammars/<file>`).
     */
    macro public static function loadGlazeGrammar(file:String):Expr {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('testing/BenchData.hx')));
        return embed(haxe.io.Path.join([dir, '..', '..', '..', '..', '..', 'glaze', 'assets', 'glaze', 'grammars', file]));
    }

    #if macro
    static function embed(path:String):Expr {
        final full = haxe.io.Path.normalize(path);
        if (!sys.FileSystem.exists(full)) {
            Context.error('Missing bench data: $full', Context.currentPos());
        }
        Context.registerModuleDependency(Context.getLocalModule(), full);
        return macro $v{sys.io.File.getContent(full)};
    }
    #end

}
