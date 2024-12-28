package tools.tasks.font;

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
        var quiet = extractArgFlag(args, 'quiet');
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

        FontUtils.createBitmapFont({
            fontPath: fontPath,
            outputPath: outputPath,
            charset: charset,
            quiet: quiet,
            charsetFile: charsetFile,
            msdf: msdf,
            msdfRange: msdfRange,
            bold: bold,
            italic: italic,
            padding: padding,
            size: size,
            offsetX: offsetX,
            offsetY: offsetY
        });

    }

}