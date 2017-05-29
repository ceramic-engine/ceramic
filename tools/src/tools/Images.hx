package tools;

import js.html.Uint8Array;
import haxe.Json;
import npm.Sharp.sharp;

typedef RawImageData = {

    var pixels:Uint8Array;

    var width:Int;

    var height:Int;

    var channels:Int;

} //ImageData

class Images {

    public static function getRaw(srcPath:String):RawImageData {

        var pixels:Uint8Array = null;
        var width:Int;
        var height:Int;
        var channels:Int;

        Sync.run(function(done) {

            sharp(srcPath)
            .raw()
            .toBuffer(function(err, data, info) {

                if (err) throw err;

                pixels = data;
                width = info.width;
                height = info.height;
                channels = info.channels;

                done();

            });

        });

        return {
            pixels: pixels,
            width: width,
            height: height,
            channels: channels
        };

    } //getRaw

    public static function saveRaw(dstPath:String, data:RawImageData):Void {

        Sync.run(function(done) {

            sharp(data.pixels, {
                raw: {
                    width: data.width,
                    height: data.height,
                    channels: data.channels
                }
            })
            .png()
            .toFile(dstPath, function(err, info) {

                if (err) throw err;

                done();

            });

        });

    } //saveRaw

    public static function premultiplyAlpha(pixels:Uint8Array):Void {

        var count = pixels.length;
        var index = 0;

        while (index < count) {

            var r = pixels[index+0];
            var g = pixels[index+1];
            var b = pixels[index+2];
            var a = pixels[index+3] / 255.0;

            pixels[index+0] = Std.int(r*a);
            pixels[index+1] = Std.int(g*a);
            pixels[index+2] = Std.int(b*a);

            index += 4;

        }

    } //premultiplyAlpha

} //Images
