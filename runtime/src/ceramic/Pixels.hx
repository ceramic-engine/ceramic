package ceramic;

import ceramic.Assert.assert;
import haxe.io.Bytes;

using ceramic.Extensions;

/**
 * Utilities to manipulate RGBA pixels.
 */
class Pixels {

    /**
     * Copy pixels from `srcBuffer` to `dstBuffer`
     * @param srcBuffer Source buffer to copy pixels from
     * @param srcBufferWidth Source buffer image width (needed to know index from x,y coordinates)
     * @param dstBuffer Destination buffer to past pixels into
     * @param dstBufferWidth Destination buffer image width (needed to know index from x,y coordinates)
     * @param srcX Source x position to copy from
     * @param srcY Source y position to copy from
     * @param srcWidth Source width to copy from
     * @param srcHeight Source height to copy from
     * @param dstX Destination x to paste into
     * @param dstY Destination y to paste into
     * @param copyRed Set to `true` default to copy red channel
     * @param copyGreen Set to `true` default to copy green channel
     * @param copyBlue Set to `true` default to copy blue channel
     * @param copyAlpha Set to `true` default to copy alpha channel
     */
    public static function copy(
        srcBuffer:UInt8Array, srcBufferWidth:Int,
        dstBuffer:UInt8Array, dstBufferWidth:Int,
        srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int,
        dstX:Int, dstY:Int,
        copyRed:Bool = true, copyGreen:Bool = true, copyBlue:Bool = true, copyAlpha:Bool = true
    ):Void {

        var right:Int = srcX + srcWidth;
        var bottom:Int = srcY + srcHeight;

        var x0:Int = srcX;
        var y0:Int = srcY;
        var x1:Int = dstX;
        var y1:Int = dstY;

        while (y0 < bottom) {
            var yIndex0:Int = y0 * srcBufferWidth;
            var yIndex1:Int = y1 * dstBufferWidth;

            while (x0 < right) {
                var index0:Int = (yIndex0 + x0) * 4;
                var index1:Int = (yIndex1 + x1) * 4;

                if (copyRed) {
                    dstBuffer[index1] = srcBuffer[index0];
                }
                index0++;
                index1++;

                if (copyGreen) {
                    dstBuffer[index1] = srcBuffer[index0];
                }
                index0++;
                index1++;

                if (copyBlue) {
                    dstBuffer[index1] = srcBuffer[index0];
                }
                index0++;
                index1++;

                if (copyAlpha) {
                    dstBuffer[index1] = srcBuffer[index0];
                }
                index0++;
                index1++;

                // Next column
                x0++;
                x1++;
            }

            // Next row
            y0++;
            y1++;
            x0 = srcX;
            x1 = dstX;
        }

    }

    /**
     * Create a pixels buffer
     * @param width Image width
     * @param height Image height
     * @param fillColor Default color
     * @return UInt8Array
     */
    public static function create(width:Int, height:Int, fillColor:AlphaColor):UInt8Array {

        var buffer = new UInt8Array(width * height * 4);
        for (i in 0...width * height) {
            var n = i * 4;
            buffer[n] = fillColor.red;
            n++;
            buffer[n] = fillColor.green;
            n++;
            buffer[n] = fillColor.blue;
            n++;
            buffer[n] = fillColor.alpha;
        }
        return buffer;

    }

    /**
     * Create a pixels buffer from bytes with RGBA representation
     */
    public static function fromBytes(bytes:Bytes):UInt8Array {

        #if (cpp || js)
        return UInt8Array.fromBytes(bytes);
        #else
        return bytes.getData();
        #end

    }

    /**
     * Get a pixel as `AlphaColor` at `x`,`y` coordinates on the given buffer
     * @param buffer The pixel buffer to read from
     * @param bufferWidth Image width
     * @param x Pixel x position
     * @param y Pixel y position
     * @return AlphaColor
     */
    public static inline function get(
        buffer:UInt8Array, bufferWidth:Int,
        x:Int, y:Int
    ):AlphaColor {

        var index:Int = (y * bufferWidth + x) * 4;
        return new AlphaColor(
            Color.fromRGB(buffer[index], buffer[index + 1], buffer[index + 2]), buffer[index + 3]
        );

    }

    /**
     * Set a pixel as `AlphaColor` at `x`,`y` coordinates on the given buffer
     * @param buffer The pixel buffer to write into
     * @param bufferWidth Image width
     * @param x Pixel x position
     * @param y Pixel y position
     * @param color AlphaColor of the pixel
     */
    public static inline function set(
        buffer:UInt8Array, bufferWidth:Int,
        x:Int, y:Int, color:AlphaColor
    ):Void {

        var index:Int = (y * bufferWidth + x) * 4;
        buffer[index] = color.red;
        buffer[index + 1] = color.green;
        buffer[index + 2] = color.blue;
        buffer[index + 3] = color.alpha;

    }

    /**
     * Set a rectangle of pixels as `AlphaColor` at `x`,`y` coordinates and with the specified `width` and `height` on the given buffer
     * @param buffer The pixel buffer to write into
     * @param bufferWidth Image width
     * @param x Rectangle x position
     * @param y Rectangle y position
     * @param width Rectangle width
     * @param height Rectangle height
     * @param color AlphaColor of the rectangle's pixels
     */
     public static inline function setRectangle(
        buffer:UInt8Array, bufferWidth:Int,
        x:Int, y:Int, width:Int, height:Int, color:AlphaColor
    ):Void {

        for (rectangleX in 0...width) for (rectangleY in 0...height) {
            set(buffer, bufferWidth, x + rectangleX, y + rectangleY, color);
        }

    }

    /**
     * Export the given pixels pixels as PNG data and save it to the given file path
     * @param width Image width
     * @param height Image height
     * @param pixels The pixels buffer
     * @param path The png file path where to save the image (`'/path/to/image.png'`)
     * @param done Called when the png has been exported
     */
    static inline extern overload public function pixelsToPng(width:Int, height:Int, pixels:UInt8Array, path:String, done:()->Void):Void {
        _pixelsToPng(width, height, pixels, path, (?data) -> {
            done();
        });
    }

    /**
     * Export the given pixels to PNG data/bytes
     * @param width Image width
     * @param height Image height
     * @param pixels The pixels buffer
     * @param done Called when the png has been exported, with `data` containing PNG bytes
     * @return ->Void):Void
     */
    static inline extern overload public function pixelsToPng(width:Int, height:Int, pixels:UInt8Array, done:(data:Bytes)->Void):Void {
        _pixelsToPng(width, height, pixels, null, (?data) -> {
            done(data);
        });
    }

    static function _pixelsToPng(width:Int, height:Int, pixels:UInt8Array, ?path:String, done:(?data:Bytes)->Void):Void {

        ceramic.App.app.backend.textures.pixelsToPng(width, height, pixels, path, done);

    }

    /**
     * Converts a RGBA pixels buffer into RGB pixels buffer
     * @param width Image width
     * @param height Image height
     * @param inPixels The source RGBA pixels buffer
     * @param outPixels (optional) The destination RGB pixels buffer
     * @return The final RGB pixels buffer
     */
    public static function rgbaPixelsToRgbPixels(width:Int, height:Int, inPixels:UInt8Array, ?outPixels:UInt8Array):UInt8Array {

        var rgbLength = width * height * 3;
        if (outPixels == null) {
            outPixels = new UInt8Array(rgbLength);
        }
        else if (outPixels.length != rgbLength) {
            ceramic.Shortcuts.log.warning('Not reusing outPixels because its length (${outPixels.length}) does not match the required one: $rgbLength. Creating a new buffer.');
            outPixels = new UInt8Array(rgbLength);
        }

        for (i in 0...width * height) {
            var nRgb = i * 3;
            var nRgba = i * 4;
            outPixels[nRgb] = inPixels[nRgba];
            nRgb++;
            nRgba++;
            outPixels[nRgb] = inPixels[nRgba];
            nRgb++;
            nRgba++;
            outPixels[nRgb] = inPixels[nRgba];
        }
        return outPixels;

    }

    /**
     * Converts a RGB pixels buffer into RGBA pixels buffer
     * @param width Image width
     * @param height Image height
     * @param alpha Alpha value (0-255) to use (default to 255)
     * @param inPixels The source RGBA pixels buffer
     * @param outPixels (optional) The destination RGB pixels buffer
     * @return The final RGBA pixels buffer
     */
    public static function rgbPixelsToRgbaPixels(width:Int, height:Int, alpha:Int = 255, inPixels:UInt8Array, ?outPixels:UInt8Array):UInt8Array {

        var rgbaLength = width * height * 4;
        if (outPixels == null) {
            outPixels = new UInt8Array(rgbaLength);
        }
        else if (outPixels.length != rgbaLength) {
            ceramic.Shortcuts.log.warning('Not reusing outPixels because its length (${outPixels.length}) does not match the required one: $rgbaLength. Creating a new buffer.');
            outPixels = new UInt8Array(rgbaLength);
        }

        for (i in 0...width * height) {
            var nRgb = i * 3;
            var nRgba = i * 4;
            outPixels[nRgba] = inPixels[nRgb];
            nRgb++;
            nRgba++;
            outPixels[nRgba] = inPixels[nRgb];
            nRgb++;
            nRgba++;
            outPixels[nRgba] = inPixels[nRgb];
            nRgba++;
            outPixels[nRgba] = alpha;
        }
        return outPixels;

    }

    /**
     * Mix the given list of pixels buffers into a single one.
     * @param inPixelsList An array of pixels buffers
     * @param middleFactor A multiplicator that makes the middle buffers more important than the rest if above 1
     * @param outPixels (optional) The destination pixels buffer
     * @return The final mixed pixels buffer
     */
    public static function mixPixelsBuffers(inPixelsList:Array<UInt8Array>, middleFactor:Float = 1, ?outPixels:UInt8Array):UInt8Array {

        assert(inPixelsList.length > 0, 'There should be at least one pixels buffer to mix');

        var numBuffers = inPixelsList.length;
        var length = inPixelsList.unsafeGet(0).length;

        if (outPixels == null) {
            outPixels = new UInt8Array(length);
        }

        var weight:Float = 0;
        var factors:Array<Float> = [];
        var factor:Float = 1;
        var i:Int = 0;
        var half:Int = Math.ceil(numBuffers*0.5);
        while (i < half) {
            factors[i] = factor;
            weight += factor;
            factor *= middleFactor;
            i++;
        }
        i = numBuffers - 1;
        factor = 1;
        while (i >= half) {
            factors[i] = factor;
            weight += factor;
            factor *= middleFactor;
            i--;
        }

        for (i in 0...length) {
            var total:Float = 0;
            for (n in 0...numBuffers) {
                total += inPixelsList.unsafeGet(n)[i] * factors.unsafeGet(n);
            }
            outPixels[i] = Math.round(total / weight);
        }

        return outPixels;

    }

    /**
     * Flip the given pixels buffer on the Y axis
     * @param buffer The pixel buffer to read from and write to
     * @param bufferWidth Image width
     */
    public static function flipY(buffer:UInt8Array, bufferWidth:Int):Void {

        var bufferHeight:Int = Std.int(buffer.length / (bufferWidth * 4));
        var halfHeight:Int = Std.int(bufferHeight * 0.5);
        var index0:Int = 0;
        var index1:Int = 0;
        var r:Int = 0;
        var g:Int = 0;
        var b:Int = 0;
        var a:Int = 0;

        for (y in 0...halfHeight) {
            for (x in 0...bufferWidth) {
                index0 = (y * bufferWidth + x) * 4;
                index1 = ((bufferHeight - 1 - y) * bufferWidth + x) * 4;
                r = buffer[index0];
                g = buffer[index0+1];
                b = buffer[index0+2];
                a = buffer[index0+3];
                buffer[index0] = buffer[index1];
                buffer[index0+1] = buffer[index1+1];
                buffer[index0+2] = buffer[index1+2];
                buffer[index0+3] = buffer[index1+3];
                buffer[index1] = r;
                buffer[index1+1] = g;
                buffer[index1+2] = b;
                buffer[index1+3] = a;
            }
        }

    }

    /**
     * Flip the given pixels buffer on the X axis
     * @param buffer The pixel buffer to read from and write to
     * @param bufferWidth Image width
     */
    public static function flipX(buffer:UInt8Array, bufferWidth:Int):Void {

        var bufferHeight:Int = Std.int(buffer.length / (bufferWidth * 4));
        var halfWidth:Int = Std.int(bufferWidth * 0.5);
        var index0:Int = 0;
        var index1:Int = 0;
        var r:Int = 0;
        var g:Int = 0;
        var b:Int = 0;
        var a:Int = 0;

        for (y in 0...bufferHeight) {
            for (x in 0...halfWidth) {
                index0 = (y * bufferWidth + x) * 4;
                index1 = (y * bufferWidth + bufferWidth - 1 - x) * 4;
                r = buffer[index0];
                g = buffer[index0+1];
                b = buffer[index0+2];
                a = buffer[index0+3];
                buffer[index0] = buffer[index1];
                buffer[index0+1] = buffer[index1+1];
                buffer[index0+2] = buffer[index1+2];
                buffer[index0+3] = buffer[index1+3];
                buffer[index1] = r;
                buffer[index1+1] = g;
                buffer[index1+2] = b;
                buffer[index1+3] = a;
            }
        }

    }

}
