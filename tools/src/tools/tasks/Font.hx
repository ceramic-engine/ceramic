package tools.tasks;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import npm.Sharp.sharp;
import js.lib.Uint8Array;
import tools.Helpers.*;

class Font extends Task {

/// Lifecycle

    override public function help(cwd:String):Array<Array<String>> {

        return [
            ['--font <path to font>', 'The ttf/otf font file to convert'],
            ['--out <output directory>', 'The output directory'],
            ['--msdf', 'If used, export with multichannel distance field'],
            ['--size <font size>', 'The font size to export (default: 42)'],
            ['--charset', 'Characters to use as charset'],
            ['--charset-file', 'A text file containing characters to use as charset']
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
        var size:Float = extractArgValue(args, 'size') != null ? Std.parseFloat(extractArgValue(args, 'size')) : 42;

        if (fontPath == null) {
            fail('--font argument is required');
        }

        if (outputPath == null) {
            outputPath = cwd;
        }

        if (charset == null) {
            charset = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~¡¢£¤¥¦§¨©ª«¬­®¯°±²³´µ¶·¸¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿœŒ€£";
        }

        var generate:Dynamic = untyped require('msdf-bmfont-xml');

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
        var charsetPath = Path.join([tmpDir, 'charset.txt']);
        if (charsetFile != null) {
            if (!Path.isAbsolute(charsetFile)) {
                charsetFile = Path.join([cwd, charsetFile]);
            }
            charsetPath = charsetFile;
        }
        else {
            File.saveContent(charsetPath, charset);
        }

        // Run generator
        command(Path.join([context.ceramicToolsPath, 'npx']), [
            'msdf-bmfont',
            tmpFontPath,
            '-f', 'json',
            '-s', '' + size,
            '-i', charsetPath,
            '-t', 'msdf',
            '-v', //'--pot',
            '-p', '2',
            '--smart-size'
        ], { cwd: tmpDir });

        // Extract font data
        var jsonPath = Path.join([tmpDir, rawName + '.json']);
        var json = Json.parse(File.getContent(jsonPath));

        // Generate fnt data
        var fnt = '';

        fnt += 'info';
        fnt += ' face=' + Json.stringify(rawName);
        fnt += ' size=' + json.info.size;
        fnt += ' bold=' + json.info.bold;
        fnt += ' italic=' + json.info.italic;
        fnt += ' unicode=' + json.info.unicode;
        fnt += ' stretchH=' + json.info.stretchH;
        fnt += ' smooth=' + json.info.smooth;
        fnt += ' aa=' + json.info.aa;
        fnt += ' padding=' + (json.info.padding:Array<String>).join(',');
        fnt += ' spacing=' + (json.info.spacing:Array<String>).join(',');
        fnt += ' charset=""';
        fnt += '\n';

        fnt += 'common';
        fnt += ' lineHeight=' + json.common.lineHeight;
        fnt += ' base=' + json.common.base;
        fnt += ' scaleW=' + json.common.scaleW;
        fnt += ' scaleH=' + json.common.scaleH;
        fnt += ' pages=' + json.common.pages;
        fnt += ' packed=' + json.common.packed;
        fnt += ' alphaChnl=' + json.common.alphaChnl;
        fnt += ' redChnl=' + json.common.redChnl;
        fnt += ' greenChnl=' + json.common.greenChnl;
        fnt += ' blueChnl=' + json.common.blueChnl;
        fnt += '\n';

        if (msdf) {
            fnt += 'distanceField';
            fnt += ' fieldType=' + json.distanceField.fieldType;
            fnt += ' distanceRange=' + json.distanceField.distanceRange;
            fnt += '\n';
        }

        var pngFiles = [];
        var i = 0;
        for (page in (json.pages:Array<String>)) {

            pngFiles.push(page);

            var chars:Array<Dynamic> = json.chars;

            fnt += 'page id=' + i + ' file=' + Json.stringify(page) + '\n';
            fnt += 'chars count=' + chars.length;
            fnt += '\n';

            for (char in chars) {
                fnt += 'char';
                fnt += ' id=' + char.id;
                fnt += ' index=' + char.index;
                fnt += ' char=' + Json.stringify(char.char);
                fnt += ' width=' + char.width;
                fnt += ' height=' + char.height;
                fnt += ' xoffset=' + char.xoffset;
                fnt += ' yoffset=' + char.yoffset;
                fnt += ' xadvance=' + char.xadvance;
                fnt += ' chnl=' + char.chnl;
                fnt += ' x=' + char.x;
                fnt += ' y=' + char.y;
                fnt += ' page=' + char.page;
                fnt += '\n';
            }

            i++;
        }

        var kernings:Array<Dynamic> = json.kernings;
        if (kernings != null && kernings.length > 0) {

            fnt += 'kernings count=' + kernings.length + '\n';

            for (kerning in kernings) {
                fnt += 'kerning';
                fnt += ' first=' + kerning.first;
                fnt += ' second=' + kerning.second;
                fnt += ' amount=' + kerning.amount;
                fnt += '\n';
            }

        }

        // Create regular textures from svg files, if msdf is disabled
        if (!msdf) {
            for (pngFile in pngFiles) {
                
                var pngRawName = Path.withoutExtension(pngFile);
        
                var svgPath = Path.join([tmpDir, pngRawName + '.svg']);
                var pngPath = Path.join([tmpDir, pngRawName + '.png']);
                var flatPngPath = Path.join([tmpDir, pngRawName + '-flat.png']);

                // Generate a regular png texture from svg if msdf is disabled
                Sync.run(function(done) {
        
                    // Get png dimensions
                    sharp(
                        pngPath
                    )
                    .raw()
                    .toBuffer(function(err, data, info) {
        
                        if (err != null) throw err;
        
                        var width:Float = info.width;
                        var height:Float = info.height;

                        // Somehow we may need to slightly adjust crop position to make it right
                        var offsetX = 2;
                        var offsetY = 0;
        
                        // Save svg as png with same dimensions
                        sharp(
                            svgPath
                        )
                        .extract({
                            left: offsetX, top: offsetY, width: width, height: height
                        })
                        .toFile(
                            flatPngPath,
                            function(err, info) {
                                if (err != null) throw err;
                                done();
                            }
                        );
        
                    });
        
                });

                Sync.run(function(done) {

                    // Make the png white
                    sharp(
                        flatPngPath
                    )
                    .raw()
                    .toBuffer(function(err, data, info:Dynamic) {
                        var pixels:Uint8Array = data;
                        var len = pixels.length;
                        var i = 0;
                        while (i < len) {
                            pixels[i + 0] = 255;
                            pixels[i + 1] = 255;
                            pixels[i + 2] = 255;
                            i += 4;
                        }
                        sharp(pixels, {
                            raw: {
                                width: info.width,
                                height: info.height,
                                channels: info.channels
                            }
                        })
                        .png()
                        .toFile(flatPngPath, function(err, info) {
                            if (err != null) throw err;
                            done();
                        });
                    });

                });

                FileSystem.deleteFile(pngPath);
                FileSystem.rename(flatPngPath, pngPath);
            }
        }

        // Final export
        var fntPath = Path.join([outputPath, rawName + '.fnt']);
        File.saveContent(fntPath, fnt);
        for (pngFile in pngFiles) {
            var pngPath = Path.join([tmpDir, pngFile]);
            File.copy(pngPath, Path.join([outputPath, Path.withoutDirectory(pngPath)]));
        }

        // Remove temporary files
        Files.deleteRecursive(tmpDir);

    }

}