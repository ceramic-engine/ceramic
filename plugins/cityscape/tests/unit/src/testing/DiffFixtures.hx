// New code for Cityscape (not a port): embeds vscode's diffing fixtures
// (src/vs/editor/test/node/diffing/fixtures, copied in
// tests/unit/data/vscode/diffing/fixtures) at compile time.
package testing;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

typedef DiffFixture = {
    var name:String;
    var firstFileName:String;
    var firstContent:String;
    var secondFileName:String;
    var secondContent:String;
    var legacyExpected:Null<String>;
    var advancedExpected:Null<String>;
}

/**
 * The fixtures of vscode's `fixtures.test.ts`: in each folder, the file
 * starting with `1.` is diffed against the file starting with `2.`, and
 * `legacy.expected.diff.json` / `advanced.expected.diff.json` hold vscode's
 * results. Macro only (see PORTING.md, "Pitfalls").
 */
class DiffFixtures {

    /**
     * Build macro of the fixture test class: adds `testFixture_<folder>_legacy`
     * and `testFixture_<folder>_advanced` (vscode's `${folder}-${algo}`
     * tests), each calling `runTest(folder, algo)`.
     */
    macro public static function buildTests():Array<Field> {
        final fields = Context.getBuildFields();
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('testing/DiffFixtures.hx')));
        final root = haxe.io.Path.normalize(haxe.io.Path.join([dir, '..', '..', 'data', 'vscode', 'diffing', 'fixtures']));
        final folders = sys.FileSystem.readDirectory(root).filter(f -> sys.FileSystem.isDirectory(haxe.io.Path.join([root, f])));
        folders.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        for (folder in folders) {
            for (algo in ['legacy', 'advanced']) {
                final name = 'testFixture_' + StringTools.replace(folder, '-', '_') + '_' + algo;
                fields.push({
                    name: name,
                    access: [APublic],
                    pos: Context.currentPos(),
                    kind: FFun({
                        args: [],
                        ret: macro :Void,
                        expr: macro runTest($v{folder}, $v{algo})
                    })
                });
            }
        }
        return fields;
    }

    /**
     * Returns the fixtures, sorted by folder name like `readdirSync`.
     */
    macro public static function load():Expr {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('testing/DiffFixtures.hx')));
        final root = haxe.io.Path.normalize(haxe.io.Path.join([dir, '..', '..', 'data', 'vscode', 'diffing', 'fixtures']));
        if (!sys.FileSystem.exists(root)) {
            Context.error('Missing vscode diffing fixtures: $root', Context.currentPos());
        }
        final folders = sys.FileSystem.readDirectory(root).filter(f -> sys.FileSystem.isDirectory(haxe.io.Path.join([root, f])));
        folders.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        final entries:Array<Expr> = [];
        for (folder in folders) {
            final folderPath = haxe.io.Path.join([root, folder]);
            final files = sys.FileSystem.readDirectory(folderPath);
            files.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
            var first:Null<String> = null;
            var second:Null<String> = null;
            for (f in files) {
                if (first == null && StringTools.startsWith(f, '1.')) {
                    first = f;
                }
                if (second == null && StringTools.startsWith(f, '2.')) {
                    second = f;
                }
            }
            if (first == null || second == null) {
                Context.error('Fixture without 1.* and 2.*: $folderPath', Context.currentPos());
            }
            function read(name:String):Null<String> {
                final path = haxe.io.Path.join([folderPath, name]);
                if (!sys.FileSystem.exists(path)) {
                    return null;
                }
                Context.registerModuleDependency(Context.getLocalModule(), path);
                return sys.io.File.getContent(path);
            }
            final firstContent = read(first);
            final secondContent = read(second);
            final legacy = read('legacy.expected.diff.json');
            final advanced = read('advanced.expected.diff.json');
            entries.push(macro {
                name: $v{folder},
                firstFileName: $v{first},
                firstContent: $v{firstContent},
                secondFileName: $v{second},
                secondContent: $v{secondContent},
                legacyExpected: $v{legacy},
                advancedExpected: $v{advanced}
            });
        }
        return macro ($a{entries} : Array<testing.DiffFixtures.DiffFixture>);
    }

}
