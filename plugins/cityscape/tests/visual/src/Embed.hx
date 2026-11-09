// New code for Cityscape (not a port): embeds the test data files of the
// visual check at compile time (the same files on every target).
package;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

class Embed {

    /**
     * The content of a file, its path relative to the calling source file.
     */
    public static macro function file(path:String):ExprOf<String> {
        final caller = Context.getPosInfos(Context.currentPos()).file;
        final full = sys.FileSystem.absolutePath(haxe.io.Path.join([haxe.io.Path.directory(caller), path]));
        Context.registerModuleDependency(Context.getLocalModule(), full);
        return macro $v{sys.io.File.getContent(full)};
    }

}
