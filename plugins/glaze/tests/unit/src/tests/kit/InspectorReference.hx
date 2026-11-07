// New code for the Haxe port of gpui-kit: embeds test/unit/data/inspector-reference.json,
// the outputs of the original inspector code. See NOTICE.md.
package tests.kit;

import haxe.macro.Expr;

/**
 * The content of `test/unit/data/inspector-reference.json`, embedded at
 * compile time (kept in its own module so that the macro context does not
 * load the inspector).
 */
class InspectorReference {

    public static macro function content():Expr {
        final file = haxe.macro.Context.getPosInfos(haxe.macro.Context.currentPos()).file;
        final dir = haxe.io.Path.directory(sys.FileSystem.fullPath(file));
        final path = haxe.io.Path.normalize(dir + '/../../../data/inspector-reference.json');
        haxe.macro.Context.registerModuleDependency('tests.kit.InspectorReference', path);
        return macro $v{sys.io.File.getContent(path)};
    }

}
