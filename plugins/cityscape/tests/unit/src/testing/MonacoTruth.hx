package testing;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Embeds, at compile time, data produced by the real Monaco (the vendored
 * monaco-editor 0.52.2 of loreline-monaco, and vscode-textmate) through the scripts of
 * glaze-golden's `reference/cityscape/`, copied in `tests/unit/data/monaco`,
 * so unit tests can compare Cityscape with it.
 */
class MonacoTruth {

    /**
     * Returns the content of `tests/unit/data/monaco/<name>` as a string literal.
     */
    macro public static function load(name:String):Expr {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('testing/MonacoTruth.hx')));
        final path = haxe.io.Path.normalize(haxe.io.Path.join([dir, '..', '..', 'data', 'monaco', name]));
        if (!sys.FileSystem.exists(path)) {
            Context.error('Missing Monaco reference data: $path (run glaze-golden reference/cityscape scripts)', Context.currentPos());
        }
        Context.registerModuleDependency(Context.getLocalModule(), path);
        return macro $v{sys.io.File.getContent(path)};
    }

    /**
     * Returns the content of a TextMate grammar bundled with Glaze
     * (`plugins/glaze/assets/glaze/grammars/<file>`) as a string literal: the
     * grammars of the TextMate truth (`textmate-tokens.json`).
     */
    macro public static function loadGlazeGrammar(file:String):Expr {
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(Context.resolvePath('testing/MonacoTruth.hx')));
        final path = haxe.io.Path.normalize(haxe.io.Path.join([dir, '..', '..', '..', '..', '..', 'glaze', 'assets', 'glaze', 'grammars', file]));
        if (!sys.FileSystem.exists(path)) {
            Context.error('Missing Glaze grammar: $path', Context.currentPos());
        }
        Context.registerModuleDependency(Context.getLocalModule(), path);
        return macro $v{sys.io.File.getContent(path)};
    }

}
