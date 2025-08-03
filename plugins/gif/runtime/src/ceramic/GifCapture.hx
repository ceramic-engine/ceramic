package ceramic;

import ceramic.Assert.assert;
import ceramic.Shortcuts.*;
import ceramic.UInt8Array;
import gif.GifEncoder;
import haxe.io.Bytes;
import haxe.io.BytesOutput;

/**
 * Captures the screen content and creates animated GIF files.
 * 
 * This utility allows recording gameplay or animations from your Ceramic app
 * and exporting them as GIF files. It supports frame blending for smooth
 * animations and configurable frame rates.
 * 
 * ## Features
 * 
 * - Screen capture to animated GIF
 * - Configurable frame rates and duration
 * - Frame blending for smoother animations
 * - Automatic file saving
 * - Real-time capture with fixed delta time
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var capture = new GifCapture();
 * 
 * // Start capturing for 5 seconds at 30 FPS
 * capture.captureScreen(1, 1.0, 30, 5.0, "recording.gif");
 * 
 * // Listen for completion
 * capture.onFinish(this, () -> {
 *     trace("GIF saved!");
 * });
 * 
 * // Or manually stop capture
 * app.onceDelay(this, 3.0, () -> {
 *     var bytes = capture.finish("manual-stop.gif");
 *     trace("Captured " + bytes.length + " bytes");
 * });
 * ```
 * 
 * @see ceramic.Pixels
 * @see gif.GifEncoder
 */
class GifCapture extends Entity {

    /**
     * Emitted when GIF capture has finished.
     * Called after the file has been saved and encoding is complete.
     */
    @event function finish();

    /** Internal frame rate for screen capture */
    var screenFps:Int = 50;

    /** Output GIF frame rate */
    var gifFps:Int = 50;

    /** Duration to capture in seconds (-1 for manual stop) */
    var duration:Float = -1;

    /** Elapsed capture time */
    var elapsed:Float = 0;

    /** Whether currently capturing */
    var capturing:Bool = false;

    /** Current frame number */
    var frameNumber:Int = 0;

    /** GIF encoder instance */
    var encoder:GifEncoder = null;

    /** Output stream for GIF data */
    var output:BytesOutput = null;

    /** Capture width in pixels */
    var width:Int = 0;

    /** Capture height in pixels */
    var height:Int = 0;

    /** Previous delta time override value */
    var prevOverrideDelta:Float = -1;

    /** Path to save the GIF file */
    var pendingPath:String = null;

    /** List of captured pixel buffers for blending */
    var pendingPixelsList:Array<UInt8Array> = null;

    /** Buffer for mixed/blended pixels */
    var mixedPixels:UInt8Array = null;

    /** Blending factor for middle frames */
    var middleFactor:Float = 1;

    /** Number of screen captures per GIF frame */
    var imagesPerFrame:Int = 1;

    /**
     * Creates a new GIF capture instance.
     */
    public function new() {

        super();

    }

    /**
     * Starts capturing the screen content to create an animated GIF.
     * 
     * @param imagesPerFrame Number of screen captures to blend per GIF frame (higher = smoother)
     * @param middleFactor Blending weight for middle frames (0-1, affects smoothness)
     * @param gifFps Target frame rate for the output GIF
     * @param duration Duration to capture in seconds (-1 to capture until manually stopped)
     * @param path Optional file path to save the GIF (can also be specified in finish())
     */
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

        mixedPixels = new UInt8Array(width * height * 3);

        encoder = new GifEncoder(
            width, height,
            gifFps, Infinite, 10
        );
        encoder.start(output);

        _nextScreenFrame();

    }

    /**
     * Captures the next screen frame and processes it.
     * This method runs recursively to capture frames at the specified rate.
     */
    function _nextScreenFrame() {

        app.onceFinishDraw(this, () -> {
            var delta = 1.0 / screenFps;
            settings.overrideDelta = delta;
            elapsed += delta;
            app.onceFinishDraw(this, () -> {
                settings.overrideDelta = 0;

                if (!capturing)
                    return;

                screen.toPixels(function(pixels, width, height) {

                    if (!capturing)
                        return;

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

    /**
     * Finishes the GIF capture and saves the file.
     * 
     * @param path Optional file path to save the GIF (overrides path from captureScreen)
     * @return The encoded GIF data as bytes
     */
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

    /**
     * Cleans up resources and restores settings.
     * Automatically stops capture if still running.
     */
    override function destroy() {

        if (capturing) {
            app.onceFinishDraw(null, function() {
                settings.overrideDelta = prevOverrideDelta;
            });
        }

        super.destroy();

    }

}
