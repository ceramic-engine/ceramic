// Ported from gpui-pre-web 0.3.10: src/canvas_text.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic; the browser calls are
// behind `CanvasTextBackend` so the rest runs (and is tested) on every target.
// See NOTICE.md.
package gpui.platform;

import haxe.io.Bytes;

/**
 * Text metrics measured by the browser (Rust `CanvasTextMetrics`), in
 * pixels at the measured font size (f32 values).
 */
class CanvasTextMetrics {

    public final advance:Float;

    public final left:Float;

    public final right:Float;

    public final ascent:Float;

    public final descent:Float;

    public function new(advance:Float, left:Float, right:Float, ascent:Float, descent:Float) {
        this.advance = advance;
        this.left = left;
        this.right = right;
        this.ascent = ascent;
        this.descent = descent;
    }

    public function toString():String {
        return 'CanvasTextMetrics(advance: $advance, left: $left, right: $right, ascent: $ascent, descent: $descent)';
    }

}

/**
 * The Canvas2D calls of `CanvasText`: a browser `OffscreenCanvas`
 * (`BrowserCanvasText`), or a fake in tests.
 */
interface CanvasTextBackend {

    /**
     * Measures `text` with the CSS font `cssFont` (`measureText`): fills
     * `result` with `width`, `actualBoundingBoxLeft`,
     * `actualBoundingBoxRight`, `actualBoundingBoxAscent` and
     * `actualBoundingBoxDescent`, as returned by the browser.
     */
    function measureText(text:String, cssFont:String, result:Array<Float>):Void;

    /**
     * Draws `text` in white with `fillText` at (`x`, `y`) on a cleared canvas
     * of `width` x `height` pixels (left aligned, alphabetic baseline, left
     * to right), and returns its pixels (`getImageData`: RGBA, straight
     * alpha, 4 bytes per pixel).
     */
    function fillText(text:String, cssFont:String, width:Int, height:Int, x:Float, y:Float):Bytes;

}

/**
 * Measures and rasterizes graphemes with the fonts of the browser (Rust
 * `canvas_text::measure` and `canvas_text::rasterize`).
 */
class CanvasText {

    public static inline final MAX_RASTER_DIMENSION:Int = 4096;

    public static inline final MAX_RASTER_PIXELS:Int = 4 * 1024 * 1024;

    static final measured:Array<Float> = [0, 0, 0, 0, 0];

    /** Rust `canvas_text::measure` */
    public static function measure(backend:CanvasTextBackend, text:String, cssFont:String):CanvasTextMetrics {
        if (StringTools.trim(cssFont).length == 0)
            throw 'Canvas text font is empty';
        backend.measureText(text, cssFont, measured);
        final metrics = new CanvasTextMetrics(
            f32(measured[0]),
            f32(-measured[1]),
            f32(measured[2]),
            f32(measured[3]),
            f32(measured[4])
        );
        for (value in [metrics.advance, metrics.left, metrics.right, metrics.ascent, metrics.descent]) {
            if (!Math.isFinite(value))
                throw 'Canvas returned non-finite text metrics';
        }
        return metrics;
    }

    /**
     * Rust `canvas_text::rasterize`: draws `text` so that the pixel at the
     * origin of `bounds` (device pixels, y down from the baseline) is the
     * first one of the result, at the given subpixel offset. Returns the
     * alpha mask (1 byte per pixel), or straight alpha BGRA pixels when
     * `color` is set (polychrome sprites).
     */
    public static function rasterize(backend:CanvasTextBackend, text:String, cssFont:String, bounds:Bounds, subpixelOffsetX:Float, subpixelOffsetY:Float, color:Bool):Bytes {
        if (!Math.isFinite(subpixelOffsetX) || !Math.isFinite(subpixelOffsetY))
            throw 'Canvas text subpixel offset must be finite';
        final w:Float = bounds.size.width;
        final h:Float = bounds.size.height;
        if (w < 0)
            throw 'Canvas text raster width must be nonnegative';
        if (h < 0)
            throw 'Canvas text raster height must be nonnegative';
        final width = Std.int(w);
        final height = Std.int(h);
        if (width == 0 || height == 0)
            return Bytes.alloc(0);
        if (width > MAX_RASTER_DIMENSION || height > MAX_RASTER_DIMENSION)
            throw 'Canvas text raster exceeds maximum dimension $MAX_RASTER_DIMENSION: ${width}x$height';
        final pixelCount = width * height;
        if (pixelCount > MAX_RASTER_PIXELS)
            throw 'Canvas text raster exceeds maximum pixel count $MAX_RASTER_PIXELS: ${width}x$height';
        final byteCount = pixelCount * 4;
        if (StringTools.trim(cssFont).length == 0)
            throw 'Canvas text font is empty';

        final x:Float = -(bounds.origin.x:Float) + subpixelOffsetX;
        final y:Float = -(bounds.origin.y:Float) + subpixelOffsetY;
        final pixels = backend.fillText(text, cssFont, width, height, x, y);
        if (pixels.length != byteCount)
            throw 'Canvas text raster returned ${pixels.length} bytes, expected $byteCount';
        if (color) {
            // RGBA to BGRA
            var i = 0;
            while (i < byteCount) {
                final r = pixels.get(i);
                pixels.set(i, pixels.get(i + 2));
                pixels.set(i + 2, r);
                i += 4;
            }
            return pixels;
        }
        else {
            final alpha = Bytes.alloc(pixelCount);
            for (p in 0...pixelCount)
                alpha.set(p, pixels.get(p * 4 + 3));
            return alpha;
        }
    }

    static inline function f32(value:Float):Float {
        return ttf.shape.Shaper.f32(value);
    }

}

#if js
/**
 * `CanvasTextBackend` over a browser `OffscreenCanvas` 2D context (Rust
 * `TextCanvas`), created on first use. Only in browsers (clay web,
 * Electron): `BrowserCanvasText.available()` is false elsewhere (node).
 */
class BrowserCanvasText implements CanvasTextBackend {

    var canvas:Dynamic = null;

    var context:Dynamic = null;

    /** Whether the browser can draw text on an `OffscreenCanvas` */
    public static function available():Bool {
        return js.Browser.supported && js.Syntax.code('typeof OffscreenCanvas !== "undefined"');
    }

    public function new() {}

    function ensureCanvas():Void {
        if (context != null)
            return;
        if (!available())
            throw 'OffscreenCanvas 2D text rendering is unavailable';
        canvas = js.Syntax.code('new OffscreenCanvas(1, 1)');
        // Every rasterized glyph is read back for upload into GPUI's atlas.
        context = canvas.getContext('2d', {willReadFrequently: true});
        if (context == null)
            throw 'OffscreenCanvas 2D text rendering is unavailable';
    }

    function configure(cssFont:String):Void {
        if (StringTools.trim(cssFont).length == 0)
            throw 'Canvas text font is empty';
        // An invalid CSS font assignment is ignored by Canvas. Reset first so
        // it cannot accidentally inherit the preceding request's font.
        context.font = '10px sans-serif';
        context.font = cssFont;
        context.textAlign = 'left';
        context.textBaseline = 'alphabetic';
        context.fillStyle = 'white';
        context.direction = 'ltr';
    }

    public function measureText(text:String, cssFont:String, result:Array<Float>):Void {
        ensureCanvas();
        configure(cssFont);
        final metrics:Dynamic = context.measureText(text);
        result[0] = metrics.width;
        result[1] = metrics.actualBoundingBoxLeft;
        result[2] = metrics.actualBoundingBoxRight;
        result[3] = metrics.actualBoundingBoxAscent;
        result[4] = metrics.actualBoundingBoxDescent;
    }

    public function fillText(text:String, cssFont:String, width:Int, height:Int, x:Float, y:Float):Bytes {
        ensureCanvas();
        // Shrink before growing so intermediate canvas sizes obey the pixel cap.
        if (height < (canvas.height:Int))
            canvas.height = height;
        if ((canvas.width:Int) != width)
            canvas.width = width;
        if ((canvas.height:Int) != height)
            canvas.height = height;
        configure(cssFont);
        context.clearRect(0.0, 0.0, width, height);
        context.fillText(text, x, y);
        final image:Dynamic = context.getImageData(0.0, 0.0, width, height);
        final data:js.lib.Uint8ClampedArray = image.data;
        return Bytes.ofData(data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength));
    }

}
#end
