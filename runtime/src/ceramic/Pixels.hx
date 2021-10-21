package ceramic;

import haxe.io.Bytes;

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

}
