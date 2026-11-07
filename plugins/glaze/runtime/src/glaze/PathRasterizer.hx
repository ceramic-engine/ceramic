// Original code (not a port), written for Glaze: rasterizes GPUI
// paths for Window.paintPath() like GPUI's Metal renderer (gpui-pre-apple
// 0.3.10: metal_renderer.rs draw_paths_to_intermediate with 4x MSAA, and
// shaders.metal path_rasterization_vertex / path_rasterization_fragment).
// MIT License, see Ceramic's LICENSE file.
package glaze;

import haxe.io.Bytes;

/**
 * Rasterizes a `Path` at device resolution for `Window.paintPath()`, the way
 * GPUI's Metal renderer covers pixels: GPUI draws the path triangles into an
 * intermediate 4x MSAA texture (`PATH_SAMPLE_COUNT`) with 8 bits per channel
 * per sample, resolved (mean of the samples, rounded) then copied.
 *
 * Geometry, exactly like the GPU:
 *
 * - vertices are scaled to device pixels in `f32` (`Path::scale`), then go
 *   through `path_rasterization_vertex` (`xy * (2 / size) + (-1, 1)`, NDC in
 *   `f32`) and the viewport transform, and are snapped to the rasterizer's
 *   1/256 pixel grid, ties rounded up (measured on the reference renders: a
 *   vertex of the non zero star in `paths` lands exactly on a tie once in
 *   NDC, and GPUI rounds it up);
 * - samples are at Metal's standard 4x positions ((0.375, 0.125),
 *   (0.875, 0.375), (0.125, 0.625), (0.625, 0.875)), tested with exact
 *   integer edge functions and the top-left rule;
 * - fills (`Path.fillPolygons`: lyon's outline, see `PathBuilder`) are
 *   covered with their fill rule; triangles (strokes, raw paths) each cover
 *   the samples they contain;
 * - pixels whose center is outside the path bounds are left empty (GPUI's
 *   clip distances are evaluated at the pixel center).
 *
 * Output, a tile of the atlas:
 *
 * - plain coverage (`rasterize()`): one byte per pixel, the mean of the 4
 *   samples (0, 64, 128, 191 or 255), decoded by the plain coverage mode of
 *   `shaders.GlazePathSprite`, which reproduces the per sample storage and
 *   the resolve;
 * - paths with Loop-Blinn curve triangles (`rasterizeCurves()`): GPUI's
 *   fragment shader gives the samples of a curve triangle the alpha of the
 *   pixel center, and each sample stores `round(255 * color * alpha)`
 *   before the resolve, so one byte per pixel is not enough. These tiles
 *   are RGBA (polychrome atlas pages): red holds the number of plain
 *   samples plus 5 times the number of curve samples (bits 0 to 4) and the
 *   3 high bits of the curve alpha (bits 5 to 7), green and blue the 16
 *   other bits of the alpha (19 bits in total), alpha is 255. The shader's
 *   path curve mode rounds each kind of sample, then resolves.
 */
class PathRasterizer {

    /** Metal's standard 4x MSAA sample positions, in 1/256 pixel units */
    static final SAMPLE_X:Array<Int> = [96, 224, 32, 160];

    static final SAMPLE_Y:Array<Int> = [32, 96, 160, 224];

    static inline final SUBPIXEL:Float = 256;

    /** Bits of the curve alpha in curve tiles */
    static inline final ALPHA_BITS:Int = 19;

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

    /** Whether the path has Loop-Blinn curve triangles (see `rasterizeCurves()`). */
    public static function hasCurves(path:Path):Bool {
        if (path.fillPolygons != null)
            return false;
        final vertices = path.vertices;
        var i = 0;
        while (i + 2 < vertices.length) {
            final a = vertices[i];
            final b = vertices[i + 1];
            final c = vertices[i + 2];
            if (a.s != b.s || a.s != c.s)
                return true;
            i += 3;
        }
        return false;
    }

    /**
     * A key identifying the rasterized tile, independent of where the tile
     * is: `rasterize()` and `rasterizeCurves()` only read the vertices
     * snapped to the 1/256 grid relative to the tile corner, the curve
     * parameters, the path bounds relative to the tile and the tile size, so
     * the key hashes exactly these values. A path moved by whole device
     * pixels (scrolling) gets the same key, unless the `f32` snapping of its
     * vertices differs at the new position, which then gives another key.
     *
     * Two independent 32 bit hashes plus the count of hashed values: equal
     * keys for different tiles would need a collision of both hashes.
     */
    public static function cacheKey(path:Path, scaleFactor:Float, x0:Float, y0:Float, width:Int, height:Int, viewportWidth:Int, viewportHeight:Int):String {
        final ox = x0 * SUBPIXEL;
        final oy = y0 * SUBPIXEL;
        final hash = keyHash;
        hash.reset();
        hash.addInt(width);
        hash.addInt(height);

        // boundsClip() relative to the tile: f32 values minus whole pixels,
        // exact in f32
        final b = path.bounds;
        final left = f(b.origin.x * scaleFactor);
        final top = f(b.origin.y * scaleFactor);
        hash.addF32(left - x0);
        hash.addF32(top - y0);
        hash.addF32(f(left + f(b.size.width * scaleFactor)) - x0);
        hash.addF32(f(top + f(b.size.height * scaleFactor)) - y0);

        if (path.fillPolygons != null) {
            hash.addInt(path.fillRule == EvenOdd ? 1 : 2);
            for (poly in path.fillPolygons) {
                hash.addInt(-1 - poly.length);
                var i = 0;
                while (i < poly.length) {
                    hash.addInt(Std.int(snapX(poly[i], scaleFactor, viewportWidth) - ox));
                    hash.addInt(Std.int(snapY(poly[i + 1], scaleFactor, viewportHeight) - oy));
                    i += 2;
                }
            }
        }
        else {
            hash.addInt(3);
            for (v in path.vertices) {
                hash.addInt(Std.int(snapX(v.xyPosition.x, scaleFactor, viewportWidth) - ox));
                hash.addInt(Std.int(snapY(v.xyPosition.y, scaleFactor, viewportHeight) - oy));
                hash.addFloat(v.s);
                hash.addFloat(v.t);
            }
        }
        return hash.key();
    }

    static final keyHash:PathKeyHash = new PathKeyHash();

    /** Number of tiles rasterized so far (instrumentation, see `tests/bench`) */
    public static var rasterizedCount:Int = 0;

    /**
     * A vertex coordinate (logical pixels) in 1/256 device pixel units, as
     * the GPU rasterizes it: `f32` scale, NDC in `f32`, viewport transform,
     * snapped to the 1/256 grid with ties rounded up.
     */
    static inline function snapX(v:Float, scaleFactor:Float, size:Int):Float {
        final device = f(v * scaleFactor);
        final ndc = f(device * f(2 / size) - 1);
        return Math.ffloor((ndc + 1) * (size / 2) * SUBPIXEL + 0.5);
    }

    static inline function snapY(v:Float, scaleFactor:Float, size:Int):Float {
        final device = f(v * scaleFactor);
        final ndc = f(device * f(-2 / size) + 1);
        return Math.ffloor((1 - ndc) * (size / 2) * SUBPIXEL + 0.5);
    }

    /**
     * Rasterizes the path into a `width` x `height` coverage mask whose top
     * left corner is at device pixel (`x0`, `y0`), in a viewport of
     * `viewportWidth` x `viewportHeight` device pixels.
     */
    public static function rasterize(path:Path, scaleFactor:Float, x0:Float, y0:Float, width:Int, height:Int, viewportWidth:Int, viewportHeight:Int):AtlasTile.AtlasTileSource {
        rasterizedCount++;
        final mask = Bytes.alloc(width * height);
        mask.fill(0, mask.length, 0);
        final ox = x0 * SUBPIXEL;
        final oy = y0 * SUBPIXEL;

        final bits = Bytes.alloc(width * height);
        bits.fill(0, bits.length, 0);

        if (path.fillPolygons != null) {
            final polygons:Array<Array<Float>> = [];
            for (poly in path.fillPolygons) {
                final out:Array<Float> = [];
                var i = 0;
                while (i < poly.length) {
                    out.push(snapX(poly[i], scaleFactor, viewportWidth) - ox);
                    out.push(snapY(poly[i + 1], scaleFactor, viewportHeight) - oy);
                    i += 2;
                }
                polygons.push(out);
            }
            coverPolygons(polygons, path.fillRule == EvenOdd, bits, width, height);
        }
        else {
            final vertices = path.vertices;
            final covered = coveredSamples;
            var i = 0;
            while (i + 2 < vertices.length) {
                final a = vertices[i].xyPosition;
                final b = vertices[i + 1].xyPosition;
                final c = vertices[i + 2].xyPosition;
                i += 3;
                coverTriangle(
                    snapX(a.x, scaleFactor, viewportWidth) - ox, snapY(a.y, scaleFactor, viewportHeight) - oy,
                    snapX(b.x, scaleFactor, viewportWidth) - ox, snapY(b.y, scaleFactor, viewportHeight) - oy,
                    snapX(c.x, scaleFactor, viewportWidth) - ox, snapY(c.y, scaleFactor, viewportHeight) - oy,
                    width, height, covered
                );
                for (k in covered) {
                    final p = k >> 2;
                    bits.set(p, bits.get(p) | (1 << (k & 3)));
                }
            }
        }

        final clip = boundsClip(path, scaleFactor, x0, y0);
        for (y in 0...height) {
            final cy = y + 0.5;
            for (x in 0...width) {
                final b = bits.get(y * width + x);
                if (b == 0)
                    continue;
                final cx = x + 0.5;
                if (cy < clip[1] || cy > clip[3] || cx < clip[0] || cx > clip[2])
                    continue;
                final k = (b & 1) + ((b >> 1) & 1) + ((b >> 2) & 1) + ((b >> 3) & 1);
                mask.set(y * width + x, Math.round(k * 255 / 4));
            }
        }

        return new AtlasTile.AtlasTileSource(width, height, mask);
    }

    /**
     * Rasterizes a path made of triangles with Loop-Blinn curve triangles
     * into an RGBA tile (BGRA bytes, straight alpha, see the class
     * documentation for the encoding).
     */
    public static function rasterizeCurves(path:Path, scaleFactor:Float, x0:Float, y0:Float, width:Int, height:Int, viewportWidth:Int, viewportHeight:Int):AtlasTile.AtlasTileSource {
        rasterizedCount++;
        final samples = new haxe.ds.Vector<Float>(width * height * 4);
        for (i in 0...samples.length)
            samples[i] = 0;
        final ox = x0 * SUBPIXEL;
        final oy = y0 * SUBPIXEL;

        final vertices = path.vertices;
        var i = 0;
        while (i + 2 < vertices.length) {
            final va = vertices[i];
            final vb = vertices[i + 1];
            final vc = vertices[i + 2];
            i += 3;
            final ax = snapX(va.xyPosition.x, scaleFactor, viewportWidth) - ox, ay = snapY(va.xyPosition.y, scaleFactor, viewportHeight) - oy;
            final bx = snapX(vb.xyPosition.x, scaleFactor, viewportWidth) - ox, by = snapY(vb.xyPosition.y, scaleFactor, viewportHeight) - oy;
            final cx = snapX(vc.xyPosition.x, scaleFactor, viewportWidth) - ox, cy = snapY(vc.xyPosition.y, scaleFactor, viewportHeight) - oy;
            final area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
            if (area == 0)
                continue;

            // Affine st(x, y): gradients of s and t per device pixel
            final dsx = ((vb.s - va.s) * (cy - ay) - (vc.s - va.s) * (by - ay)) / area * SUBPIXEL;
            final dsy = ((vc.s - va.s) * (bx - ax) - (vb.s - va.s) * (cx - ax)) / area * SUBPIXEL;
            final dtx = ((vb.t - va.t) * (cy - ay) - (vc.t - va.t) * (by - ay)) / area * SUBPIXEL;
            final dty = ((vc.t - va.t) * (bx - ax) - (vb.t - va.t) * (cx - ax)) / area * SUBPIXEL;
            // path_rasterization_fragment: `length(float2(dx.x, dy.x)) < 0.001`
            final isCurve = Math.sqrt(dsx * dsx + dsy * dsy) >= 0.001;

            final covered = coveredSamples;
            coverTriangle(ax, ay, bx, by, cx, cy, width, height, covered);
            for (k in covered) {
                final p = k >> 2;
                final j = k & 3;
                var alpha = 1.0;
                if (isCurve) {
                    // Fragment values at the pixel center
                    final px = p % width;
                    final py = Std.int(p / width);
                    final fx = px + 0.5 - ax / SUBPIXEL;
                    final fy = py + 0.5 - ay / SUBPIXEL;
                    final s = va.s + dsx * fx + dsy * fy;
                    final t = va.t + dtx * fx + dty * fy;
                    final gx = 2 * s * dsx - dtx;
                    final gy = 2 * s * dsy - dty;
                    final distance = (s * s - t) / Math.sqrt(gx * gx + gy * gy);
                    alpha = f(Math.max(0, Math.min(1, 0.5 - distance)));
                }
                if (alpha <= 0)
                    continue;
                // Premultiplied "over" of the path color with itself (`k` is `p * 4 + j`)
                samples[k] = samples[k] + alpha * (1 - samples[k]);
            }
        }

        final clip = boundsClip(path, scaleFactor, x0, y0);
        final bytes = Bytes.alloc(width * height * 4);
        bytes.fill(0, bytes.length, 0);
        final scale = 1 << ALPHA_BITS;
        for (y in 0...height) {
            final cy = y + 0.5;
            for (x in 0...width) {
                final p = y * width + x;
                final cx = x + 0.5;
                if (cy < clip[1] || cy > clip[3] || cx < clip[0] || cx > clip[2])
                    continue;
                var plain = 0;
                var curve = 0;
                var alpha = 0.0;
                for (j in 0...4) {
                    final v = samples[p * 4 + j];
                    if (v >= 1) {
                        plain++;
                    }
                    else if (v > 0) {
                        // Samples of one pixel share the alpha of its center
                        // (a pixel with several curve alphas keeps the first)
                        if (curve == 0)
                            alpha = v;
                        curve++;
                    }
                }
                if (plain == 0 && curve == 0)
                    continue;
                final a = curve > 0 ? Std.int(Math.min(Math.round(alpha * scale), scale - 1)) : 0;
                final q = p * 4;
                // BGRA (the atlas swaps it to RGBA): red = counts and the 3
                // high bits of the alpha, green and blue = its 16 low bits
                bytes.set(q, a & 0xFF);
                bytes.set(q + 1, (a >> 8) & 0xFF);
                bytes.set(q + 2, (plain + curve * 5) | ((a >> 16) << 5));
                bytes.set(q + 3, 255);
            }
        }

        final source = new AtlasTile.AtlasTileSource(width, height, bytes);
        source.straightAlpha = true;
        return source;
    }

    /** The path bounds in device pixels relative to the tile: left, top, right, bottom */
    static function boundsClip(path:Path, scaleFactor:Float, x0:Float, y0:Float):Array<Float> {
        final b = path.bounds;
        final left = f(b.origin.x * scaleFactor);
        final top = f(b.origin.y * scaleFactor);
        return [
            left - x0,
            top - y0,
            f(left + f(b.size.width * scaleFactor)) - x0,
            f(top + f(b.size.height * scaleFactor)) - y0
        ];
    }

    /** Samples covered by the last `coverTriangle()` (reused) */
    static final coveredSamples:Array<Int> = [];

    /**
     * Sets `covered` to `pixel * 4 + sample` for each sample of the tile
     * inside the triangle (vertices in 1/256 pixel units relative to the
     * tile), with exact integer edge functions and the top-left rule, in
     * row, sample, column order.
     */
    static function coverTriangle(ax:Float, ay:Float, bx:Float, by:Float, cx:Float, cy:Float, width:Int, height:Int, covered:Array<Int>):Void {
        covered.resize(0);
        var area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
        if (area == 0)
            return;
        if (area < 0) {
            // Clockwise on screen (y down): interior on the positive side
            final tx = bx, ty = by;
            bx = cx;
            by = cy;
            cx = tx;
            cy = ty;
        }
        // Top-left rule: a sample on an edge is inside when the edge is a top
        // edge (horizontal, interior below) or a left edge (interior on the right)
        inline function inclusive(px:Float, py:Float, qx:Float, qy:Float):Bool {
            return (py == qy && qx > px) || qy < py;
        }
        final incAB = inclusive(ax, ay, bx, by);
        final incBC = inclusive(bx, by, cx, cy);
        final incCA = inclusive(cx, cy, ax, ay);

        final minX = Std.int(Math.max(0, Math.floor(Math.min(ax, Math.min(bx, cx)) / SUBPIXEL)));
        final maxX = Std.int(Math.min(width - 1, Math.floor(Math.max(ax, Math.max(bx, cx)) / SUBPIXEL)));
        final minY = Std.int(Math.max(0, Math.floor(Math.min(ay, Math.min(by, cy)) / SUBPIXEL)));
        final maxY = Std.int(Math.min(height - 1, Math.floor(Math.max(ay, Math.max(by, cy)) / SUBPIXEL)));
        for (py in minY...maxY + 1) {
            for (j in 0...4) {
                final sy:Float = py * 256 + SAMPLE_Y[j];
                for (px in minX...maxX + 1) {
                    final sx:Float = px * 256 + SAMPLE_X[j];
                    final e0 = (bx - ax) * (sy - ay) - (by - ay) * (sx - ax);
                    if (e0 < 0 || (e0 == 0 && !incAB))
                        continue;
                    final e1 = (cx - bx) * (sy - by) - (cy - by) * (sx - bx);
                    if (e1 < 0 || (e1 == 0 && !incBC))
                        continue;
                    final e2 = (ax - cx) * (sy - cy) - (ay - cy) * (sx - cx);
                    if (e2 < 0 || (e2 == 0 && !incCA))
                        continue;
                    covered.push((py * width + px) * 4 + j);
                }
            }
        }
    }

    /**
     * Sample coverage of closed polygons (vertices in 1/256 pixel units)
     * with the non zero or even odd rule: for each sample row, the winding
     * number of each sample is the sum of the edges crossing the row at or
     * left of it, tested exactly. Edges cover `[y0, y1)`: with crossings
     * counted at or left of the sample, this is the top-left rule of the
     * triangles lyon would emit (a sample on a left or top edge is inside,
     * on a right or bottom edge outside). Sets bit `j` of `bits` for each
     * covered sample `j`.
     */
    static function coverPolygons(polygons:Array<Array<Float>>, evenOdd:Bool, bits:Bytes, width:Int, height:Int):Void {
        // Edges: x0, y0, x1, y1, direction (y0 < y1)
        final edges:Array<Float> = [];
        for (poly in polygons) {
            final n = Std.int(poly.length / 2);
            if (n < 2)
                continue;
            for (i in 0...n) {
                final j = (i + 1) % n;
                final ax = poly[i * 2], ay = poly[i * 2 + 1];
                final bx = poly[j * 2], by = poly[j * 2 + 1];
                if (ay == by)
                    continue;
                if (ay < by) {
                    edges.push(ax); edges.push(ay); edges.push(bx); edges.push(by); edges.push(1);
                }
                else {
                    edges.push(bx); edges.push(by); edges.push(ax); edges.push(ay); edges.push(-1);
                }
            }
        }
        final edgeCount = Std.int(edges.length / 5);
        if (edgeCount == 0)
            return;

        final xs:Array<Float> = [];
        final ids:Array<Int> = [];
        final order:Array<Int> = [];
        for (y in 0...height) {
            for (j in 0...4) {
                final sy:Float = y * 256 + SAMPLE_Y[j];
                final ox = SAMPLE_X[j];
                xs.resize(0);
                ids.resize(0);
                for (e in 0...edgeCount) {
                    final k = e * 5;
                    final ey0 = edges[k + 1];
                    final ey1 = edges[k + 3];
                    if (sy < ey0 || sy >= ey1)
                        continue;
                    final ex0 = edges[k];
                    final ex1 = edges[k + 2];
                    xs.push(ex0 + (sy - ey0) * (ex1 - ex0) / (ey1 - ey0));
                    ids.push(e);
                }
                final count = xs.length;
                if (count == 0)
                    continue;
                order.resize(0);
                for (i in 0...count)
                    order.push(i);
                order.sort((a, b) -> xs[a] < xs[b] ? -1 : (xs[a] > xs[b] ? 1 : 0));
                var winding = 0;
                var next = 0;
                final bit = 1 << j;
                var x = 0;
                while (x < width) {
                    final sx:Float = x * 256 + ox;
                    // Crossing at or left of the sample, exactly:
                    // x0 + (sy - y0) (x1 - x0) / (y1 - y0) <= sx
                    while (next < count) {
                        final k = ids[order[next]] * 5;
                        final ex0 = edges[k], ey0 = edges[k + 1], ex1 = edges[k + 2], ey1 = edges[k + 3];
                        if ((ex1 - ex0) * (sy - ey0) > (sx - ex0) * (ey1 - ey0))
                            break;
                        winding += Std.int(edges[k + 4]);
                        next++;
                    }
                    final inside = evenOdd ? (winding & 1) != 0 : winding != 0;
                    if (inside) {
                        final p = y * width + x;
                        bits.set(p, bits.get(p) | bit);
                    }
                    else if (next >= count) {
                        break;
                    }
                    x++;
                }
            }
        }
    }

}

/**
 * Two independent 32 bit hashes (FNV-1a and a multiply-rotate mix, with
 * murmur3's finalizer) over 32 bit words, for `PathRasterizer.cacheKey()`.
 */
class PathKeyHash {

    var h1:Int = 0;

    var h2:Int = 0;

    var count:Int = 0;

    public function new() {}

    public inline function reset():Void {
        h1 = 0x811C9DC5;
        h2 = 0x2F3B5A1D;
        count = 0;
    }

    public function addInt(value:Int):Void {
        var a:haxe.Int32 = h1 ^ value;
        a = a * 0x01000193;
        h1 = a;
        var k:haxe.Int32 = value;
        k = k * 0xCC9E2D51;
        k = (k << 15) | (k >>> 17);
        k = k * 0x1B873593;
        var b:haxe.Int32 = h2 ^ k;
        b = (b << 13) | (b >>> 19);
        b = b * 5 + 0xE6546B64;
        h2 = b;
        count++;
    }

    /** A value exact in `f32` */
    public inline function addF32(value:Float):Void {
        addInt(haxe.io.FPHelper.floatToI32(value));
    }

    /** Any double: its `f32` rounding, then the `f32` rounding of the rest */
    public inline function addFloat(value:Float):Void {
        final high = SpringMath.f32(value);
        addInt(haxe.io.FPHelper.floatToI32(high));
        addInt(haxe.io.FPHelper.floatToI32(value - high));
    }

    static inline function fmix(h:haxe.Int32):Int {
        h = h ^ (h >>> 16);
        h = h * 0x85EBCA6B;
        h = h ^ (h >>> 13);
        h = h * 0xC2B2AE35;
        h = h ^ (h >>> 16);
        return h;
    }

    public function key():String {
        return fmix(h1 ^ count) + ':' + fmix(h2 ^ count) + ':' + count;
    }

}
