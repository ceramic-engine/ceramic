package tests;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Shared fixtures of the text system tests:
 *
 * - the values dumped from the original GPUI (gpui-pre 0.3.10 with the
 *   `CosmicTextSystem` of gpui-pre-wgpu) by `reference/examples/text_dump.rs`
 *   (`test/unit/data/gpui-text-reference.json`). Regenerate with, from
 *   `reference/`:
 *   `cargo run --release --example text_dump -- ../test/unit/data/gpui-text-reference.json`
 * - the same font files, embedded as resources: Inter and JetBrains Mono
 *   from `ceramic/git/ttf/test/fonts` (SIL Open Font License 1.1).
 */
class TextFixtures {

    #if !macro

    static var cachedReference:Dynamic = null;

    static var cachedTextSystem:gpui.TextSystem = null;

    public static function reference():Dynamic {
        if (cachedReference == null) {
            cachedReference = haxe.Json.parse(referenceContent());
        }
        return cachedReference;
    }

    public static function interBytes():haxe.io.Bytes {
        embedFonts();
        return haxe.Resource.getBytes('gpui-test-font-inter');
    }

    public static function monoBytes():haxe.io.Bytes {
        return haxe.Resource.getBytes('gpui-test-font-mono');
    }

    /**
     * A text system over `CeramicTextSystem` loaded with the reference fonts,
     * like the dump (`.SystemUIFont` is Inter).
     */
    public static function textSystem():gpui.TextSystem {
        if (cachedTextSystem == null) {
            final platform = new gpui.platform.CeramicTextSystem('Inter');
            cachedTextSystem = new gpui.TextSystem(platform);
            cachedTextSystem.addFonts([interBytes(), monoBytes()]);
        }
        return cachedTextSystem;
    }

    /** Family name of the face of a font id */
    public static function familyOf(fontId:gpui.FontId):String {
        final platform:gpui.platform.CeramicTextSystem = cast textSystem().platformTextSystem;
        return platform.ttfFont(fontId).familyName;
    }

    /** Builds GPUI runs from the run descriptions of the dump */
    public static function textRuns(runs:Array<Dynamic>):Array<gpui.TextRun> {
        final result:Array<gpui.TextRun> = [];
        for (desc in runs) {
            final font = gpui.Font.of(desc.family);
            if (desc.bold)
                font.weight = gpui.FontWeight.BOLD;
            if (desc.disable_calt)
                font.features = gpui.FontFeatures.disableLigatures();
            if (desc.fallbacks != null)
                font.fallbacks = gpui.FontFallbacks.fromFonts([for (f in (desc.fallbacks:Array<String>)) f]);
            result.push(new gpui.TextRun(desc.len, font, new gpui.Hsla(0, 0, 0, 1)));
        }
        return result;
    }

    #end

    static macro function referenceContent():Expr {
        final file = Context.getPosInfos(Context.currentPos()).file;
        final dir = haxe.io.Path.directory(sys.FileSystem.fullPath(file));
        final path = haxe.io.Path.normalize(dir + '/../../data/gpui-text-reference.json');
        Context.registerModuleDependency('tests.TextFixtures', path);
        return macro $v{sys.io.File.getContent(path)};
    }

    static macro function embedFonts():Expr {
        final file = Context.getPosInfos(Context.currentPos()).file;
        final dir = haxe.io.Path.directory(sys.FileSystem.fullPath(file));
        final fonts = haxe.io.Path.normalize(dir + '/../../../../../ceramic/git/ttf/test/fonts');
        for (entry in [['gpui-test-font-inter', 'Inter-Regular.ttf'], ['gpui-test-font-mono', 'JetBrainsMono-Regular.ttf']]) {
            final path = fonts + '/' + entry[1];
            if (!sys.FileSystem.exists(path))
                Context.error('Missing test font: $path', Context.currentPos());
            Context.registerModuleDependency('tests.TextFixtures', path);
            Context.addResource(entry[0], sys.io.File.getBytes(path));
        }
        return macro null;
    }

}
