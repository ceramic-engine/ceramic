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
 * `typedef X = gpui.base.dock...` modules), sorted.
 */
class ComponentDockExports {

    public static macro function baseModRs():Expr {
        return macro $v{read('gpui-kit/crates/base/src/dock/mod.rs')};
    }

    public static macro function componentModRs():Expr {
        return macro $v{read('gpui-kit/crates/component/src/dock/mod.rs')};
    }

    public static macro function haxeReexports():Expr {
        final dir = root() + '/runtime/src/gpui/component/dock';
        final names:Array<String> = [];
        final pattern = ~/^typedef ([A-Za-z]+) = gpui\.base\.dock\./m;
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
    static function root():String {
        final file = Context.getPosInfos(Context.currentPos()).file;
        // A scratch copy of test/unit has no repository around it: fall back
        // to the gpui plugin path it records.
        final local = haxe.io.Path.normalize(haxe.io.Path.directory(sys.FileSystem.absolutePath(file)) + '/../../../../..');
        if (sys.FileSystem.exists(local + '/gpui-kit')) return local;
        final plugin = haxe.io.Path.normalize(haxe.io.Path.directory(sys.FileSystem.absolutePath(file)) + '/../../../plugins/gpui.plugin');
        return StringTools.trim(sys.io.File.getContent(plugin));
    }

    static function read(relative:String):String {
        final path = root() + '/' + relative;
        Context.registerModuleDependency('tests.kit.ComponentDockExports', path);
        return sys.io.File.getContent(path);
    }
    #end

}
