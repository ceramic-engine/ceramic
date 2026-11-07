package glaze.platform;

import ceramic.Texture;
import glaze.scene.MonochromeSprite;
import glaze.scene.PathSprite;
import glaze.scene.PolychromeSprite;
import glaze.scene.Quad;
import glaze.scene.Scene;
import glaze.scene.Shadow;
import glaze.scene.Underline;

/**
 * The region of a render texture that changes between two scenes, for the
 * partial rendering of `SceneRenderable` (a Ceramic addition: GPUI redraws
 * every frame entirely).
 *
 * `record()` copies, for each primitive of a scene in draw order (the order
 * of `Scene.nextBatch()`), every value the renderer reads from it, and the
 * device pixels it can touch: its geometry quad (the vertices the renderer
 * emits, so the antialiasing of the shaders and the blur of shadows are
 * inside) intersected with its content mask, rounded out to whole pixels
 * plus a margin of one pixel. A primitive changes no pixel outside that
 * rectangle.
 *
 * `diff()` compares the new records with those of the scene the texture
 * holds: the primitives of the common prefix and suffix are unchanged and
 * keep their relative order, every other primitive (removed, added or
 * modified) damages its rectangle. Outside the union of these rectangles,
 * each pixel is covered by the same unchanged primitives in the same order
 * in both scenes, so it keeps its value.
 *
 * The damaged rectangles are merged into a few damage rectangles (at most
 * `MAX_RECTS`, see `addDamage()`), each one containing some of them
 * (while scrolling, their bounds when splitting them saved nothing, see
 * `addMany()`). The renderer handles each damage rectangle in its own
 * pass, with a scissor on that rectangle: it clears the pixels and draws
 * again, in scene order,
 * every primitive whose rectangle intersects it. A pixel p of a damage
 * rectangle R ends with the bytes of a full redraw: every primitive that
 * can change p has a rectangle containing p, so it intersects R and is
 * drawn, in scene order, after the clear; the other primitives drawn leave
 * p as is. The scissor only discards fragments outside R, so it changes
 * neither the geometry nor the interpolation of what is drawn inside, and
 * a later pass on another rectangle either leaves p alone (outside its
 * scissor) or gives it the same bytes again (the same reasoning). A single
 * pass with one scissor over several rectangles would not be exact: the
 * primitives drawn for one rectangle would blend a second time over the
 * pixels kept between them.
 */
class SceneDamage {

    /** Margin added around the rectangle of each primitive, in device pixels */
    public static inline final MARGIN:Int = 1;

    /** Values of the recorded primitives, one run per primitive */
    var prevData:Array<Float> = [];
    var curData:Array<Float> = [];

    /** Start of each primitive's run in `*Data`, plus the end of the last one */
    var prevStarts:Array<Int> = [0];
    var curStarts:Array<Int> = [0];

    /** Pixel rectangle of each primitive: x0, y0, x1, y1 (exclusive ends) */
    var prevRects:Array<Int> = [];
    var curRects:Array<Int> = [];

    var prevCount:Int = 0;
    var curCount:Int = 0;

    var dataLength:Int = 0;

    /** Atlas textures (and their sizes) when the previous scene was drawn */
    final prevTextures:Array<Texture> = [];
    final prevTextureSizes:Array<Float> = [];

    /** `CeramicAtlas.releaseCount` when the previous scene was drawn */
    var prevReleaseCount:Int = -1;

    /** Whether the previous records describe the texture's content */
    public var valid(default, null):Bool = false;

    /**
     * Bounds of the damaged region of the last `diff()`, in device pixels
     * (exclusive ends): the union of its damage rectangles.
     */
    public var x0(default, null):Int = 0;
    public var y0(default, null):Int = 0;
    public var x1(default, null):Int = 0;
    public var y1(default, null):Int = 0;

    /** Most damage rectangles of a `diff()` */
    public static inline final MAX_RECTS:Int = 8;

    /**
     * Two disjoint damage rectangles are merged when their bounding
     * rectangle has at most this many more pixels than both together, plus
     * a quarter of them: a pass costs about as much as redrawing such an
     * area, and the scene is walked once per pass.
     */
    public static inline final MERGE_SLACK:Int = 4096;

    /** Damage rectangles of the last `diff()`: x0, y0, x1, y1 (exclusive ends) */
    final rects:Array<Int> = [];

    /** Number of damage rectangles of the last `diff()` (0: nothing to draw) */
    public var rectCount(default, null):Int = 0;

    /** Damage rectangle `i` of the last `diff()`, in device pixels (exclusive ends) */
    public inline function rectX0(i:Int):Int return rects[i * 4];
    public inline function rectY0(i:Int):Int return rects[i * 4 + 1];
    public inline function rectX1(i:Int):Int return rects[i * 4 + 2];
    public inline function rectY1(i:Int):Int return rects[i * 4 + 3];

    /** Damage rectangle the last added rectangle fell in or became */
    var lastHit:Int = 0;

    /** Whether a damage rectangle grew in place since the last `normalize()` */
    var grown:Bool = false;

    /**
     * Merges the damage rectangles that should be (see `shouldMerge()`)
     * after some grew in place, until none is left.
     */
    function normalize():Void {

        if (!grown) return;
        grown = false;
        var merged = true;
        while (merged) {
            merged = false;
            var i = 0;
            while (i < rectCount && !merged) {
                var j = i + 1;
                while (j < rectCount) {
                    final a = i * 4;
                    final b = j * 4;
                    if (shouldMerge(rects[a], rects[a + 1], rects[a + 2], rects[a + 3], rects[b], rects[b + 1], rects[b + 2], rects[b + 3])) {
                        final mx0 = rects[a] < rects[b] ? rects[a] : rects[b];
                        final my0 = rects[a + 1] < rects[b + 1] ? rects[a + 1] : rects[b + 1];
                        final mx1 = rects[a + 2] > rects[b + 2] ? rects[a + 2] : rects[b + 2];
                        final my1 = rects[a + 3] > rects[b + 3] ? rects[a + 3] : rects[b + 3];
                        setRect(i, mx0, my0, mx1, my1);
                        removeRect(j);
                        merged = true;
                        break;
                    }
                    j++;
                }
                i++;
            }
        }

    }

    /** Texture size of the running `diff()` */
    var limitWidth:Int = 0;
    var limitHeight:Int = 0;

    /** Whether the last `diff()` must redraw the whole texture */
    public var full(default, null):Bool = true;

    public function new() {}

    /** Forgets the previous scene: the next `diff()` asks for a full redraw. */
    public function invalidate():Void {

        valid = false;

    }

    /**
     * Records `scene` (see the class description). Leaves the scene's batch
     * iteration at its end. `textures` are the atlas textures the scene's
     * sprites index, `releaseCount` the atlas' count of released tiles
     * (-1 when unknown, which forces a full redraw).
     */
    public function record(scene:Null<Scene>, textures:Array<Texture>, releaseCount:Int):Void {

        curCount = 0;
        dataLength = 0;

        // Atlas textures replaced, resized or tiles released (their room can
        // hold other pixels for equal records): the texture is drawn again
        if (releaseCount < 0 || releaseCount != prevReleaseCount) {
            valid = false;
        }
        final textureCount = textures.length < prevTextures.length ? textures.length : prevTextures.length;
        for (i in 0...textureCount) {
            final texture = textures[i];
            if (texture != prevTextures[i]
                || (texture != null && (texture.nativeWidthActual != prevTextureSizes[i * 2] || texture.nativeHeightActual != prevTextureSizes[i * 2 + 1]))) {
                valid = false;
                break;
            }
        }
        if (textures.length < prevTextures.length) {
            valid = false;
        }
        prevReleaseCount = releaseCount;
        prevTextures.resize(textures.length);
        prevTextureSizes.resize(textures.length * 2);
        for (i in 0...textures.length) {
            final texture = textures[i];
            prevTextures[i] = texture;
            prevTextureSizes[i * 2] = texture != null ? texture.nativeWidthActual : 0;
            prevTextureSizes[i * 2 + 1] = texture != null ? texture.nativeHeightActual : 0;
        }

        if (scene == null) return;

        scene.resetBatches();
        var batch = scene.nextBatch();
        while (batch != null) {
            switch batch.kind {
                case Shadow:
                    final shadows = scene.shadows;
                    for (i in batch.start...batch.end) recordShadow(shadows[i]);
                case Quad:
                    final quads = scene.quads;
                    for (i in batch.start...batch.end) recordQuad(quads[i]);
                case Path:
                    final paths = scene.paths;
                    for (i in batch.start...batch.end) recordPath(paths[i]);
                case Underline:
                    final underlines = scene.underlines;
                    for (i in batch.start...batch.end) recordUnderline(underlines[i]);
                case MonochromeSprite:
                    final sprites = scene.monochromeSprites;
                    for (i in batch.start...batch.end) recordMonochromeSprite(sprites[i]);
                case PolychromeSprite:
                    final sprites = scene.polychromeSprites;
                    for (i in batch.start...batch.end) recordPolychromeSprite(sprites[i]);
                case _:
            }
            batch = scene.nextBatch();
        }

    }

    /**
     * Computes the damaged region between the previous scene and the one
     * just recorded, clamped to a texture of `width` x `height` pixels, then
     * makes the recorded scene the previous one. `full` is set when there
     * is no valid previous scene or when the region covers the texture.
     */
    public function diff(width:Int, height:Int):Void {

        x0 = 0;
        y0 = 0;
        x1 = 0;
        y1 = 0;
        rectCount = 0;
        lastHit = 0;
        grown = false;
        splitEvaluated = false;
        full = !valid;
        limitWidth = width;
        limitHeight = height;

        if (valid) {
            final common = prevCount < curCount ? prevCount : curCount;
            var prefix = 0;
            while (prefix < common && same(prefix, prefix)) prefix++;
            var suffix = 0;
            final maxSuffix = common - prefix;
            while (suffix < maxSuffix && same(prevCount - 1 - suffix, curCount - 1 - suffix)) suffix++;

            if (lastDamageCovered) {
                // While everything changes at each frame (scrolling), the
                // middle is not searched for unchanged primitives (it would
                // find none), and the bounds of the changed primitives are
                // checked first: when they cover the texture, it is drawn
                // again entirely without splitting the damage
                ux0 = width;
                uy0 = height;
                ux1 = 0;
                uy1 = 0;
                for (i in prefix...prevCount - suffix) unite(prevRects, i);
                for (i in prefix...curCount - suffix) unite(curRects, i);
                if (ux0 <= 0 && uy0 <= 0 && ux1 >= width && uy1 >= height) {
                    full = true;
                }
                else {
                    addMany(prefix, prevCount - suffix, curCount - suffix, false);
                }
            }
            else if (!matchMiddle(prefix, prevCount - suffix, prefix, curCount - suffix)) {
                addMany(prefix, prevCount - suffix, curCount - suffix, true);
            }

            normalize();
            if (!full && rectCount > 0) {
                var bx0 = width;
                var by0 = height;
                var bx1 = 0;
                var by1 = 0;
                for (r in 0...rectCount) {
                    final rx0 = rects[r * 4];
                    final ry0 = rects[r * 4 + 1];
                    final rx1 = rects[r * 4 + 2];
                    final ry1 = rects[r * 4 + 3];
                    if (rx0 == 0 && ry0 == 0 && rx1 == width && ry1 == height) full = true;
                    if (rx0 < bx0) bx0 = rx0;
                    if (ry0 < by0) by0 = ry0;
                    if (rx1 > bx1) bx1 = rx1;
                    if (ry1 > by1) by1 = ry1;
                }
                x0 = bx0;
                y0 = by0;
                x1 = bx1;
                y1 = by1;
                if (splitEvaluated) {
                    // Whether the split saved at least a tenth of its bounds
                    var area = 0.0;
                    for (r in 0...rectCount) {
                        area += (rects[r * 4 + 2] - rects[r * 4]) * 1.0 * (rects[r * 4 + 3] - rects[r * 4 + 1]);
                    }
                    splitUseful = area * 10 < (bx1 - bx0) * 1.0 * (by1 - by0) * 9;
                }
            }
            splitEvaluated = false;
            lastDamageCovered = full;
        }
        else {
            lastDamageCovered = false;
        }

        if (full) {
            x0 = 0;
            y0 = 0;
            x1 = width;
            y1 = height;
            rectCount = width > 0 && height > 0 ? 1 : 0;
            if (rectCount > 0) setRect(0, 0, 0, width, height);
        }

        // The recorded scene becomes the previous one, the old previous
        // arrays are reused for the next record
        final data = prevData;
        prevData = curData;
        curData = data;
        final starts = prevStarts;
        prevStarts = curStarts;
        curStarts = starts;
        final primitiveRects = prevRects;
        prevRects = curRects;
        curRects = primitiveRects;
        prevCount = curCount;
        valid = true;

    }

    /**
     * Frames of many changes (scrolling) drawn with the bounds of the
     * changed primitives instead of splitting them, since the last split.
     */
    var splitSkips:Int = 0;

    /** Whether the last split of many changes saved room (see `addMany()`) */
    var splitUseful:Bool = true;

    /** Set while `diff()` runs when `addMany()` split many changes */
    var splitEvaluated:Bool = false;

    /** Frames of many changes using the bounds before trying to split again */
    public static inline final SPLIT_RETRY:Int = 16;

    /**
     * Adds the rectangles of the primitives `prefix...prevEnd` of the
     * previous scene and `prefix...curEnd` of the recorded one, all
     * changed: more edits than `matchMiddle()` searches (`searched`) or a
     * frame after a full one (the bounds `ux0, uy0` to `ux1, uy1` are then
     * already known). Splitting them costs a little more than their bounds
     * and, while scrolling, often saves nothing: when the last split saved
     * less than a tenth of its bounds, the bounds are used for the next
     * `SPLIT_RETRY - 1` such frames. Both contain every changed rectangle.
     */
    function addMany(prefix:Int, prevEnd:Int, curEnd:Int, searched:Bool):Void {

        if (!splitUseful && splitSkips < SPLIT_RETRY - 1) {
            splitSkips++;
            if (searched) {
                ux0 = limitWidth;
                uy0 = limitHeight;
                ux1 = 0;
                uy1 = 0;
                for (i in prefix...prevEnd) unite(prevRects, i);
                for (i in prefix...curEnd) unite(curRects, i);
            }
            addDamage(ux0, uy0, ux1, uy1);
            return;
        }
        splitSkips = 0;
        splitEvaluated = true;
        addPrimitives(prevRects, prefix, prevEnd);
        addPrimitives(curRects, prefix, curEnd);

    }

    /** Bounds of the changed primitives while `diff()` runs (scrolling) */
    var ux0:Int = 0;
    var uy0:Int = 0;
    var ux1:Int = 0;
    var uy1:Int = 0;

    /** Whether the damage of the last `diff()` covered the whole texture */
    var lastDamageCovered:Bool = false;

    inline function unite(rects:Array<Int>, i:Int):Void {

        final ax0 = rect(rects, i * 4);
        final ay0 = rect(rects, i * 4 + 1);
        final ax1 = rect(rects, i * 4 + 2);
        final ay1 = rect(rects, i * 4 + 3);
        if (ax1 > ax0 && ay1 > ay0) {
            if (ax0 < ux0) ux0 = ax0;
            if (ay0 < uy0) uy0 = ay0;
            if (ax1 > ux1) ux1 = ax1;
            if (ay1 > uy1) uy1 = ay1;
        }

    }

    /**
     * Adds the rectangles of primitives `from...to` of `primitiveRects` to
     * the damage. The damage rectangle the last one fell in is kept in
     * locals: while scrolling, most primitives fall in it.
     */
    @:noDebug
    function addPrimitives(primitiveRects:Array<Int>, from:Int, to:Int):Void {

        var hx0 = 1;
        var hy0 = 1;
        var hx1 = 0;
        var hy1 = 0;
        if (lastHit < rectCount) {
            final b = lastHit * 4;
            hx0 = rect(rects, b);
            hy0 = rect(rects, b + 1);
            hx1 = rect(rects, b + 2);
            hy1 = rect(rects, b + 3);
        }
        var i = from;
        while (i < to) {
            final r = i * 4;
            // Clamped to the texture like the damage rectangles (the margin
            // puts the primitives along an edge one pixel out)
            var ax0 = rect(primitiveRects, r);
            var ay0 = rect(primitiveRects, r + 1);
            var ax1 = rect(primitiveRects, r + 2);
            var ay1 = rect(primitiveRects, r + 3);
            if (ax0 < 0) ax0 = 0;
            if (ay0 < 0) ay0 = 0;
            if (ax1 > limitWidth) ax1 = limitWidth;
            if (ay1 > limitHeight) ay1 = limitHeight;
            if (ax0 >= hx0 && ay0 >= hy0 && ax1 <= hx1 && ay1 <= hy1) {
                // Inside the cached rectangle
            }
            else if (ax1 <= ax0 || ay1 <= ay0) {
                // Clipped out or off the texture (scrolled out): no pixel
            }
            else if (lastHit < rectCount && ax0 <= hx1 && hx0 <= ax1 && ay0 <= hy1 && hy0 <= ay1) {
                // Overlapping or touching the cached rectangle: it grows in
                // place (see `addDamage()`)
                if (ax0 < hx0) hx0 = ax0;
                if (ay0 < hy0) hy0 = ay0;
                if (ax1 > hx1) hx1 = ax1;
                if (ay1 > hy1) hy1 = ay1;
                final b = lastHit * 4;
                setInt(rects, b, hx0);
                setInt(rects, b + 1, hy0);
                setInt(rects, b + 2, hx1);
                setInt(rects, b + 3, hy1);
                grown = true;
            }
            else if (!containedSwitch(ax0, ay0, ax1, ay1)) {
                // In no damage rectangle (`containedSwitch()` caches the one
                // holding it otherwise)
                addDamage(ax0, ay0, ax1, ay1);
                switched = true;
            }
            if (switched) {
                switched = false;
                if (lastHit < rectCount) {
                    final b = lastHit * 4;
                    hx0 = rect(rects, b);
                    hy0 = rect(rects, b + 1);
                    hx1 = rect(rects, b + 2);
                    hy1 = rect(rects, b + 3);
                }
            }
            i++;
        }

    }

    /** Set when `lastHit` changed during `addPrimitives()` */
    var switched:Bool = false;

    /**
     * Whether `ax0, ay0` to `ax1, ay1` is inside a damage rectangle, which
     * becomes `lastHit` (and sets `switched`).
     */
    @:noDebug
    function containedSwitch(ax0:Int, ay0:Int, ax1:Int, ay1:Int):Bool {

        for (r in 0...rectCount) {
            final b = r * 4;
            if (ax0 >= rect(rects, b) && ay0 >= rect(rects, b + 1) && ax1 <= rect(rects, b + 2) && ay1 <= rect(rects, b + 3)) {
                lastHit = r;
                switched = true;
                return true;
            }
        }
        return false;

    }

    /** Adds the rectangle of primitive `i` of `rects` to the damage */
    inline function addPrimitive(primitiveRects:Array<Int>, i:Int):Void {

        final ax0 = rect(primitiveRects, i * 4);
        final ay0 = rect(primitiveRects, i * 4 + 1);
        final ax1 = rect(primitiveRects, i * 4 + 2);
        final ay1 = rect(primitiveRects, i * 4 + 3);
        // Inside the damage rectangle the previous one fell in (most
        // primitives while scrolling): nothing to do, without a call
        final b = lastHit * 4;
        if (lastHit >= rectCount
            || ax0 < rect(rects, b) || ay0 < rect(rects, b + 1) || ax1 > rect(rects, b + 2) || ay1 > rect(rects, b + 3)) {
            addDamage(ax0, ay0, ax1, ay1);
        }

    }

    /**
     * Adds the rectangle `ax0, ay0` to `ax1, ay1` (exclusive ends) to the
     * damage rectangles, clamped to the texture. A damage rectangle that
     * overlaps or touches it, or whose merge with it wastes little room
     * (see `MERGE_SLACK`), is merged with it, again until none is left.
     * Beyond `MAX_RECTS` rectangles, the pair whose merge wastes the least
     * room is merged. The damage rectangles always contain every added one.
     */
    @:noDebug
    function addDamage(ax0:Int, ay0:Int, ax1:Int, ay1:Int):Void {

        if (ax0 < 0) ax0 = 0;
        if (ay0 < 0) ay0 = 0;
        if (ax1 > limitWidth) ax1 = limitWidth;
        if (ay1 > limitHeight) ay1 = limitHeight;
        if (ax1 <= ax0 || ay1 <= ay0) return;

        // Most added rectangles fall inside a damage rectangle (the glyphs
        // of a changed line), often the one the previous rectangle fell in:
        // nothing to do
        if (lastHit < rectCount) {
            final b = lastHit * 4;
            final bx0 = rect(rects, b);
            final by0 = rect(rects, b + 1);
            final bx1 = rect(rects, b + 2);
            final by1 = rect(rects, b + 3);
            if (ax0 >= bx0 && ay0 >= by0 && ax1 <= bx1 && ay1 <= by1) return;
            // Overlapping or touching it (content scrolled in order): it
            // grows in place, `normalize()` merges what it now overlaps
            if (ax0 <= bx1 && bx0 <= ax1 && ay0 <= by1 && by0 <= ay1) {
                if (ax0 < bx0) setInt(rects, b, ax0);
                if (ay0 < by0) setInt(rects, b + 1, ay0);
                if (ax1 > bx1) setInt(rects, b + 2, ax1);
                if (ay1 > by1) setInt(rects, b + 3, ay1);
                grown = true;
                return;
            }
        }
        for (r in 0...rectCount) {
            final b = r * 4;
            if (ax0 >= rect(rects, b) && ay0 >= rect(rects, b + 1) && ax1 <= rect(rects, b + 2) && ay1 <= rect(rects, b + 3)) {
                lastHit = r;
                return;
            }
        }

        var r = 0;
        while (r < rectCount) {
            final b = r * 4;
            final bx0 = rect(rects, b);
            final by0 = rect(rects, b + 1);
            final bx1 = rect(rects, b + 2);
            final by1 = rect(rects, b + 3);
            if (shouldMerge(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)) {
                if (bx0 < ax0) ax0 = bx0;
                if (by0 < ay0) ay0 = by0;
                if (bx1 > ax1) ax1 = bx1;
                if (by1 > ay1) ay1 = by1;
                removeRect(r);
                // The larger rectangle may now merge with ones already passed
                r = 0;
            }
            else {
                r++;
            }
        }

        setRect(rectCount, ax0, ay0, ax1, ay1);
        lastHit = rectCount;
        rectCount++;

        if (rectCount > MAX_RECTS) {
            // Merge the pair that wastes the least room, then add their
            // bounds again (it may merge with others)
            var bestI = 0;
            var bestJ = 1;
            var bestWaste = Math.POSITIVE_INFINITY;
            for (i in 0...rectCount) {
                for (j in i + 1...rectCount) {
                    final waste = mergeWaste(i, j);
                    if (waste < bestWaste) {
                        bestWaste = waste;
                        bestI = i;
                        bestJ = j;
                    }
                }
            }
            final bi = bestI * 4;
            final bj = bestJ * 4;
            final mx0 = rects[bi] < rects[bj] ? rects[bi] : rects[bj];
            final my0 = rects[bi + 1] < rects[bj + 1] ? rects[bi + 1] : rects[bj + 1];
            final mx1 = rects[bi + 2] > rects[bj + 2] ? rects[bi + 2] : rects[bj + 2];
            final my1 = rects[bi + 3] > rects[bj + 3] ? rects[bi + 3] : rects[bj + 3];
            // Remove the higher index first so that the lower one stays valid
            removeRect(bestJ);
            removeRect(bestI);
            addDamage(mx0, my0, mx1, my1);
        }

    }

    /** Whether the rectangles `a` and `b` are better drawn in one pass */
    static inline function shouldMerge(ax0:Int, ay0:Int, ax1:Int, ay1:Int, bx0:Int, by0:Int, bx1:Int, by1:Int):Bool {

        // Overlapping or touching
        if (ax0 <= bx1 && bx0 <= ax1 && ay0 <= by1 && by0 <= ay1) return true;
        final sum = (ax1 - ax0) * 1.0 * (ay1 - ay0) + (bx1 - bx0) * 1.0 * (by1 - by0);
        final ux0 = ax0 < bx0 ? ax0 : bx0;
        final uy0 = ay0 < by0 ? ay0 : by0;
        final ux1 = ax1 > bx1 ? ax1 : bx1;
        final uy1 = ay1 > by1 ? ay1 : by1;
        final union = (ux1 - ux0) * 1.0 * (uy1 - uy0);
        return union - sum <= MERGE_SLACK + sum * 0.25;

    }

    /** Pixels of the bounds of damage rectangles `i` and `j` covered by neither */
    function mergeWaste(i:Int, j:Int):Float {

        final a = i * 4;
        final b = j * 4;
        final ux0 = rects[a] < rects[b] ? rects[a] : rects[b];
        final uy0 = rects[a + 1] < rects[b + 1] ? rects[a + 1] : rects[b + 1];
        final ux1 = rects[a + 2] > rects[b + 2] ? rects[a + 2] : rects[b + 2];
        final uy1 = rects[a + 3] > rects[b + 3] ? rects[a + 3] : rects[b + 3];
        return (ux1 - ux0) * 1.0 * (uy1 - uy0)
            - (rects[a + 2] - rects[a]) * 1.0 * (rects[a + 3] - rects[a + 1])
            - (rects[b + 2] - rects[b]) * 1.0 * (rects[b + 3] - rects[b + 1]);

    }

    inline function setRect(r:Int, rx0:Int, ry0:Int, rx1:Int, ry1:Int):Void {

        final b = r * 4;
        if (rects.length < b + 4) rects.resize(b + 4);
        rects[b] = rx0;
        rects[b + 1] = ry0;
        rects[b + 2] = rx1;
        rects[b + 3] = ry1;

    }

    /** Removes damage rectangle `r` (the last one takes its place) */
    inline function removeRect(r:Int):Void {

        rectCount--;
        if (r != rectCount) {
            final b = r * 4;
            final l = rectCount * 4;
            rects[b] = rects[l];
            rects[b + 1] = rects[l + 1];
            rects[b + 2] = rects[l + 2];
            rects[b + 3] = rects[l + 3];
        }

    }

    /**
     * Most edits between two scenes searched for in their middle section.
     * Each modified primitive counts as two (removed, added).
     */
    public static inline final MAX_EDITS:Int = 96;

    /** Furthest reaching paths of `matchMiddle()`, one row per edit count */
    var trace:Array<Int> = [];

    /**
     * Finds the primitives of the previous scene `p0...p1` and the recorded
     * one `c0...c1` that changed with Myers' diff ("An O(ND) Difference
     * Algorithm and Its Variations", 1986): the others form a longest
     * common subsequence (unchanged primitives, same relative order), and
     * adds the rectangles of the changed ones to the damage. Returns false,
     * adding nothing, when they differ by more than `MAX_EDITS` edits.
     */
    @:noDebug
    function matchMiddle(p0:Int, p1:Int, c0:Int, c1:Int):Bool {

        final n = p1 - p0;
        final m = c1 - c0;
        if (n == 0 || m == 0) {
            for (i in p0...p1) addPrimitive(prevRects, i);
            for (i in c0...c1) addPrimitive(curRects, i);
            return true;
        }

        final maxD = n + m < MAX_EDITS ? n + m : MAX_EDITS;
        final width = 2 * maxD + 3;
        final offset = maxD + 1;
        final needed = width * (maxD + 1);
        if (trace.length < needed) trace.resize(needed);

        // v[k] (k = x - y) of edit count d is stored in row d of `trace`,
        // the reads of row d come from row d - 1
        var found = -1;
        var d = 0;
        while (d <= maxD && found < 0) {
            final row = d * width + offset;
            final prevRow = row - width;
            var k = -d;
            while (k <= d) {
                var x:Int;
                if (d == 0) {
                    x = 0;
                }
                else if (k == -d || (k != d && trace[prevRow + k - 1] < trace[prevRow + k + 1])) {
                    x = trace[prevRow + k + 1];
                }
                else {
                    x = trace[prevRow + k - 1] + 1;
                }
                var y = x - k;
                while (x < n && y < m && same(p0 + x, c0 + y)) {
                    x++;
                    y++;
                }
                trace[row + k] = x;
                if (x >= n && y >= m) {
                    found = d;
                    break;
                }
                k += 2;
            }
            d++;
        }
        if (found < 0) return false;

        // Back from (n, m): each step of d is one removed or added primitive
        var x = n;
        var y = m;
        d = found;
        while (d > 0) {
            final prevRow = (d - 1) * width + offset;
            final k = x - y;
            final prevK = (k == -d || (k != d && trace[prevRow + k - 1] < trace[prevRow + k + 1])) ? k + 1 : k - 1;
            final prevX = trace[prevRow + prevK];
            final prevY = prevX - prevK;
            // Skip the diagonal (unchanged primitives) down to the edit
            while (x > prevX && y > prevY) {
                x--;
                y--;
            }
            if (x == prevX) {
                // Added: primitive y - 1 of the recorded scene
                addPrimitive(curRects, c0 + y - 1);
            }
            else {
                // Removed: primitive x - 1 of the previous scene
                addPrimitive(prevRects, p0 + x - 1);
            }
            x = prevX;
            y = prevY;
            d--;
        }
        return true;

    }

    /** Rectangle of the primitive at `index` of the scene `diff()` just compared */
    public inline function drawnRectX0(index:Int):Int return rect(prevRects, index * 4);
    public inline function drawnRectY0(index:Int):Int return rect(prevRects, index * 4 + 1);
    public inline function drawnRectX1(index:Int):Int return rect(prevRects, index * 4 + 2);
    public inline function drawnRectY1(index:Int):Int return rect(prevRects, index * 4 + 3);

    /** Whether primitive `p` of the previous scene and `c` of the recorded one have the same values */
    @:noDebug
    function same(p:Int, c:Int):Bool {

        final pStart = start(prevStarts, p);
        final pEnd = start(prevStarts, p + 1);
        final cStart = start(curStarts, c);
        final cEnd = start(curStarts, c + 1);
        if (pEnd - pStart != cEnd - cStart) return false;
        // Rectangles follow from the values, except for rounding: compare them too
        for (k in 0...4) {
            if (rect(prevRects, p * 4 + k) != rect(curRects, c * 4 + k)) return false;
        }
        var i = pStart;
        var j = cStart;
        while (i < pEnd) {
            // NaN never equals itself: such a primitive counts as changed
            if (value(prevData, i) != value(curData, j)) return false;
            i++;
            j++;
        }
        return true;

    }

/// Recording

    inline function begin(kindCode:Int):Void {

        // Room for the longest run (quads: 37 values)
        if (curData.length < dataLength + 64) {
            curData.resize(curData.length * 2 + 256);
        }
        put(kindCode);

    }

    inline function put(value:Float):Void {

        #if cpp
        cpp.NativeArray.unsafeSet(curData, dataLength, value);
        #else
        curData[dataLength] = value;
        #end
        dataLength++;

    }

    /**
     * Ends the run of a primitive whose geometry quad is `gx0, gy0` to
     * `gx1, gy1` in scene pixels, clipped by its content mask.
     */
    @:noDebug
    function end(gx0:Float, gy0:Float, gx1:Float, gy1:Float, maskX:Float, maskY:Float, maskWidth:Float, maskHeight:Float):Void {

        var ix0 = 0;
        var iy0 = 0;
        var ix1 = 0;
        var iy1 = 0;
        if (gx0 != gx0 || gy0 != gy0 || gx1 != gx1 || gy1 != gy1
            || maskX != maskX || maskY != maskY || maskWidth != maskWidth || maskHeight != maskHeight) {
            // A NaN somewhere: assume the whole texture
            ix0 = -0x3FFFFFFF;
            iy0 = -0x3FFFFFFF;
            ix1 = 0x3FFFFFFF;
            iy1 = 0x3FFFFFFF;
        }
        else {
            final mx1 = maskX + maskWidth;
            final my1 = maskY + maskHeight;
            final cx0 = gx0 > maskX ? gx0 : maskX;
            final cy0 = gy0 > maskY ? gy0 : maskY;
            final cx1 = gx1 < mx1 ? gx1 : mx1;
            final cy1 = gy1 < my1 ? gy1 : my1;
            // Empty: no pixel
            if (cx1 > cx0 && cy1 > cy0) {
                ix0 = toPixel(Math.ffloor(cx0)) - MARGIN;
                iy0 = toPixel(Math.ffloor(cy0)) - MARGIN;
                ix1 = toPixel(Math.fceil(cx1)) + MARGIN;
                iy1 = toPixel(Math.fceil(cy1)) + MARGIN;
            }
        }

        final r = curCount * 4;
        if (curRects.length < r + 4) {
            curRects.resize(curRects.length * 2 + 64);
        }
        setInt(curRects, r, ix0);
        setInt(curRects, r + 1, iy0);
        setInt(curRects, r + 2, ix1);
        setInt(curRects, r + 3, iy1);

        curCount++;
        if (curStarts.length < curCount + 1) {
            curStarts.resize(curStarts.length * 2 + 64);
        }
        setInt(curStarts, curCount, dataLength);

    }

    static inline function toPixel(value:Float):Int {

        return value < -0x3FFFFFFF ? -0x3FFFFFFF : value > 0x3FFFFFFF ? 0x3FFFFFFF : Std.int(value);

    }

    @:noDebug
    function recordQuad(quad:Quad):Void {

        begin(1);
        put(quad.boundsX);
        put(quad.boundsY);
        put(quad.boundsWidth);
        put(quad.boundsHeight);
        put(quad.contentMaskX);
        put(quad.contentMaskY);
        put(quad.contentMaskWidth);
        put(quad.contentMaskHeight);
        put(quad.borderStyle);
        put(quad.backgroundTag);
        put(quad.backgroundColorSpace);
        put(quad.backgroundSolidH);
        put(quad.backgroundSolidS);
        put(quad.backgroundSolidL);
        put(quad.backgroundSolidA);
        put(quad.backgroundGradientAngleOrPatternHeight);
        put(quad.backgroundColor0H);
        put(quad.backgroundColor0S);
        put(quad.backgroundColor0L);
        put(quad.backgroundColor0A);
        put(quad.backgroundColor0Percentage);
        put(quad.backgroundColor1H);
        put(quad.backgroundColor1S);
        put(quad.backgroundColor1L);
        put(quad.backgroundColor1A);
        put(quad.backgroundColor1Percentage);
        put(quad.borderColorH);
        put(quad.borderColorS);
        put(quad.borderColorL);
        put(quad.borderColorA);
        put(quad.cornerRadiusTopLeft);
        put(quad.cornerRadiusTopRight);
        put(quad.cornerRadiusBottomRight);
        put(quad.cornerRadiusBottomLeft);
        put(quad.borderWidthTop);
        put(quad.borderWidthRight);
        put(quad.borderWidthBottom);
        put(quad.borderWidthLeft);
        end(
            quad.boundsX, quad.boundsY, quad.boundsX + quad.boundsWidth, quad.boundsY + quad.boundsHeight,
            quad.contentMaskX, quad.contentMaskY, quad.contentMaskWidth, quad.contentMaskHeight
        );

    }

    @:noDebug
    function recordShadow(shadow:Shadow):Void {

        begin(2);
        put(shadow.boundsX);
        put(shadow.boundsY);
        put(shadow.boundsWidth);
        put(shadow.boundsHeight);
        put(shadow.contentMaskX);
        put(shadow.contentMaskY);
        put(shadow.contentMaskWidth);
        put(shadow.contentMaskHeight);
        put(shadow.blurRadius);
        put(shadow.inset ? 1 : 0);
        put(shadow.cornerRadiusTopLeft);
        put(shadow.cornerRadiusTopRight);
        put(shadow.cornerRadiusBottomRight);
        put(shadow.cornerRadiusBottomLeft);
        put(shadow.colorH);
        put(shadow.colorS);
        put(shadow.colorL);
        put(shadow.colorA);
        put(shadow.elementBoundsX);
        put(shadow.elementBoundsY);
        put(shadow.elementBoundsWidth);
        put(shadow.elementBoundsHeight);
        put(shadow.elementCornerRadiusTopLeft);
        put(shadow.elementCornerRadiusTopRight);
        put(shadow.elementCornerRadiusBottomRight);
        put(shadow.elementCornerRadiusBottomLeft);
        // Geometry of `SceneRenderable.drawShadows()`
        if (shadow.inset) {
            end(
                shadow.elementBoundsX, shadow.elementBoundsY,
                shadow.elementBoundsX + shadow.elementBoundsWidth, shadow.elementBoundsY + shadow.elementBoundsHeight,
                shadow.contentMaskX, shadow.contentMaskY, shadow.contentMaskWidth, shadow.contentMaskHeight
            );
        }
        else {
            final margin = 3.0 * shadow.blurRadius;
            final gx = shadow.boundsX - margin;
            final gy = shadow.boundsY - margin;
            end(
                gx, gy, gx + (shadow.boundsWidth + 2.0 * margin), gy + (shadow.boundsHeight + 2.0 * margin),
                shadow.contentMaskX, shadow.contentMaskY, shadow.contentMaskWidth, shadow.contentMaskHeight
            );
        }

    }

    @:noDebug
    function recordUnderline(underline:Underline):Void {

        begin(3);
        put(underline.boundsX);
        put(underline.boundsY);
        put(underline.boundsWidth);
        put(underline.boundsHeight);
        put(underline.contentMaskX);
        put(underline.contentMaskY);
        put(underline.contentMaskWidth);
        put(underline.contentMaskHeight);
        put(underline.colorH);
        put(underline.colorS);
        put(underline.colorL);
        put(underline.colorA);
        put(underline.thickness);
        put(underline.wavy ? 1 : 0);
        end(
            underline.boundsX, underline.boundsY, underline.boundsX + underline.boundsWidth, underline.boundsY + underline.boundsHeight,
            underline.contentMaskX, underline.contentMaskY, underline.contentMaskWidth, underline.contentMaskHeight
        );

    }

    @:noDebug
    function recordMonochromeSprite(sprite:MonochromeSprite):Void {

        begin(4);
        put(sprite.textureIndex);
        put(sprite.tileX);
        put(sprite.tileY);
        put(sprite.tileWidth);
        put(sprite.tileHeight);
        put(sprite.boundsX);
        put(sprite.boundsY);
        put(sprite.boundsWidth);
        put(sprite.boundsHeight);
        put(sprite.contentMaskX);
        put(sprite.contentMaskY);
        put(sprite.contentMaskWidth);
        put(sprite.contentMaskHeight);
        put(sprite.colorH);
        put(sprite.colorS);
        put(sprite.colorL);
        put(sprite.colorA);
        put(sprite.transformM00);
        put(sprite.transformM01);
        put(sprite.transformM10);
        put(sprite.transformM11);
        put(sprite.transformTx);
        put(sprite.transformTy);

        // Corners after the sprite transformation, like `SceneRenderable.drawMonochromeSprites()`
        var gx0 = Math.POSITIVE_INFINITY;
        var gy0 = Math.POSITIVE_INFINITY;
        var gx1 = Math.NEGATIVE_INFINITY;
        var gy1 = Math.NEGATIVE_INFINITY;
        var nan = false;
        for (i in 0...4) {
            final px = sprite.boundsX + ((i == 1 || i == 2) ? 1.0 : 0.0) * sprite.boundsWidth;
            final py = sprite.boundsY + ((i >= 2) ? 1.0 : 0.0) * sprite.boundsHeight;
            final sx = sprite.transformM00 * px + sprite.transformM01 * py + sprite.transformTx;
            final sy = sprite.transformM10 * px + sprite.transformM11 * py + sprite.transformTy;
            if (sx < gx0) gx0 = sx;
            if (sy < gy0) gy0 = sy;
            if (sx > gx1) gx1 = sx;
            if (sy > gy1) gy1 = sy;
            if (sx != sx || sy != sy) nan = true;
        }
        if (nan) gx0 = Math.NaN;
        end(gx0, gy0, gx1, gy1, sprite.contentMaskX, sprite.contentMaskY, sprite.contentMaskWidth, sprite.contentMaskHeight);

    }

    @:noDebug
    function recordPath(path:PathSprite):Void {

        begin(5);
        put(path.textureIndex);
        put(path.tileX);
        put(path.tileY);
        put(path.tileWidth);
        put(path.tileHeight);
        put(path.boundsX);
        put(path.boundsY);
        put(path.boundsWidth);
        put(path.boundsHeight);
        put(path.contentMaskX);
        put(path.contentMaskY);
        put(path.contentMaskWidth);
        put(path.contentMaskHeight);
        put(path.colorH);
        put(path.colorS);
        put(path.colorL);
        put(path.colorA);
        put(path.spriteX);
        put(path.spriteY);
        put(path.spriteWidth);
        put(path.spriteHeight);
        final background = path.background;
        if (background == null) {
            put(-1);
        }
        else {
            put(cast(background.tag, Int));
            put(cast(background.colorSpace, Int));
            put(background.gradientAngleOrPatternHeight);
            final c0 = background.colors0;
            put(c0.color.h);
            put(c0.color.s);
            put(c0.color.l);
            put(c0.color.a);
            put(c0.percentage);
            final c1 = background.colors1;
            put(c1.color.h);
            put(c1.color.s);
            put(c1.color.l);
            put(c1.color.a);
            put(c1.percentage);
        }
        end(
            path.spriteX, path.spriteY, path.spriteX + path.spriteWidth, path.spriteY + path.spriteHeight,
            path.contentMaskX, path.contentMaskY, path.contentMaskWidth, path.contentMaskHeight
        );

    }

    @:noDebug
    function recordPolychromeSprite(sprite:PolychromeSprite):Void {

        begin(6);
        put(sprite.textureIndex);
        put(sprite.tileX);
        put(sprite.tileY);
        put(sprite.tileWidth);
        put(sprite.tileHeight);
        put(sprite.boundsX);
        put(sprite.boundsY);
        put(sprite.boundsWidth);
        put(sprite.boundsHeight);
        put(sprite.contentMaskX);
        put(sprite.contentMaskY);
        put(sprite.contentMaskWidth);
        put(sprite.contentMaskHeight);
        put(sprite.cornerRadiusTopLeft);
        put(sprite.cornerRadiusTopRight);
        put(sprite.cornerRadiusBottomRight);
        put(sprite.cornerRadiusBottomLeft);
        put(sprite.grayscale ? 1 : 0);
        put(sprite.opacity);
        end(
            sprite.boundsX, sprite.boundsY, sprite.boundsX + sprite.boundsWidth, sprite.boundsY + sprite.boundsHeight,
            sprite.contentMaskX, sprite.contentMaskY, sprite.contentMaskWidth, sprite.contentMaskHeight
        );

    }

/// Unchecked reads (indices below the recorded lengths)

    static inline function rect(array:Array<Int>, index:Int):Int {
        #if cpp
        return cpp.NativeArray.unsafeGet(array, index);
        #else
        return array[index];
        #end
    }

    static inline function start(array:Array<Int>, index:Int):Int {
        #if cpp
        return cpp.NativeArray.unsafeGet(array, index);
        #else
        return array[index];
        #end
    }

    static inline function setInt(array:Array<Int>, index:Int, value:Int):Void {
        #if cpp
        cpp.NativeArray.unsafeSet(array, index, value);
        #else
        array[index] = value;
        #end
    }

    static inline function value(array:Array<Float>, index:Int):Float {
        #if cpp
        return cpp.NativeArray.unsafeGet(array, index);
        #else
        return array[index];
        #end
    }

}
