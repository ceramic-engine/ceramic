package tools;

#if (haxe_ver < 4)
import js.html.Uint8Array;
#else
import js.lib.Uint8Array;
#end
import haxe.Json;
import haxe.io.Path;
import npm.Sharp.sharp;
import npm.ToIco.toIco;
import sys.FileSystem;

typedef RawImageData = {

    var pixels:Uint8Array;

    var width:Int;

    var height:Int;

    var channels:Int;

}

typedef ImageMetadata = {

    var width:Int;

    var height:Int;

}

typedef TargetImage = {

    var path:String;

    var width:Int;

    var height:Int;

}

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

                if (err != null) throw err;

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

    }

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

                if (err != null) throw err;

                done();

            });

        });

    }

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

    }

    public static function resize(srcPath:String, dstPath:String, targetWidth:Float, targetHeight:Float):Void {

        Sync.run(function(done) {

            // Create target directory if needed
            var dirname = Path.directory(dstPath);
            if (!FileSystem.exists(dirname)) {
                FileSystem.createDirectory(dirname);
            }

            sharp(
                srcPath
            ).resize(
                Math.round(targetWidth), Math.round(targetHeight)
            ).toFile(
                dstPath,
                function(err, info) {
                    if (err != null) throw err;

                    done();
                }
            );

        });

    }

    public static function createIco(srcPath:String, dstPath:String, targetWidth:Float = 256, targetHeight:Float = 256):Void {

        Sync.run(function(done) {

            // Create target directory if needed
            var dirname = Path.directory(dstPath);
            if (!FileSystem.exists(dirname)) {
                FileSystem.createDirectory(dirname);
            }

            sharp(
                srcPath
            ).resize(
                Math.round(targetWidth), Math.round(targetHeight)
            ).toBuffer(function(err, data, info) {

                if (err != null) throw err;

                toIco([data], {resize: true, sizes: [16, 24, 32, 48, 64, 128, 256]})
                .then(function(buffer:js.node.Buffer) {

                    js.node.Fs.writeFileSync(dstPath, buffer);

                    done();

                },
                function(err) {
                    throw err;
                });

            });

        });

    }

    public function metadata(path:String):ImageMetadata {

        var width:Float = 0;
        var height:Float = 0;

        Sync.run(function(done) {

            sharp(
                path
            ).metadata(function(err, meta) {
                if (err != null) throw err;

                width = meta.width;
                height = meta.height;

            });

        });

        return {
            width: Math.round(width),
            height: Math.round(height)
        };

    }

}
