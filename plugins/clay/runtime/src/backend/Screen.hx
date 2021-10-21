package backend;

import ceramic.Files;
import ceramic.Point;
import ceramic.Utils;
import clay.Clay;
import haxe.io.Bytes;

#if cpp
import opengl.GL;
#else
import clay.opengl.GL;
#end

class Screen implements tracker.Events #if !completion implements spec.Screen #end {

    public function new() {}

/// Events

    @event function resize();

    @event function mouseDown(buttonId:Int, x:Float, y:Float);
    @event function mouseUp(buttonId:Int, x:Float, y:Float);
    @event function mouseWheel(x:Float, y:Float);
    @event function mouseMove(x:Float, y:Float);

    @event function touchDown(touchIndex:Int, x:Float, y:Float);
    @event function touchUp(touchIndex:Int, x:Float, y:Float);
    @event function touchMove(touchIndex:Int, x:Float, y:Float);

/// Public API

    inline public function getWidth():Int {

        return Clay.app.screenWidth;

    }

    inline public function getHeight():Int {

        return Clay.app.screenHeight;

    }

    inline public function getDensity():Float {

        return Clay.app.screenDensity;

    }

    public function setBackground(background:Int):Void {

        // Already handled in draw loop, no need to do anything here.

    }

    public function setWindowTitle(title:String):Void {

        Clay.app.runtime.setWindowTitle(title);

    }

    public function setWindowFullscreen(fullscreen:Bool):Void {

        #if web
        // If using electron runner, use that to handle fullscreen instead of html fullscreen
        if (ElectronRunner.electronRunner != null && ElectronRunner.electronRunner.setFullscreen != null) {
            ElectronRunner.electronRunner.setFullscreen(fullscreen);
            return;
        }
        #end

        if (!Clay.app.runtime.setWindowFullscreen(fullscreen)) {
            // Failed to change fullscreen setting, restore previous setting
            ceramic.App.app.settings.fullscreen = !fullscreen;
        }

    }

/// Screenshot

    var nextScreenshotIndex:Int = 0;

    #if web

    public function screenshotToTexture(done:(texture:Texture)->Void):Void {

        var window = clay.Clay.app.runtime.window;
        window.toBlob(function(blob:Dynamic) {
            blob.arrayBuffer().then(function(buffer:js.lib.ArrayBuffer) {
                var pngBytes = ceramic.UInt8Array.fromBuffer(buffer, 0, buffer.byteLength);
                clay.Clay.app.assets.imageFromBytes(pngBytes, 'png', 4, true, function(image) {
                    if (image != null) {
                        var id = 'screenshot:' + (nextScreenshotIndex++);
                        var texture = clay.graphics.Texture.fromImage(image);
                        texture.id = id;
                        texture.init();
                        done(texture);
                    }
                    else {
                        done(null);
                    }
                });
            });
        }, 'image/png');

    }

    public function screenshotToPng(?path:String, done:(?data:Bytes)->Void):Void {

        var window = clay.Clay.app.runtime.window;
        window.toBlob(function(blob:Dynamic) {
            blob.arrayBuffer().then(function(buffer:js.lib.ArrayBuffer) {
                var pngBytes = ceramic.UInt8Array.fromBuffer(buffer, 0, buffer.byteLength).toBytes();
                if (path != null) {
                    Files.saveBytes(path, pngBytes);
                    done();
                }
                else {
                    done(pngBytes);
                }
            });
        }, 'image/png');

    }

    public function screenshotToPixels(done:(pixels:ceramic.UInt8Array, width:Int, height:Int)->Void):Void {

        var window = clay.Clay.app.runtime.window;
        window.toBlob(function(blob:Dynamic) {
            blob.arrayBuffer().then(function(buffer:js.lib.ArrayBuffer) {
                var pngBytes = ceramic.UInt8Array.fromBuffer(buffer, 0, buffer.byteLength);
                clay.Clay.app.assets.imageFromBytes(pngBytes, 'png', 4, false, function(image) {
                    if (image != null) {
                        done(image.pixels, image.width, image.height);
                    }
                    else {
                        done(null, 0, 0);
                    }
                });
            });
        }, 'image/png');

    }

    #elseif cpp

    // Just a dummy method to force opengl headers to be imported
    // in our generated c++ file
    @:noCompletion @:keep function importGlHeaders():Void {
        GL.glClear(0);
    }

    static var _point = new Point(0, 0);

    function _sdlScreenshot(point:Point):ceramic.UInt8Array {

        var width = Clay.app.runtime.windowWidth();
        var height = Clay.app.runtime.windowHeight();
        var pixels = new clay.buffers.Uint32Array(width * height);
        for (i in 0...pixels.length) {
            pixels[i] = 0;
        }

        var rmask:Int;
        var gmask:Int;
        var bmask:Int;
        var amask:Int;
        if (sdl.SDL.byteOrderIsBigEndian()) {
            rmask = 0xff000000;
            gmask = 0x00ff0000;
            bmask = 0x0000ff00;
            amask = 0x000000ff;
        }
        else {
            rmask = 0x000000ff;
            gmask = 0x0000ff00;
            bmask = 0x00ff0000;
            amask = 0xff000000;
        }

        var depth:Int = 32;
        var pitch:Int = 4 * width;
        var bytes = pixels.toBytes();

        var surface = sdl.SDL.createRGBSurfaceFrom(
            pixels.toBytes().getData(),
            width, height, depth, pitch,
            rmask, gmask, bmask, amask
        );

        // Actual screenshot
        clay.opengl.GL.readPixels(
            0, 0, width, height,
            clay.opengl.GL.RGBA,
            clay.opengl.GL.UNSIGNED_BYTE,
            pixels
        );

        _sdlSurfacePixelsToRgbaPixels(pixels, width, height);
        sdl.SDL.freeSurface(surface);

        _point.x = width;
        _point.y = height;

        return ceramic.UInt8Array.fromBytes(bytes);

    }

    function _sdlSurfacePixelsToRgbaPixels(pixels:clay.buffers.Uint32Array, width:Int, height:Int):Void {

        var halfHeight = Math.floor(height / 2);
        var px:Int = 0;
        var i:Int = 0;
        var i2:Int = 0;
        for (y in 0...halfHeight) {
            for (x in 0...width) {
                i = y * width + x;
                i2 = (height - y - 1) * width + x;
                px = pixels[i];
                pixels[i] = pixels[i2];
                pixels[i2] = px;
            }
        }

    }

    public function screenshotToTexture(done:(texture:Texture)->Void):Void {

        var pixels = _sdlScreenshot(_point);

        done(ceramic.App.app.backend.textures.createTexture(Std.int(_point.x), Std.int(_point.y), pixels));

    }

    public function screenshotToPng(?path:String, done:(?data:Bytes)->Void):Void {

        var pixels = _sdlScreenshot(_point);
        var bytes = pixels.toBytes();

        if (path != null) {
            stb.ImageWrite.write_png(path, Std.int(_point.x), Std.int(_point.y), 4, bytes.getData(), 0, bytes.length, Std.int(_point.x * 4));
            done();
        }
        else {
            // This part could be improved if we exposed stbi_write_png_to_func
            // and skipped the write to disk part, but that will do for now.
            var tmpFile = Utils.uniqueId() + '_screenshot.png';
            var storageDir = ceramic.App.app.backend.info.storageDirectory();
            var tmpPath = ceramic.Path.join([storageDir, tmpFile]);
            stb.ImageWrite.write_png(tmpPath, Std.int(_point.x), Std.int(_point.y), 4, bytes.getData(), 0, bytes.length, Std.int(_point.x * 4));
            var data = Files.getBytes(tmpPath);
            Files.deleteFile(tmpPath);
            done(data);
        }

    }

    public function screenshotToPixels(done:(pixels:ceramic.UInt8Array, width:Int, height:Int)->Void):Void {

        var pixels = _sdlScreenshot(_point);

        done(pixels, Std.int(_point.x), Std.int(_point.y));

    }

    #else

    public function screenshotToTexture(done:(texture:Texture)->Void):Void {

        done(null);

    }

    public function screenshotToPng(?path:String, done:(?data:Bytes)->Void):Void {

        done(null);

    }

    public function screenshotToPixels(done:(pixels:ceramic.UInt8Array, width:Int, height:Int)->Void):Void {

        done(null, 0, 0);

    }

    #end

}
