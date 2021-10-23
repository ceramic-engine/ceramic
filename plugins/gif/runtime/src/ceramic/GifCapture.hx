package ceramic;

import ceramic.Assert.assert;
import ceramic.Shortcuts.*;
import ceramic.UInt8Array;
import clay.buffers.Uint8Array;
import gif.GifEncoder;
import haxe.io.Bytes;
import haxe.io.BytesOutput;

class GifCapture extends Entity {

    @event function finish();

    var screenFps:Int = 50;

    var gifFps:Int = 50;

    var duration:Float = -1;

    var elapsed:Float = 0;

    var capturing:Bool = false;

    var frameNumber:Int = 0;

    var encoder:GifEncoder = null;

    var output:BytesOutput = null;

    var width:Int = 0;

    var height:Int = 0;

    var prevOverrideDelta:Float = -1;

    var pendingPath:String = null;

    var pendingPixelsList:Array<Uint8Array> = null;

    var mixedPixels:Uint8Array = null;

    var middleFactor:Float = 1;

    var imagesPerFrame:Int = 1;

    public function new() {

        super();

    }

    public function captureScreen(imagesPerFrame:Int = 1, middleFactor:Float = 1, gifFps:Int = 50, duration:Float = -1, ?path:String):Void {

        assert(capturing == false, 'Already capturing!');

        capturing = true;

        this.imagesPerFrame = imagesPerFrame;
        this.screenFps = gifFps * imagesPerFrame;
        this.gifFps = gifFps;
        this.duration = duration;
        this.pendingPath = path;
        this.middleFactor = middleFactor;

        frameNumber = 0;

        prevOverrideDelta = settings.overrideDelta;
        settings.overrideDelta = 0;

        pendingPixelsList = [];

        output = new BytesOutput();

        width = Std.int(screen.nativeWidth * screen.nativeDensity);
        height = Std.int(screen.nativeHeight * screen.nativeDensity);

        mixedPixels = new Uint8Array(width * height * 3);

        encoder = new GifEncoder(
            width, height,
            gifFps, Infinite, 10
        );
        encoder.start(output);

        _nextScreenFrame();

    }

    function _nextScreenFrame() {

        app.onceFinishDraw(this, () -> {
            var delta = 1.0 / screenFps;
            settings.overrideDelta = delta;
            elapsed += delta;
            app.onceFinishDraw(this, () -> {
                settings.overrideDelta = 0;

                screen.toPixels(function(pixels, width, height) {

                    // TODO pixels blending etc...
                    var rgbPixels = Pixels.rgbaPixelsToRgbPixels(width, height, pixels);

                    pendingPixelsList.push(rgbPixels);

                    if (pendingPixelsList.length >= imagesPerFrame) {

                        var mixedPixels = Pixels.mixPixelsBuffers(pendingPixelsList, middleFactor);
                        pendingPixelsList = [];

                        #if cs
                        var haxeUint8Array = haxe.io.UInt8Array.fromBytes(Bytes.ofData(mixedPixels));
                        #else
                        var haxeUint8Array = haxe.io.UInt8Array.fromBytes(mixedPixels.toBytes());
                        #end

                        trace('add frame ${frameNumber++}');
                        encoder.add(output, {
                            delay: 1.0 / gifFps,
                            flippedY: false,
                            data: haxeUint8Array
                        });

                        if (duration != -1 && elapsed >= duration) {
                            finish();
                        }
                        else {
                            _nextScreenFrame();
                        }
                    }
                    else {
                        _nextScreenFrame();
                    }
                });
            });
        });

    }

    public function finish(?path:String):Bytes {

        assert(capturing == true, 'Cannot finish if not capturing!');

        encoder.commit(output);
        var bytes = output.getBytes();

        if (path != null) {
            Files.saveBytes(path, bytes);
        }
        if (pendingPath != null && pendingPath != path) {
            trace('save bytes $pendingPath / ${bytes.length}');
            Files.saveBytes(pendingPath, bytes);
        }

        encoder = null;
        output = null;
        capturing = false;

        app.onceFinishDraw(null, function() {
            settings.overrideDelta = prevOverrideDelta;
        });

        emitFinish();

        return bytes;

    }

    override function destroy() {

        if (capturing) {
            app.onceFinishDraw(null, function() {
                settings.overrideDelta = prevOverrideDelta;
            });
        }

        super.destroy();

    }

}
