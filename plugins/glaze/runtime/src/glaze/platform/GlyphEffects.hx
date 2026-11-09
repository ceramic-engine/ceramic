// Original code for Glaze (not a port): glyph outlines with a synthetic oblique
// and a stem dilation, rendered like ttf.GlyphRasterizer renders the plain ones.
package glaze.platform;

import haxe.io.Bytes;
import ttf.GlyphRasterizer.GlyphBitmap;
import ttf.GrayRaster;
import ttf.OutlineSink;

/**
 * Renders glyphs with two outline effects that `ttf.GlyphRasterizer` does
 * not have, using the same scaling, placement and scan converter:
 *
 * - `skewX`: a synthetic oblique, `x += skewX * y` (pixels, y up from the
 *   baseline), like a browser draws an italic run of a family without an
 *   italic face (Skia's `setSkewX(-1/4)` in y down coordinates is
 *   `skewX = 0.25`). The advances do not change.
 * - `dilation`: stems made thicker by `dilation` pixels in total (half on
 *   each side), by moving every point of the outline along the bisector of
 *   its two edges (FreeType's `FT_Outline_EmboldenXY`, made symmetric so the
 *   glyph does not move): what CoreGraphics does to glyphs when font
 *   smoothing is on (see `FontSmoothing`).
 *
 * With both at 0 the result is the one of `ttf.GlyphRasterizer`. The
 * outline is scaled to pixels first (26.6 fixed point for TrueType, like
 * the plain rendering), then dilated, then skewed. Scratch buffers are
 * reused: one instance per text system.
 */
class GlyphEffects {

    /** The horizontal shear of the synthetic oblique (0: none). */
    public var skewX:Float = 0;

    /** The total stem dilation in pixels (0: none). */
    public var dilation:Float = 0;

    final raster:GrayRaster = new GrayRaster();
    final path:RecordedOutline = new RecordedOutline();
    final cff:CffScaledSink = new CffScaledSink();

    public function new() {}

    /**
     * Whether `skewX` or `dilation` changes the outline.
     */
    public inline function active():Bool {
        return skewX != 0 || dilation != 0;
    }

    /**
     * Scales, dilates and skews the outline of a glyph into `path`. Returns
     * false when the glyph has no outline.
     */
    function prepare(font:ttf.Font, gid:Int, fontSize:Float):Bool {
        path.reset();
        var ok = false;
        if (!font.isCff) {
            ok = font.outlineScaled(gid, fontSize, path);
        }
        else {
            cff.target = path;
            cff.scale = fontSize / font.unitsPerEm;
            ok = font.outline(gid, cff);
        }
        if (!ok || path.count == 0)
            return false;
        if (dilation != 0)
            path.embolden(dilation * 0.5);
        if (skewX != 0)
            path.skew(skewX);
        return true;
    }

    /**
     * The pixel bounds of the transformed glyph at `fontSize` pixels per em
     * with the subpixel offset (like `GlyphRasterizer.rasterBounds`).
     */
    public function rasterBounds(font:ttf.Font, gid:Int, fontSize:Float, subpixelX:Float, subpixelY:Float, out:GlyphBitmap):GlyphBitmap {
        out.data = null;
        if (!prepare(font, gid, fontSize)) {
            out.width = out.height = out.left = out.top = 0;
            return out;
        }
        placeBounds(subpixelX, subpixelY, out);
        return out;
    }

    function placeBounds(subpixelX:Float, subpixelY:Float, out:GlyphBitmap):Void {
        final left = Math.floor(path.xMin + subpixelX);
        final right = Math.ceil(path.xMax + subpixelX);
        final bottom = Math.floor(path.yMin + subpixelY);
        final top = Math.ceil(path.yMax + subpixelY);
        if (right <= left || top <= bottom) {
            out.width = out.height = out.left = out.top = 0;
            return;
        }
        out.left = left;
        out.top = top;
        out.width = right - left;
        out.height = top - bottom;
    }

    /**
     * Renders the transformed glyph (like `GlyphRasterizer.rasterize`).
     * `out.data` is reused when it is large enough.
     */
    public function rasterize(font:ttf.Font, gid:Int, fontSize:Float, subpixelX:Float, subpixelY:Float, out:GlyphBitmap):GlyphBitmap {
        out.data = null;
        if (!prepare(font, gid, fontSize)) {
            out.width = out.height = out.left = out.top = 0;
            return out;
        }
        placeBounds(subpixelX, subpixelY, out);
        final width = out.width;
        final height = out.height;
        if (width <= 0 || height <= 0)
            return out;
        final size = width * height;
        var buffer = scratch;
        if (buffer == null || buffer.length < size) {
            buffer = Bytes.alloc(size);
            scratch = buffer;
        }
        buffer.fill(0, size, 0);
        out.data = buffer;
        raster.reset(width, height);
        path.replay(raster, subpixelX - out.left, subpixelY + height - out.top);
        raster.render(buffer, 0, width);
        return out;
    }

    var scratch:Null<Bytes> = null;

    /**
     * The length of the transformed outline in pixels (0 without outline),
     * used to calibrate the dilation.
     */
    public function outlineLength(font:ttf.Font, gid:Int, fontSize:Float):Float {
        return prepare(font, gid, fontSize) ? path.length() : 0;
    }

}

/**
 * An outline recorded as commands and points (pixels, y up), with the
 * control box of its points.
 */
private class RecordedOutline implements OutlineSink {

    static inline final MOVE = 0;
    static inline final LINE = 1;
    static inline final QUAD = 2;
    static inline final CUBIC = 3;
    static inline final CLOSE = 4;

    /** One entry per command */
    final ops:Array<Int> = [];

    /** The points of the commands, two numbers each */
    final xs:Array<Float> = [];
    final ys:Array<Float> = [];

    /** Index of the first point of each contour, and its end (exclusive) */
    final contourStarts:Array<Int> = [];
    final contourEnds:Array<Int> = [];

    /** Number of commands */
    public var count(default, null):Int = 0;

    var points:Int = 0;

    public var xMin:Float = 0;
    public var yMin:Float = 0;
    public var xMax:Float = 0;
    public var yMax:Float = 0;

    /** Scratch shifts of the dilation */
    final shiftX:Array<Float> = [];
    final shiftY:Array<Float> = [];

    public function new() {}

    public function reset():Void {
        count = 0;
        points = 0;
        contourStarts.resize(0);
        contourEnds.resize(0);
    }

    inline function op(code:Int):Void {
        if (count < ops.length)
            ops[count] = code;
        else
            ops.push(code);
        count++;
    }

    inline function point(x:Float, y:Float):Void {
        if (points < xs.length) {
            xs[points] = x;
            ys[points] = y;
        }
        else {
            xs.push(x);
            ys.push(y);
        }
        points++;
    }

    function endContour():Void {
        if (contourStarts.length > contourEnds.length)
            contourEnds.push(points);
    }

    public function moveTo(x:Float, y:Float):Void {
        endContour();
        contourStarts.push(points);
        op(MOVE);
        point(x, y);
    }

    public function lineTo(x:Float, y:Float):Void {
        op(LINE);
        point(x, y);
    }

    public function quadTo(cx:Float, cy:Float, x:Float, y:Float):Void {
        op(QUAD);
        point(cx, cy);
        point(x, y);
    }

    public function cubicTo(c1x:Float, c1y:Float, c2x:Float, c2y:Float, x:Float, y:Float):Void {
        op(CUBIC);
        point(c1x, c1y);
        point(c2x, c2y);
        point(x, y);
    }

    public function close():Void {
        endContour();
        op(CLOSE);
        updateBounds();
    }

    function updateBounds():Void {
        if (points == 0) {
            xMin = yMin = xMax = yMax = 0;
            return;
        }
        xMin = xMax = xs[0];
        yMin = yMax = ys[0];
        for (i in 1...points) {
            final x = xs[i];
            final y = ys[i];
            if (x < xMin) xMin = x;
            if (x > xMax) xMax = x;
            if (y < yMin) yMin = y;
            if (y > yMax) yMax = y;
        }
    }

    /**
     * `x += k * y` for every point.
     */
    public function skew(k:Float):Void {
        for (i in 0...points)
            xs[i] += k * ys[i];
        updateBounds();
    }

    /**
     * Moves every point by `strength` pixels outward along the bisector of
     * its edges (FreeType's `FT_Outline_EmboldenXY` with the same strength
     * in x and y, without its shift of the whole outline).
     */
    public function embolden(strength:Float):Void {
        endContour();
        // Orientation: the signed area of the control polygons (TrueType
        // outer contours are clockwise in y up, CFF ones counterclockwise)
        var area = 0.0;
        for (c in 0...contourStarts.length) {
            final first = contourStarts[c];
            final last = contourEnds[c] - 1;
            if (last <= first)
                continue;
            var j = last;
            for (i in first...last + 1) {
                area += (xs[j] - xs[i]) * (ys[j] + ys[i]);
                j = i;
            }
        }
        if (area == 0)
            return;
        // area < 0: clockwise (FT_ORIENTATION_TRUETYPE)
        final clockwise = area < 0;
        while (shiftX.length < points) {
            shiftX.push(0);
            shiftY.push(0);
        }
        for (c in 0...contourStarts.length) {
            final first = contourStarts[c];
            var last = contourEnds[c] - 1;
            // a closing point equal to the first one is not a vertex of its own
            while (last > first && xs[last] == xs[first] && ys[last] == ys[first])
                last--;
            if (last <= first) {
                for (i in contourStarts[c]...contourEnds[c]) {
                    shiftX[i] = 0;
                    shiftY[i] = 0;
                }
                continue;
            }
            final n = last - first + 1;
            for (k in 0...n) {
                final i = first + k;
                // previous and next distinct points
                var p = k;
                var inX = 0.0, inY = 0.0, lIn = 0.0;
                for (_ in 0...n) {
                    p = p == 0 ? n - 1 : p - 1;
                    inX = xs[i] - xs[first + p];
                    inY = ys[i] - ys[first + p];
                    lIn = Math.sqrt(inX * inX + inY * inY);
                    if (lIn > 0)
                        break;
                }
                var q = k;
                var outX = 0.0, outY = 0.0, lOut = 0.0;
                for (_ in 0...n) {
                    q = q == n - 1 ? 0 : q + 1;
                    outX = xs[first + q] - xs[i];
                    outY = ys[first + q] - ys[i];
                    lOut = Math.sqrt(outX * outX + outY * outY);
                    if (lOut > 0)
                        break;
                }
                var sx = 0.0, sy = 0.0;
                if (lIn > 0 && lOut > 0) {
                    inX /= lIn;
                    inY /= lIn;
                    outX /= lOut;
                    outY /= lOut;
                    var d = inX * outX + inY * outY;
                    // shift only if the turn is less than about 160 degrees
                    if (d > -0.9375) {
                        d = d + 1;
                        sx = inY + outY;
                        sy = inX + outX;
                        if (clockwise)
                            sx = -sx;
                        else
                            sy = -sy;
                        var s = outX * inY - outY * inX;
                        if (clockwise)
                            s = -s;
                        final l = lIn < lOut ? lIn : lOut;
                        if (strength * s <= l * d) {
                            sx = sx * strength / d;
                            sy = sy * strength / d;
                        }
                        else {
                            sx = sx * l / s;
                            sy = sy * l / s;
                        }
                    }
                }
                shiftX[i] = sx;
                shiftY[i] = sy;
            }
            for (i in last + 1...contourEnds[c]) {
                // repeated closing points follow the first one
                shiftX[i] = shiftX[first];
                shiftY[i] = shiftY[first];
            }
        }
        for (c in 0...contourStarts.length) {
            for (i in contourStarts[c]...contourEnds[c]) {
                xs[i] += shiftX[i];
                ys[i] += shiftY[i];
            }
        }
        updateBounds();
    }

    /**
     * Feeds the outline to `raster`, shifted.
     */
    public function replay(raster:GrayRaster, dx:Float, dy:Float):Void {
        var p = 0;
        for (i in 0...count) {
            switch ops[i] {
                case MOVE:
                    raster.moveTo(xs[p] + dx, ys[p] + dy);
                    p++;
                case LINE:
                    raster.lineTo(xs[p] + dx, ys[p] + dy);
                    p++;
                case QUAD:
                    raster.quadTo(xs[p] + dx, ys[p] + dy, xs[p + 1] + dx, ys[p + 1] + dy);
                    p += 2;
                case CUBIC:
                    raster.cubicTo(xs[p] + dx, ys[p] + dy, xs[p + 1] + dx, ys[p + 1] + dy, xs[p + 2] + dx, ys[p + 2] + dy);
                    p += 3;
                case _:
                    raster.close();
            }
        }
    }

    /**
     * The length of the outline in pixels (curves flattened), for the
     * calibration of the dilation.
     */
    public function length():Float {
        var total = 0.0;
        var p = 0;
        var cx = 0.0, cy = 0.0, sx = 0.0, sy = 0.0;
        inline function seg(x:Float, y:Float) {
            total += Math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
            cx = x;
            cy = y;
        }
        for (i in 0...count) {
            switch ops[i] {
                case MOVE:
                    cx = sx = xs[p];
                    cy = sy = ys[p];
                    p++;
                case LINE:
                    seg(xs[p], ys[p]);
                    p++;
                case QUAD:
                    final x0 = cx, y0 = cy;
                    for (s in 1...17) {
                        final t = s / 16, u = 1 - t;
                        seg(u * u * x0 + 2 * u * t * xs[p] + t * t * xs[p + 1], u * u * y0 + 2 * u * t * ys[p] + t * t * ys[p + 1]);
                    }
                    p += 2;
                case CUBIC:
                    final x0 = cx, y0 = cy;
                    for (s in 1...17) {
                        final t = s / 16, u = 1 - t;
                        seg(u * u * u * x0 + 3 * u * u * t * xs[p] + 3 * u * t * t * xs[p + 1] + t * t * t * xs[p + 2],
                            u * u * u * y0 + 3 * u * u * t * ys[p] + 3 * u * t * t * ys[p + 1] + t * t * t * ys[p + 2]);
                    }
                    p += 3;
                case _:
                    seg(sx, sy);
            }
        }
        return total;
    }

}

/** Scales font units to pixels rounded to 1/64 (CFF outlines, like `ttf.GlyphRasterizer`). */
private class CffScaledSink implements OutlineSink {

    public var target:Null<OutlineSink> = null;

    public var scale:Float = 1;

    public function new() {}

    inline function s(v:Float):Float {
        return Math.round(v * scale * 64) / 64;
    }

    public function moveTo(x:Float, y:Float):Void {
        target.moveTo(s(x), s(y));
    }

    public function lineTo(x:Float, y:Float):Void {
        target.lineTo(s(x), s(y));
    }

    public function quadTo(cx:Float, cy:Float, x:Float, y:Float):Void {
        target.quadTo(s(cx), s(cy), s(x), s(y));
    }

    public function cubicTo(c1x:Float, c1y:Float, c2x:Float, c2y:Float, x:Float, y:Float):Void {
        target.cubicTo(s(c1x), s(c1y), s(c2x), s(c2y), s(x), s(y));
    }

    public function close():Void {
        target.close();
    }

}
