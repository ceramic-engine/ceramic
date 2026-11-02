// Original code (not a port), written for the Ceramic vector plugin.
// MIT License, see Ceramic's LICENSE file.
package ceramic;

import ceramic.Shortcuts.*;

/**
 * Helpers converting plutovg surfaces and lunasvg documents into Ceramic textures.
 *
 * plutovg (and lunasvg, which renders with it) produces premultiplied ARGB
 * pixels: one 32-bit `0xAARRGGBB` value per pixel, stored as B, G, R, A bytes.
 * Ceramic textures expect premultiplied RGBA bytes (R, G, B, A). Only the red
 * and blue channels are swapped: the values are not unpremultiplied.
 *
 * ```haxe
 * var surface = plutovg.Surface.create(64, 64);
 * var canvas = new plutovg.Canvas(surface);
 * canvas.circle(32, 32, 30);
 * canvas.setRgb(1, 0.5, 0);
 * canvas.fill();
 * quad.texture = VectorTextures.textureFromSurface(surface);
 * ```
 */
class VectorTextures {

    /**
     * Converts the premultiplied ARGB pixels of `surface` into premultiplied
     * RGBA bytes, as expected by `Texture.fromPixels()` and `Texture.submitPixels()`.
     * @param surface The plutovg surface to read
     * @param result An optional buffer of `width * height * 4` bytes to reuse
     * @return The RGBA pixels (`result` when given and large enough)
     */
    public static function surfaceToPixels(surface:plutovg.Surface, ?result:UInt8Array):UInt8Array {

        final width = surface.width;
        final height = surface.height;
        final stride = surface.stride;
        final data = surface.data;
        final size = width * height * 4;

        if (result == null || result.length < size)
            result = new UInt8Array(size);

        var o = 0;
        for (y in 0...height) {
            var i = y * stride;
            final end = i + width * 4;
            while (i < end) {
                result[o] = data.get(i + 2);
                result[o + 1] = data.get(i + 1);
                result[o + 2] = data.get(i);
                result[o + 3] = data.get(i + 3);
                i += 4;
                o += 4;
            }
        }

        return result;

    }

    /**
     * Creates a texture from a plutovg surface, or updates `reuse` in place when
     * it has the same pixel size (the texture is then returned unchanged).
     * @param surface The plutovg surface to upload
     * @param density Texture density: the logical size is the pixel size divided by it
     * @param reuse An existing texture to update if its pixel size matches
     * @return The texture holding the surface pixels
     */
    public static function textureFromSurface(surface:plutovg.Surface, density:Float = 1, ?reuse:Texture):Texture {

        final pixels = surfaceToPixels(surface);

        if (reuse != null && !reuse.destroyed
            && reuse.nativeWidth == surface.width
            && reuse.nativeHeight == surface.height
            && reuse.density == density) {
            reuse.submitPixels(pixels);
            return reuse;
        }

        return Texture.fromPixels(surface.width / density, surface.height / density, pixels, density);

    }

    /**
     * Rasterizes an SVG document at `width` x `height` logical units and `density`,
     * into a new texture (or into `reuse` when it has the same pixel size).
     *
     * The pixel size is `round(width * density)` x `round(height * density)` and
     * the document is rendered with `Document.renderToBitmap()` at that size, so the
     * pixels are exactly what lunasvg produces. A size below or equal to zero is
     * computed from the intrinsic size of the document (keeping its aspect ratio
     * when the other size is given).
     * @param document The SVG document
     * @param width Logical width (-1 for automatic)
     * @param height Logical height (-1 for automatic)
     * @param density Pixels per logical unit (-1 for `screen.texturesDensity`)
     * @param reuse An existing texture to update if its pixel size matches
     * @return The texture, or null if the document has no size
     */
    public static function textureFromSvg(document:lunasvg.Document, width:Float = -1, height:Float = -1, density:Float = -1, ?reuse:Texture):Texture {

        if (density <= 0)
            density = screen.texturesDensity;

        final size = svgPixelSize(document, width, height, density);
        if (size == null)
            return null;

        final bitmap = document.renderToBitmap(size.width, size.height);
        if (bitmap.isNull())
            return null;

        return textureFromSurface(bitmap.surface(), density, reuse);

    }

    /**
     * Computes the pixel size used to rasterize `document` at the given logical
     * size and density (see `textureFromSvg()`). Returns null if the document
     * has no intrinsic size and no explicit size is given.
     */
    public static function svgPixelSize(document:lunasvg.Document, width:Float, height:Float, density:Float):{width:Int, height:Int} {

        var w = width > 0 ? Math.round(width * density) : 0;
        var h = height > 0 ? Math.round(height * density) : 0;

        if (w <= 0 || h <= 0) {
            final intrinsicWidth = document.width();
            final intrinsicHeight = document.height();
            if (intrinsicWidth <= 0 || intrinsicHeight <= 0)
                return null;
            if (w <= 0 && h <= 0) {
                w = Math.round(intrinsicWidth * density);
                h = Math.round(intrinsicHeight * density);
            }
            else if (w <= 0) {
                w = Math.round(h * intrinsicWidth / intrinsicHeight);
            }
            else {
                h = Math.round(w * intrinsicHeight / intrinsicWidth);
            }
        }

        if (w <= 0) w = 1;
        if (h <= 0) h = 1;

        return { width: w, height: h };

    }

}
