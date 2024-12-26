package tools.tasks;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

class Font extends Task {

/// Lifecycle

    override public function help(cwd:String):Array<Array<String>> {

        return [
            ['--font <path to font>', 'The ttf/otf font file to convert'],
            ['--out <output directory>', 'The output directory'],
            ['--msdf', 'If used, export with multichannel distance field'],
            ['--msdf-range', 'Sets the distance field range in pixels (default: 2)'],
            ['--size <font size>', 'The font size to export (default: 42)'],
            ['--factor <factor>', 'A precision factor (advanced usage, default: 4)'],
            ['--charset', 'Characters to use as charset'],
            ['--charset-file', 'A text file containing characters to use as charset'],
            ['--offset-x', 'Move every character by this X offset'],
            ['--offset-y', 'Move every character by this Y offset']
        ];

    }

    override public function info(cwd:String):String {

        return "Utility to convert ttf/otf font to bitmap font compatible with ceramic";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var fontPath = extractArgValue(args, 'font');
        var outputPath = extractArgValue(args, 'out');
        var charset = extractArgValue(args, 'charset');
        var charsetFile = extractArgValue(args, 'charset-file');
        var msdf = extractArgFlag(args, 'msdf');
        var msdfRange = extractArgValue(args, 'msdf-range') != null ? Math.round(Std.parseFloat(extractArgValue(args, 'msdf-range'))) : 2;
        var bold = extractArgFlag(args, 'bold');
        var italic = extractArgFlag(args, 'italic');
        var padding:Int = extractArgValue(args, 'padding') != null ? Math.round(Std.parseFloat(extractArgValue(args, 'padding'))) : 2;
        var size:Float = extractArgValue(args, 'size') != null ? Std.parseFloat(extractArgValue(args, 'size')) : 42;
        var offsetX:Float = extractArgValue(args, 'offset-x') != null ? Std.parseFloat(extractArgValue(args, 'offset-x')) : 0;
        var offsetY:Float = extractArgValue(args, 'offset-y') != null ? Std.parseFloat(extractArgValue(args, 'offset-y')) : 0;

        if (fontPath == null) {
            fail('--font argument is required');
        }

        if (outputPath == null) {
            outputPath = cwd;
        }

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

        if (!Path.isAbsolute(fontPath))
            fontPath = Path.normalize(Path.join([cwd, fontPath]));

        if (!Path.isAbsolute(outputPath))
            outputPath = Path.normalize(Path.join([cwd, outputPath]));

        var tmpDir = Path.join([cwd, '.tmp']);
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

        command(msdfAtlasGen, [
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
        ] : []));

        // Make the image transparent, if not using msdf
        if (!msdf) {
            var image = Images.getRaw(tmpImagePath);
            image = Images.blackAndWhiteToWhiteAlpha(image);
            Images.saveRaw('$rawName.png', image);
        }
        else {
            File.copy(tmpImagePath, '$rawName.png');
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
        //Files.deleteRecursive(tmpDir);

    }

}