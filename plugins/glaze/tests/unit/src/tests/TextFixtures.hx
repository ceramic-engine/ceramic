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
 *   (`tests/unit/data/gpui-text-reference.json`). Regenerate with, from
 *   `reference/`:
 *   `cargo run --release --example text_dump -- ../../ceramic/plugins/glaze/tests/unit/data/gpui-text-reference.json`
 * - the same font files, embedded as resources: Inter and JetBrains Mono
 *   from `ceramic/git/ttf/test/fonts` (SIL Open Font License 1.1).
 */
class TextFixtures {

    #if !macro

    static var cachedReference:Dynamic = null;

    static var cachedTextSystem:glaze.TextSystem = null;

    public static function reference():Dynamic {
        if (cachedReference == null) {
            cachedReference = haxe.Json.parse(referenceContent());
        }
        return cachedReference;
    }

    public static function interBytes():haxe.io.Bytes {
        embedFonts();
        return haxe.Resource.getBytes('glaze-test-font-inter');
    }

    public static function monoBytes():haxe.io.Bytes {
        return haxe.Resource.getBytes('glaze-test-font-mono');
    }

    /**
     * A text system over `CeramicTextSystem` loaded with the reference fonts,
     * like the dump (`.SystemUIFont` is Inter).
     */
    public static function textSystem():glaze.TextSystem {
        if (cachedTextSystem == null) {
            final platform = new glaze.platform.CeramicTextSystem('Inter');
            cachedTextSystem = new glaze.TextSystem(platform);
            cachedTextSystem.addFonts([interBytes(), monoBytes()]);
        }
        return cachedTextSystem;
    }

    /** Family name of the face of a font id */
    public static function familyOf(fontId:glaze.FontId):String {
        final platform:glaze.platform.CeramicTextSystem = cast textSystem().platformTextSystem;
        return platform.ttfFont(fontId).familyName;
    }

    /** Builds GPUI runs from the run descriptions of the dump */
    public static function textRuns(runs:Array<Dynamic>):Array<glaze.TextRun> {
        final result:Array<glaze.TextRun> = [];
        for (desc in runs) {
            final font = glaze.Font.of(desc.family);
            if (desc.bold)
                font.weight = glaze.FontWeight.BOLD;
            if (desc.disable_calt)
                font.features = glaze.FontFeatures.disableLigatures();
            if (desc.fallbacks != null)
                font.fallbacks = glaze.FontFallbacks.fromFonts([for (f in (desc.fallbacks:Array<String>)) f]);
            result.push(new glaze.TextRun(desc.len, font, new glaze.Hsla(0, 0, 0, 1)));
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
        final fonts = haxe.io.Path.normalize(dir + '/../../../../../../git/ttf/test/fonts');
        for (entry in [['glaze-test-font-inter', 'Inter-Regular.ttf'], ['glaze-test-font-mono', 'JetBrainsMono-Regular.ttf']]) {
            final path = fonts + '/' + entry[1];
            if (!sys.FileSystem.exists(path))
                Context.error('Missing test font: $path', Context.currentPos());
            Context.registerModuleDependency('tests.TextFixtures', path);
            Context.addResource(entry[0], sys.io.File.getBytes(path));
        }
        return macro null;
    }

}
