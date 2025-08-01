package ceramic;

import ceramic.Assert.assert;
import haxe.io.Bytes;

using ceramic.Extensions;

/**
 * Utility class for manipulating raw RGBA pixel data.
 * 
 * Pixels provides low-level operations for working with pixel buffers in RGBA format.
 * Each pixel consists of 4 bytes: Red, Green, Blue, and Alpha channels (0-255 each).
 * This class is useful for:
 * - Image processing and filtering
 * - Procedural texture generation
 * - Pixel-perfect collision detection
 * - Screenshot capture and export
 * - Dynamic texture creation
 * 
 * Buffer format:
 * - Pixels are stored in row-major order (left to right, top to bottom)
 * - Each pixel uses 4 consecutive bytes: [R, G, B, A]
 * - Buffer index calculation: (y * width + x) * 4
 * 
 * @example
 * ```haxe
 * // Create a 100x100 red image
 * var pixels = Pixels.create(100, 100, AlphaColor.RED);
 * 
 * // Set a single pixel
 * Pixels.set(pixels, 100, 50, 50, AlphaColor.BLUE);
 * 
 * // Copy a region
 * Pixels.copy(srcPixels, srcWidth, dstPixels, dstWidth,
 *             0, 0, 50, 50,  // Source region
 *             25, 25);       // Destination position
 * 
 * // Export to PNG
 * Pixels.pixelsToPng(100, 100, pixels, "output.png", () -> {
 *     trace("PNG saved!");
 * });
 * ```
 * 
 * @see UInt8Array The underlying buffer type
 * @see AlphaColor For pixel color representation
 */
class Pixels {

    /**
     * Copies a rectangular region of pixels from one buffer to another.
     * 
     * This method performs a pixel-by-pixel copy with optional channel filtering.
     * It's useful for:
     * - Compositing multiple images
     * - Creating texture atlases
     * - Implementing copy/paste functionality
     * - Selective channel manipulation
     * 
     * The copy operation respects buffer boundaries and will not read/write
     * outside the valid pixel ranges.
     * 
     * @param srcBuffer Source pixel buffer in RGBA format
     * @param srcBufferWidth Width of the source image in pixels
     * @param dstBuffer Destination pixel buffer in RGBA format
     * @param dstBufferWidth Width of the destination image in pixels
     * @param srcX Starting X coordinate in source buffer
     * @param srcY Starting Y coordinate in source buffer
     * @param srcWidth Width of the region to copy
     * @param srcHeight Height of the region to copy
     * @param dstX Target X coordinate in destination buffer
     * @param dstY Target Y coordinate in destination buffer
     * @param copyRed Whether to copy the red channel (default: true)
     * @param copyGreen Whether to copy the green channel (default: true)
     * @param copyBlue Whether to copy the blue channel (default: true)
     * @param copyAlpha Whether to copy the alpha channel (default: true)
     * 
     * @example
     * ```haxe
     * // Copy entire image
     * Pixels.copy(src, 100, dst, 200, 0, 0, 100, 100, 50, 50);
     * 
     * // Copy only RGB channels (preserve destination alpha)
     * Pixels.copy(src, 100, dst, 200, 0, 0, 50, 50, 0, 0,
     *             true, true, true, false);
     * ```
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
     * Creates a new pixel buffer filled with the specified color.
     * 
     * Allocates a UInt8Array of size width × height × 4 bytes.
     * All pixels are initialized to the same color value.
     * 
     * @param width Width of the image in pixels
     * @param height Height of the image in pixels
     * @param fillColor Initial color for all pixels (including alpha)
     * @return New pixel buffer in RGBA format
     * 
     * @example
     * ```haxe
     * // Create transparent image
     * var pixels = Pixels.create(256, 256, AlphaColor.TRANSPARENT);
     * 
     * // Create opaque white background
     * var bg = Pixels.create(800, 600, AlphaColor.WHITE);
     * ```
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
     * Creates a pixel buffer from raw bytes in RGBA format.
     * 
     * Converts Haxe Bytes to a platform-specific UInt8Array.
     * The bytes must already be in RGBA format with 4 bytes per pixel.
     * 
     * @param bytes Raw bytes containing RGBA pixel data
     * @return Pixel buffer suitable for use with other Pixels methods
     * 
     * @example
     * ```haxe
     * var bytes = File.getBytes("raw_image.data");
     * var pixels = Pixels.fromBytes(bytes);
     * ```
     */
    public static function fromBytes(bytes:Bytes):UInt8Array {

        #if (cpp || js)
        return UInt8Array.fromBytes(bytes);
        #else
        return bytes.getData();
        #end

    }

    /**
     * Gets a single pixel color at the specified coordinates.
     * 
     * Reads 4 bytes from the buffer and returns them as an AlphaColor.
     * No bounds checking is performed for performance reasons.
     * 
     * @param buffer Pixel buffer to read from
     * @param bufferWidth Width of the image in pixels
     * @param x X coordinate (0 to width-1)
     * @param y Y coordinate (0 to height-1)
     * @return Color value at the specified position
     * 
     * @example
     * ```haxe
     * var color = Pixels.get(buffer, 100, 50, 25);
     * trace('Pixel alpha: ' + color.alpha);
     * ```
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
     * Sets a single pixel color at the specified coordinates.
     * 
     * Writes 4 bytes to the buffer from the AlphaColor components.
     * No bounds checking is performed for performance reasons.
     * 
     * @param buffer Pixel buffer to write to
     * @param bufferWidth Width of the image in pixels
     * @param x X coordinate (0 to width-1)
     * @param y Y coordinate (0 to height-1)
     * @param color Color value to set (including alpha)
     * 
     * @example
     * ```haxe
     * // Draw a red pixel
     * Pixels.set(buffer, 100, 50, 25, AlphaColor.RED);
     * 
     * // Set semi-transparent green
     * var color = AlphaColor.fromRGBA(0, 255, 0, 128);
     * Pixels.set(buffer, 100, 10, 10, color);
     * ```
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
     * Fills a rectangular area with a solid color.
     * 
     * Sets all pixels within the specified rectangle to the same color.
     * This is more efficient than setting pixels individually in a loop.
     * No bounds checking is performed.
     * 
     * @param buffer Pixel buffer to write to
     * @param bufferWidth Width of the image in pixels
     * @param x Left edge of rectangle (0 to width-1)
     * @param y Top edge of rectangle (0 to height-1)
     * @param width Width of rectangle in pixels
     * @param height Height of rectangle in pixels
     * @param color Color to fill the rectangle with (including alpha)
     * 
     * @example
     * ```haxe
     * // Draw a blue square
     * Pixels.setRectangle(buffer, 200, 50, 50, 100, 100, AlphaColor.BLUE);
     * 
     * // Clear a region to transparent
     * Pixels.setRectangle(buffer, 200, 0, 0, 200, 50, AlphaColor.TRANSPARENT);
     * ```
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
     * Exports pixel data as a PNG file to the specified path.
     * 
     * Encodes the raw RGBA pixel buffer as PNG format and saves it to disk.
     * The operation is asynchronous and calls the callback when complete.
     * 
     * @param width Width of the image in pixels
     * @param height Height of the image in pixels
     * @param pixels RGBA pixel buffer to encode
     * @param path File path where to save the PNG (e.g., "/path/to/image.png")
     * @param done Callback invoked when the export is complete
     * 
     * @example
     * ```haxe
     * var screenshot = Pixels.create(800, 600, AlphaColor.BLACK);
     * // ... draw to screenshot ...
     * Pixels.pixelsToPng(800, 600, screenshot, "screenshot.png", () -> {
     *     trace("Screenshot saved!");
     * });
     * ```
     */
    static inline extern overload public function pixelsToPng(width:Int, height:Int, pixels:UInt8Array, path:String, done:()->Void):Void {
        _pixelsToPng(width, height, pixels, path, (?data) -> {
            done();
        });
    }

    /**
     * Exports pixel data as PNG bytes in memory.
     * 
     * Encodes the raw RGBA pixel buffer as PNG format and returns the bytes.
     * Useful for network transmission or further processing without disk I/O.
     * 
     * @param width Width of the image in pixels
     * @param height Height of the image in pixels
     * @param pixels RGBA pixel buffer to encode
     * @param done Callback invoked with the PNG data as Bytes
     * 
     * @example
     * ```haxe
     * Pixels.pixelsToPng(256, 256, pixels, (pngBytes) -> {
     *     // Send PNG over network
     *     socket.write(pngBytes);
     *     // Or encode as base64
     *     var base64 = haxe.crypto.Base64.encode(pngBytes);
     * });
     * ```
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
     * Converts RGBA pixel data to RGB format by stripping alpha channel.
     * 
     * Creates a new buffer with 3 bytes per pixel instead of 4.
     * Useful for formats that don't support transparency or to reduce memory usage.
     * 
     * @param width Width of the image in pixels
     * @param height Height of the image in pixels
     * @param inPixels Source RGBA pixel buffer (4 bytes per pixel)
     * @param outPixels Optional destination buffer to reuse.
     *                  Must be exactly width × height × 3 bytes.
     *                  If null or wrong size, a new buffer is created.
     * @return RGB pixel buffer (3 bytes per pixel)
     * 
     * @example
     * ```haxe
     * // Convert for JPEG encoding (no alpha support)
     * var rgbPixels = Pixels.rgbaPixelsToRgbPixels(100, 100, rgbaPixels);
     * ```
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
     * Converts RGB pixel data to RGBA format by adding an alpha channel.
     * 
     * Expands the buffer from 3 bytes per pixel to 4 bytes per pixel.
     * All pixels receive the same alpha value.
     * 
     * @param width Width of the image in pixels
     * @param height Height of the image in pixels
     * @param alpha Alpha value to add to all pixels (0-255, default: 255 for opaque)
     * @param inPixels Source RGB pixel buffer (3 bytes per pixel)
     * @param outPixels Optional destination buffer to reuse.
     *                  Must be exactly width × height × 4 bytes.
     *                  If null or wrong size, a new buffer is created.
     * @return RGBA pixel buffer (4 bytes per pixel)
     * 
     * @example
     * ```haxe
     * // Convert RGB to opaque RGBA
     * var rgbaPixels = Pixels.rgbPixelsToRgbaPixels(100, 100, 255, rgbPixels);
     * 
     * // Convert with 50% transparency
     * var semiTransparent = Pixels.rgbPixelsToRgbaPixels(100, 100, 128, rgbPixels);
     * ```
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
     * Blends multiple pixel buffers into a single weighted average.
     * 
     * Combines multiple images using weighted averaging, with optional emphasis
     * on middle buffers. This is useful for:
     * - Creating smooth transitions between frames
     * - Temporal anti-aliasing
     * - Motion blur effects
     * - Image stacking for noise reduction
     * 
     * The weight distribution forms a pyramid shape when middleFactor > 1:
     * - First and last buffers have weight 1
     * - Middle buffers have weight multiplied by middleFactor
     * 
     * @param inPixelsList Array of pixel buffers to mix. All must have same dimensions.
     * @param middleFactor Weight multiplier for middle buffers.
     *                     - 1.0: Equal weighting for all buffers
     *                     - >1.0: Emphasize middle buffers
     *                     - <1.0: Emphasize edge buffers
     * @param outPixels Optional destination buffer to reuse.
     *                  Must match size of input buffers.
     * @return Mixed pixel buffer with weighted average of inputs
     * 
     * @throws String If inPixelsList is empty
     * 
     * @example
     * ```haxe
     * // Blend 5 frames for motion blur
     * var frames = [frame1, frame2, frame3, frame4, frame5];
     * var blurred = Pixels.mixPixelsBuffers(frames, 2.0);
     * // Result weights: [1, 2, 4, 2, 1] normalized
     * ```
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
     * Flips an image vertically (upside down) in-place.
     * 
     * Swaps pixel rows from top to bottom. The top row becomes the bottom row,
     * the second row becomes the second-to-last row, etc.
     * 
     * This operation modifies the buffer directly without allocating new memory.
     * 
     * @param buffer Pixel buffer to flip. Modified in-place.
     * @param bufferWidth Width of the image in pixels.
     *                    Height is calculated from buffer.length / (width × 4).
     * 
     * @example
     * ```haxe
     * // Flip image loaded from file (often needed for OpenGL)
     * var pixels = loadImagePixels("texture.png");
     * Pixels.flipY(pixels, 256);
     * ```
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
     * Flips an image horizontally (mirror) in-place.
     * 
     * Swaps pixel columns from left to right. The leftmost column becomes
     * the rightmost column, etc.
     * 
     * This operation modifies the buffer directly without allocating new memory.
     * 
     * @param buffer Pixel buffer to flip. Modified in-place.
     * @param bufferWidth Width of the image in pixels.
     *                    Height is calculated from buffer.length / (width × 4).
     * 
     * @example
     * ```haxe
     * // Create mirror image
     * var pixels = loadImagePixels("character.png");
     * Pixels.flipX(pixels, 64);
     * // Character now faces opposite direction
     * ```
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
