// New code for the Haxe port of gpui-kit 0.8.1: the sources read by the test
// `every_base_dock_export_is_reachable_from_here` of crates/component/src/dock/mod.rs
// (`include_str!`), embedded at compile time. See NOTICE.md.
package tests.kit;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * gpui-kit's two dock `mod.rs` files, like the Rust test's `include_str!`,
 * and the names the Haxe component dock re-exports from base (its
 * `typedef X = glaze.kit.base.dock...` modules), sorted.
 */
class ComponentDockExports {

    public static macro function baseModRs():Expr {
        return macro $v{read('data/gpui-kit/crates/base/src/dock/mod.rs')};
    }

    public static macro function componentModRs():Expr {
        return macro $v{read('data/gpui-kit/crates/component/src/dock/mod.rs')};
    }

    public static macro function haxeReexports():Expr {
        final dir = unit() + '/../../runtime/src/glaze/kit/dock';
        final names:Array<String> = [];
        final pattern = ~/^typedef ([A-Za-z]+) = glaze\.kit\.base\.dock\./m;
        for (file in sys.FileSystem.readDirectory(dir)) {
            if (!StringTools.endsWith(file, '.hx')) continue;
            final path = dir + '/' + file;
            Context.registerModuleDependency('tests.kit.ComponentDockExports', path);
            if (pattern.match(sys.io.File.getContent(path))) names.push(pattern.matched(1));
        }
        names.sort(Reflect.compare);
        return macro $v{names};
    }

    #if macro
    /** The tests/unit folder (the gpui-kit sources are copied in its data/gpui-kit). */
    static function unit():String {
        final file = Context.getPosInfos(Context.currentPos()).file;
        return haxe.io.Path.normalize(haxe.io.Path.directory(sys.FileSystem.absolutePath(file)) + '/../../..');
    }

    static function read(relative:String):String {
        final path = unit() + '/' + relative;
        Context.registerModuleDependency('tests.kit.ComponentDockExports', path);
        return sys.io.File.getContent(path);
    }
    #end

}
