package tools;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

class FontUtils {

    public static function createBitmapFont(options:{
        fontPath:String,
        ?outputPath:String,
        ?charset:String,
        ?quiet:Bool,
        ?charsetFile:String,
        ?msdf:Bool,
        ?msdfRange:Int,
        ?bold:Bool,
        ?italic:Bool,
        ?padding:Int,
        ?size:Float,
        ?offsetX:Float,
        ?offsetY:Float
    }) {

        var cwd = context.cwd;

        var fontPath:String = options.fontPath;
        var outputPath:String = options.outputPath;
        var charset:String = options.charset;
        var quiet:Bool = options.quiet ?? false;
        var charsetFile:String = options.charsetFile;
        var msdf:Bool = options.msdf ?? false;
        var msdfRange:Int = options.msdfRange ?? 2;
        var bold:Bool = options.bold ?? false;
        var italic:Bool = options.italic ?? false;
        var padding:Int = options.padding ?? 2;
        var size:Float = options.size ?? 42;
        var offsetX:Float = options.offsetX ?? 0;
        var offsetY:Float = options.offsetY ?? 0;

        if (!Path.isAbsolute(fontPath))
            fontPath = Path.normalize(Path.join([cwd, fontPath]));

        if (!Path.isAbsolute(outputPath))
            outputPath = Path.normalize(Path.join([cwd, outputPath]));

        if (charset == null) {
            if (charsetFile != null) {
                if (!Path.isAbsolute(charsetFile)) {
                    charsetFile = Path.join([cwd, charsetFile]);
                }
                charset = File.getContent(charsetFile);
            }

            if (charset == null) {
                charset = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~¡¢£¤¥¦§¨©ª«¬­®¯°±²³´µ¶·¸¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿœŒ€£";
            }
        }

        var tmpDir = TempDirectory.tempDir('font') ?? Path.join([cwd, '.tmp']);
        if (FileSystem.exists(tmpDir)) {
            Files.deleteRecursive(tmpDir);
        }
        FileSystem.createDirectory(tmpDir);

        var ttfName = Path.withoutDirectory(fontPath);
        var rawName = Path.withoutExtension(ttfName);

        // Copy font
        var tmpFontPath = Path.join([tmpDir, ttfName]);
        File.copy(fontPath, tmpFontPath);

        // Add charset file
        var tmpCharsetPath = Path.join([tmpDir, 'charset.txt']);
        File.saveContent(tmpCharsetPath, '"' + charset.replace('"', '\\"') + '"');

        final msdfAtlasGen:String = switch Sys.systemName() {
            case 'Windows': Path.join([context.ceramicGitDepsPath, 'msdf-atlas-gen-binary', 'windows', 'msdf-atlas-gen.exe']);
            case 'Mac': Path.join([context.ceramicGitDepsPath, 'msdf-atlas-gen-binary', 'mac', 'msdf-atlas-gen']);
            case 'Linux':
                #if linux_arm64
                Path.join([context.ceramicGitDepsPath, 'msdf-atlas-gen-binary', 'linux-arm64', 'msdf-atlas-gen']);
                #else
                Path.join([context.ceramicGitDepsPath, 'msdf-atlas-gen-binary', 'linux-x86_64', 'msdf-atlas-gen']);
                #end
            case _: null;
        }

        if (msdfAtlasGen == null) {
            fail('Command not available on this platform: msdf-atlas-gen');
        }

        var tmpImagePath = Path.join([tmpDir, '$rawName.png']);
        var tmpJsonPath = Path.join([tmpDir, '$rawName.json']);

        final result = command(msdfAtlasGen, [
            '-charset', tmpCharsetPath,
            '-font', tmpFontPath,
            '-type', msdf ? 'msdf' : 'softmask',
            '-format', 'png',
            '-imageout', tmpImagePath,
            '-json', tmpJsonPath,
            '-outerpxpadding', '$padding',
            '-size', Std.string(Math.round(size))
        ].concat(msdf ? [
            '-pxrange', '$msdfRange',
        ] : []), {
            mute: quiet
        });

        // Make the image transparent, if not using msdf
        if (!msdf) {
            var image = Images.getRaw(tmpImagePath);
            image = Images.blackAndWhiteToWhiteAlpha(image);
            Images.saveRaw(Path.join([outputPath, '$rawName.png']), image);
        }
        else {
            File.copy(tmpImagePath, Path.join([outputPath, '$rawName.png']));
        }

        // Extract font data
        var json:Dynamic = Json.parse(File.getContent(tmpJsonPath));

        // Generate fnt data
        var fnt = '';

        fnt += 'info';
        fnt += ' face=' + Json.stringify(rawName);
        fnt += ' size=' + Math.round(json.atlas.size);
        fnt += ' bold=' + (bold ? '1' : '0');
        fnt += ' italic=' + (italic ? '1' : '0');
        fnt += ' unicode=1';
        fnt += ' stretchH=100';
        fnt += ' smooth=1';
        fnt += ' aa=1';
        fnt += ' padding=$padding,$padding,$padding,$padding';
        fnt += ' spacing=0,0';
        fnt += ' charset=""';
        fnt += '\n';

        var lineHeight = Math.round(json.metrics.lineHeight * json.atlas.size);
        var base = Math.round(json.metrics.ascender * json.atlas.size);
        fnt += 'common';
        fnt += ' lineHeight=' + lineHeight;
        fnt += ' base=' + base;
        fnt += ' scaleW=' + json.atlas.width;
        fnt += ' scaleH=' + json.atlas.height;
        fnt += ' pages=1';
        fnt += ' packed=0';
        fnt += ' alphaChnl=0';
        fnt += ' redChnl=0';
        fnt += ' greenChnl=0';
        fnt += ' blueChnl=0';
        fnt += '\n';

        if (msdf) {
            fnt += 'distanceField';
            fnt += ' fieldType=' + json.atlas.type;
            fnt += ' distanceRange=' + json.atlas.distanceRange;
            fnt += '\n';
        }

        fnt += 'page id=0 file=' + Json.stringify('$rawName.png') + '\n';
        fnt += 'chars count=' + json.glyphs.length;
        fnt += '\n';

        final allGlyphs:Array<Dynamic> = json.glyphs;
        for (i in 0...allGlyphs.length) {
            final glyph:Dynamic = allGlyphs[i];

            fnt += 'char';
            fnt += ' id=' + glyph.unicode;
            fnt += ' index=' + i;
            fnt += ' char=' + Json.stringify(String.fromCharCode(glyph.unicode));

            if (glyph.atlasBounds != null) {
                var width = Math.round(glyph.atlasBounds.right - glyph.atlasBounds.left);
                var height = Math.round(glyph.atlasBounds.top - glyph.atlasBounds.bottom);
                fnt += ' width=' + width;
                fnt += ' height=' + height;

                var xoffset:Float = 0;
                var yoffset:Float = 0;
                if (glyph.planeBounds != null) {
                    xoffset = glyph.planeBounds.left * json.atlas.size;
                    yoffset = (1 - glyph.planeBounds.top) * json.atlas.size;
                }
                fnt += ' xoffset=' + xoffset;
                fnt += ' yoffset=' + yoffset;
                fnt += ' x=' + glyph.atlasBounds.left;
                fnt += ' y=' + (json.atlas.height - glyph.atlasBounds.top);
            }
            else {
                fnt += ' width=0';
                fnt += ' height=0';
                fnt += ' xoffset=0';
                fnt += ' yoffset=0';
                fnt += ' x=0';
                fnt += ' y=0';
            }

            fnt += ' xadvance=' + (glyph.advance * json.atlas.size);
            fnt += ' chnl=15';
            fnt += ' page=0';
            fnt += '\n';

        }

        var kernings:Array<Dynamic> = json.kerning;
        if (kernings != null && kernings.length > 0) {

            fnt += 'kernings count=' + kernings.length + '\n';

            for (kerning in kernings) {
                fnt += 'kerning';
                fnt += ' first=' + kerning.unicode1;
                fnt += ' second=' + kerning.unicode2;
                fnt += ' amount=' + Math.round(kerning.advance * json.atlas.size);
                fnt += '\n';
            }

        }

        // Final export
        var fntPath = Path.join([outputPath, rawName + '.fnt']);
        File.saveContent(fntPath, fnt);

        // Remove temporary files
        Files.deleteRecursive(tmpDir);

        // Return `true` if the command didn't fail
        return result.status == 0;

    }

}
