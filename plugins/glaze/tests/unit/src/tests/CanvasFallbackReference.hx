package tests;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * The classification of the original gpui-pre-web canvas_fallback.rs
 * (`test/unit/data/canvas-fallback-reference.json`), embedded at compile
 * time. Dumped by a Rust program that compiles the original file with
 * `#[path]` against unicode-properties 0.1.3, unicode-script 0.5.8 and
 * unicode-segmentation 1.13.2 (the versions of the reference harness): for
 * every code point, its classification (`single`: ranges of 1 CJK, 2 emoji
 * in text presentation, 3 emoji presentation), the emoji status and Han
 * letter tables the port uses, and for 23 suffixes the classification of
 * every code point followed by the suffix (`sequences`).
 */
class CanvasFallbackReference {

    #if !macro
    public static function content():String {
        return referenceContent();
    }
    #end

    static macro function referenceContent():Expr {
        final file = Context.getPosInfos(Context.currentPos()).file;
        final dir = haxe.io.Path.directory(sys.FileSystem.fullPath(file));
        final path = haxe.io.Path.normalize(dir + '/../../data/canvas-fallback-reference.json');
        Context.registerModuleDependency('tests.CanvasFallbackReference', path);
        return macro $v{sys.io.File.getContent(path)};
    }

}
