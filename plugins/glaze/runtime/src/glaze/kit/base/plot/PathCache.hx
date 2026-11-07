// Ported from gpui-kit 0.8.1: crates/base/src/plot/path_cache.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.plot;

import glaze.App;
import glaze.ElementIdArg;
import glaze.Path;
import glaze.Point;
import glaze.SpringMath;
import glaze.Window;

/**
 * A tessellated path reused across frames while its shape is unchanged.
 *
 * A chart repaints on every frame it is on screen, and tessellating its
 * strokes is the bulk of that work, while the vertices only depend on the
 * projected points relative to the chart's origin. A plot keeps one cache
 * per shape and paints through `Line.paintCached` or `Area.paintCached`: the
 * path is built once per shape key, at a zero origin, and moved to the
 * frame's origin on every paint.
 *
 * Keys are the strings `ShapeKey.finish` makes (Rust hashes into a `u64`).
 */
class PathCache {

    var key:Null<String> = null;

    /** Built relative to a zero origin. */
    var path:Null<Path> = null;

    public function new() {}

    /**
     * The path for `key`, moved to `origin`. `build` runs only when the key
     * differs from the last call's; it must build relative to a zero origin.
     */
    public function get(key:String, origin:Point, build:() -> Null<Path>):Null<Path> {
        if (this.key != key) {
            path = build();
            this.key = key;
        }
        return path != null ? translated(path, origin) : null;
    }

    /** Whether the last `get` reused the path built by an earlier one. */
    public function isWarm():Bool {
        return key != null;
    }

    /**
     * `path` moved by `offset`, in `f32` like GPUI. A finished path is only
     * its bounds and vertices (and, in the port, the outline of a fill).
     */
    public static function translated(path:Path, offset:Point):Path {
        final dx = offset.x;
        final dy = offset.y;
        final result = new Path(new Point(0, 0));
        result.bounds = new glaze.Bounds(new Point(f(path.bounds.origin.x + dx), f(path.bounds.origin.y + dy)), path.bounds.size);
        for (vertex in path.vertices) {
            result.vertices.push(new Path.PathVertex(new Point(f(vertex.xyPosition.x + dx), f(vertex.xyPosition.y + dy)), vertex.s, vertex.t));
        }
        if (path.fillPolygons != null) {
            result.fillPolygons = [
                for (polygon in path.fillPolygons) [
                    for (i in 0...polygon.length) f(polygon[i] + ((i & 1) == 0 ? dx : dy))
                ]
            ];
        }
        result.fillRule = path.fillRule;
        result.stroke = path.stroke;
        return result;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}

/**
 * The `PathCache`s of a plot that is rebuilt on every render, kept in the
 * window's element state so they outlive the plot value, under the element
 * id the plot paints in (plus `key`), for as long as the plot is painted on
 * consecutive frames.
 */
class PathCaches {

    final slots:Array<PathCache> = [];

    public function new() {}

    /**
     * The caches for the plot painting under the window's current element
     * id; `key` tells apart several groups of shapes in one plot. Rust
     * returns the state entity; the port returns its value.
     */
    public static function forPaint(key:ElementIdArg, window:Window, cx:App):PathCaches {
        final state:glaze.Window.StateModel<PathCaches> = window.useKeyedState(key, cx, _ -> new PathCaches());
        return state.value;
    }

    /**
     * The `index`-th cache, created on first use. Paint each shape through
     * the same index every frame.
     */
    public function slot(index:Int):PathCache {
        while (slots.length <= index) {
            slots.push(new PathCache());
        }
        return slots[index];
    }

    /**
     * Two caches for a shape that keeps a fill and a stroke, such as
     * `Area.paintCached`, at `2 * index` and `2 * index + 1`.
     */
    public function slotPair(index:Int):Array<PathCache> {
        final first = 2 * index;
        while (slots.length <= first + 1) {
            slots.push(new PathCache());
        }
        return [slots[first], slots[first + 1]];
    }

}

/**
 * A shape key from its projected points (origin-relative) and whatever else
 * shapes the tessellation (stroke width, curve style, dash pattern). Values
 * are recorded by their exact `f32` bits.
 */
class ShapeKey {

    final buf:StringBuf = new StringBuf();

    public function new(extra:String) {
        buf.add(extra);
    }

    public function point(point:Point):ShapeKey {
        return f32(point.x).f32(point.y);
    }

    public function f32(value:Float):ShapeKey {
        buf.add(',');
        buf.add(haxe.io.FPHelper.floatToI32(value));
        return this;
    }

    public function finish():String {
        return buf.toString();
    }

    /** The key part of an `f32` (Rust `f32::to_bits`). */
    public static function bits(value:Null<Float>):String {
        return value == null ? 'none' : Std.string(haxe.io.FPHelper.floatToI32(value));
    }

}
