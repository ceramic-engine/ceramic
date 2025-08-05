package ceramic;

/**
 * Utilities for converting between straight and premultiplied alpha in image data.
 * 
 * Premultiplied alpha is a technique where RGB color values are multiplied by their
 * alpha channel value before storage or rendering. This is crucial for correct
 * alpha blending in GPU rendering pipelines.
 * 
 * In premultiplied alpha:
 * - RGB values are scaled by alpha: (R*A, G*A, B*A, A)
 * - Fully transparent pixels have RGB values of (0, 0, 0, 0)
 * - Prevents color bleeding artifacts during filtering
 * - Required by many GPU blend modes for correct results
 * 
 * In straight (non-premultiplied) alpha:
 * - RGB values are stored independently of alpha: (R, G, B, A)
 * - Transparent pixels can have any RGB values
 * - More intuitive for image editing
 * - Used by most image file formats
 * 
 * ```haxe
 * // Load image pixels
 * var pixels = texture.fetchPixels();
 * 
 * // Convert to premultiplied for GPU rendering
 * PremultiplyAlpha.premultiplyAlpha(pixels);
 * 
 * // Convert back to straight alpha for saving
 * PremultiplyAlpha.reversePremultiplyAlpha(pixels);
 * texture.saveToFile("output.png");
 * ```
 * 
 * @see Texture.fetchPixels For accessing pixel data
 * @see Blending For alpha blending modes
 */
class PremultiplyAlpha {

    /**
     * Converts pixel data from straight alpha to premultiplied alpha format.
     * 
     * Multiplies each RGB component by its corresponding alpha value.
     * This operation modifies the pixel data in-place for efficiency.
     * 
     * The conversion formula for each pixel:
     * - R' = R * (A / 255)
     * - G' = G * (A / 255)
     * - B' = B * (A / 255)
     * - A' = A (unchanged)
     * 
     * @param pixels The pixel data array in RGBA format (4 bytes per pixel).
     *               Must have length divisible by 4. Modified in-place.
     * 
     * ```haxe
     * // Prepare pixels for GPU rendering
     * var pixels = loadImagePixels("sprite.png");
     * PremultiplyAlpha.premultiplyAlpha(pixels);
     * var texture = Texture.fromPixels(width, height, pixels);
     * ```
     */
    public static function premultiplyAlpha(pixels:UInt8Array) {

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

    /**
     * Converts pixel data from premultiplied alpha back to straight alpha format.
     * 
     * Divides each RGB component by its alpha value to restore original colors.
     * This operation modifies the pixel data in-place for efficiency.
     * Pixels with zero alpha are left unchanged to avoid division by zero.
     * 
     * The conversion formula for each pixel (when A > 0):
     * - R' = R / (A / 255)
     * - G' = G / (A / 255)
     * - B' = B / (A / 255)
     * - A' = A (unchanged)
     * 
     * @param pixels The pixel data array in premultiplied RGBA format.
     *               Must have length divisible by 4. Modified in-place.
     * 
     * ```haxe
     * // Convert back for image editing or saving
     * var pixels = texture.fetchPixels();
     * PremultiplyAlpha.reversePremultiplyAlpha(pixels);
     * savePixelsAsPNG(pixels, "output.png");
     * ```
     * 
     * Note: Due to rounding during premultiplication, this operation
     * may not perfectly restore original values, especially for
     * low alpha values.
     */
    public static function reversePremultiplyAlpha(pixels:UInt8Array) {

        var count = pixels.length;
        var index = 0;

        while (index < count) {

            var r = pixels[index+0];
            var g = pixels[index+1];
            var b = pixels[index+2];
            var a = pixels[index+3] / 255.0;

            if (a > 0) {
                pixels[index+0] = Std.int(r/a);
                pixels[index+1] = Std.int(g/a);
                pixels[index+2] = Std.int(b/a);
            }

            index += 4;

        }

    }

}