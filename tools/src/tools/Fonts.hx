package tools;

import npm.OpenType;
import npm.Canvas;
import npm.MultiBinPacker;
import haxe.io.Path;
import tools.Tools.*;
import js.node.ChildProcess;
import js.html.Uint8ClampedArray;

class Fonts {

    public static var DEFAULT_CHARSET = "!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

    // Implementation strongly inspired from node module `msdf-bmfont`

    public static function generateBitmapFont(fontPath:String, ?options:{
        ?charset:String,
        ?fontSize:Int,
        ?textureWidth:Int,
        ?textureHeight:Int,
        ?texturePadding:Int,
        ?distanceRange:Int,
        ?fieldType:String
    }) {

        if (options == null) options = {};

        var charset = options.charset != null ? options.charset : DEFAULT_CHARSET;
        var fontSize = options.fontSize != null ? options.fontSize : 42;
        var textureWidth = options.textureWidth != null ? options.textureWidth : 512;
        var textureHeight = options.textureHeight != null ? options.textureHeight : 512;
        var texturePadding = options.texturePadding != null ? options.texturePadding : 0;
        var distanceRange = options.distanceRange != null ? options.distanceRange : 3;
        var fieldType = options.fieldType != null ? options.fieldType : 'msdf';

        var font = OpenType.loadSync(fontPath);
        if (untyped font.outlinesFormat != 'truetype') {
            fail("Must specify a truetype font.");
        }
        var canvas = new Canvas(textureWidth, textureHeight);
        var context = canvas.getContext2d();
        var packer = new MultiBinPacker<Dynamic>(textureWidth, textureHeight, texturePadding);
        var chars:Array<String> = [];

        var i = 0;
        var toAdd = [];
        while (i < charset.length) {

            var char = charset.charAt(i);

            var res = generateImage({
                font: font,
                char: char,
                fontSize: fontSize,
                fontPath: fontPath,
                fieldType: fieldType,
                distanceRange: distanceRange
            });

            toAdd.push({width: res.width, height: res.height, data: res.data});
            i++;
        }

        packer.addArray(toAdd);

        var textures = [];
        var index = 0;
        while (index < packer.bins.length) {
            
            var bin = packer.bins[index];
            context.fillStyle = '#000000';
            context.fillRect(0, 0, canvas.width, canvas.height);
            //context.clearRect(0, 0, canvas.width, canvas.height);
            for (rect in bin.rects) {
                if (rect.data.imageData != null) {
                    context.putImageData(rect.data.imageData, rect.x, rect.y);
                }
                var charData = rect.data.fontData;
                charData.x = rect.x;
                charData.y = rect.y;
                charData.page = index;
                chars.push(rect.data.fontData);
            }

            textures.push(canvas.toBuffer());
            index++;
        }

        var kernings = [];
        for (i in 0...charset.length) {
            for (j in 0...charset.length) {
                var first = charset.charAt(i);
                var second = charset.charAt(j);

                var amount = font.getKerningValue(font.charToGlyph(first), font.charToGlyph(second));
                if (amount != 0) {
                    kernings.push({
                        first: first.charCodeAt(0),
                        second: second.charCodeAt(0),
                        amount: amount * (fontSize / font.unitsPerEm)
                    });
                }
            }
        }

        var os2 = untyped font.tables.os2;
        var name = untyped font.tables.name.fullName;
        var face = untyped __js__('name[Object.getOwnPropertyNames(name)[0]]');
        var fontData = {
            pages: [],
            chars: chars,
            info: {
                face: face,
                size: fontSize,
                bold: 0,
                italic: 0,
                charset: charset,
                unicode: 1,
                stretchH: 100,
                smooth: 1,
                aa: 1,
                padding: [0, 0, 0, 0],
                spacing: [texturePadding, texturePadding]
            },
            common: {
                lineHeight: (os2.sTypoAscender - os2.sTypoDescender + os2.sTypoLineGap) * (fontSize / font.unitsPerEm),
                base: font.ascender * (fontSize / font.unitsPerEm),
                scaleW: textureWidth,
                scaleH: textureHeight,
                pages: packer.bins.length,
                packed: 0,
                alphaChnl: 0,
                redChnl: 0,
                greenChnl: 0,
                blueChnl: 0
            },
            kernings: kernings
        }

        return {
            textures: textures,
            fontData: fontData
        };

    } //generateBitmapFont

    static function generateImage(options:{
        font:OpenTypeFont,
        char:String,
        fontSize:Int,
        fontPath:String,
        fieldType:String,
        distanceRange:Int
    }) {

        var fontPath = options.fontPath;
        var font = options.font;
        var char = options.char;
        var fontSize = options.fontSize;
        var fieldType = options.fieldType;
        var distanceRange = options.distanceRange;
        var glyph = font.charToGlyph(char);
        var bounds = glyph.getBoundingBox();
        var unitsPerEm:Float = font.unitsPerEm;
        //var commands = glyph.getPath(0, 0, fontSize).commands;

        /*var contours:Array<Array<Dynamic>> = [];
        var currentContour = [];
        var bBox = {
            left: 0.0,
            bottom: 0.0,
            right: 0.0,
            top: 0.0
        };*/
        var bBox = {
            left: bounds.x1 / unitsPerEm,
            bottom: bounds.y2 / unitsPerEm,
            right: bounds.x2 / unitsPerEm,
            top: bounds.y1 / unitsPerEm,
            width: (bounds.x2 / unitsPerEm) - (bounds.x1 / unitsPerEm),
            height: (bounds.y2 / unitsPerEm) - (bounds.y1 / unitsPerEm)
        };

        trace(bBox);

        /*for (command in commands) {
            if (command.type == 'M') { // new contour
                if (currentContour.length > 0) {
                    contours.push(currentContour);
                    currentContour = [];
                }
            }
            currentContour.push(command);
        }
        contours.push(currentContour);

        var shapeDesc = '';
        for (contour in contours) {
            shapeDesc += '{';
            var lastIndex = contour.length - 1;

            var index = 0;
            for (command in contour) {
                if (command.type == 'Z') {
                    // shapeDesc += `${contour[0].x}, ${contour[0].y}`;
                    // adding the last point breaks it??!??!
                } else {
                    if (command.type == 'C') {
                        shapeDesc += '(${command.x1}, ${command.y1}; ${command.x2}, ${command.y2}); ';
                    } else if (command.type == 'Q') {
                        shapeDesc += '(${command.x1}, ${command.y1}); ';
                    }
                    shapeDesc += '${command.x}, ${command.y}';
                    bBox.left = Math.min(bBox.left, command.x);
                    bBox.bottom = Math.min(bBox.bottom, command.y);
                    bBox.right = Math.max(bBox.right, command.x);
                    bBox.top = Math.max(bBox.top, command.y);
                }
                if (index != lastIndex) {
                    shapeDesc += '; ';
                }
                index++;
            }
            shapeDesc += '}';
        }*/

        /*var normalized = true;
        for (contour in contours) {
            if (contour.length == 1) {
                normalized = false; // Failed to normalize
                break;
            }
        }*/

        var scale = fontSize / font.unitsPerEm;
        var height = fontSize;
        var width = Math.round(bBox.height / bBox.width * fontSize);
        var xOffset = 0;//bBox.left;
        var yOffset = 0;//bBox.right;

        // MSDF
        //var args:Array<Dynamic> = [fieldType, '-format', 'text', '-stdout', '-size', width, height, '-translate', pad, yOffset, '-pxrange', distanceRange, '-defineshape', shapeDesc, '-testrender', 'render'+char.charCodeAt(0)+'.png', 400, 400];
        var args:Array<Dynamic> = [fieldType, '-format', 'text', '-stdout', '-size', width, height, '-autoframe', '-pxrange', distanceRange, '-font', fontPath, char.charCodeAt(0), '-testrender', 'render'+char.charCodeAt(0)+'.png', 42, 42];
        //trace(args);
        var result = msdfgen(args);
        
        if (result.status != 0) {
            fail("Failed to generate glyph: " + result.error);
        }

        var stdout = ''+result.stdout;
        var rawImageData:Array<Int> = untyped __js__('stdout.match(/([0-9a-fA-F]+)/g).map(str => parseInt(str, 16))');
        var pixels = [];
        var channelCount:Int = cast rawImageData.length / (width * height);

        if (!Math.isNaN(channelCount) && channelCount % 1 != 0) {
            fail("msdfgen return an image with an invalid length: " + result.stdout);
        }

        var i = 0;
        if (fieldType == 'msdf') {
            while (i < rawImageData.length) {
                for (k in 0...channelCount) {
                    pixels.push(rawImageData[i+k]);
                }
                pixels.push(255);
                i += channelCount;
            }
        }
        else {
            while (i < rawImageData.length) {
                pixels.push(rawImageData[i]);
                pixels.push(rawImageData[i]);
                pixels.push(rawImageData[i]);
                pixels.push(255);
                i += channelCount;
            }
        }

        var imageData = null;
        var charIsBlank = false;
        if (!Math.isNaN(channelCount)) {
            var hasDefinedPixels = false;
            for (x in rawImageData) {
                if (x != 0) {
                    hasDefinedPixels = true;
                    break;
                }
            }
            if (!hasDefinedPixels) charIsBlank = true;
        } else {
            charIsBlank = true;
        }
        if (charIsBlank) {
            warning('No bitmap for character $char (${char.charCodeAt(0)}), adding to font as empty.');
            width = 0;
            height = 0;
        }
        else {
            imageData = new ImageData(new Uint8ClampedArray(pixels), width, height);
        }

        return {
            data: {
                imageData: imageData,
                fontData: {
                    id: char.charCodeAt(0),
                    width: width,
                    height: height,
                    xoffset: 0,
                    yoffset: bBox.bottom,
                    xadvance: glyph.advanceWidth * scale,
                    chnl: 15
                }
            },
            width: width,
            height: height
        };

    } //generateImage

    static function msdfgen(args:Array<Dynamic>):ChildProcessSpawnSyncResult {

        var cmd = Path.join([settings.ceramicPath, 'git/msdfgen/msdfgen.mac']);
        var args_:Array<String> = [];
        for (arg in args) {
            args_.push(''+arg);
        }

        return ChildProcess.spawnSync(cmd, args_, {cwd: shared.cwd});

    } //msdfgen

} //Fonts
