// Ported from gpui-pre 0.3.10: src/scene.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package glaze.scene;

import haxe.ds.ArraySort;

/**
 * The list of primitives painted during a frame, in scaled pixels.
 *
 * Usage while painting: get a pooled primitive with `nextQuad()` (and
 * friends), fill it, then `commitQuad()` it. Committing computes its draw
 * order from its clipped bounds (or the current layer), or drops it when
 * it is fully clipped. After painting, `finish()` sorts primitives, then
 * `nextBatch()` iterates draw batches in painter's order.
 *
 * Like GPUI, the scene also records its paint operations (committed
 * primitives, layer starts and ends) in order, so that a range of them can
 * be replayed into the next frame's scene (`paintIndex()` / `replay()`,
 * used to reuse the paint of cached views). Replayed primitives are copied
 * into this scene's pools and committed again, so draw orders and batches
 * are computed exactly as if they had been painted.
 *
 * Differences with GPUI: primitives are pooled objects with flat fields
 * (see `Primitive`), subpixel sprites and surfaces are not supported yet.
 */
class Scene {

    final primitiveBounds:BoundsTree = new BoundsTree();

    final layerStack:Array<Int> = [];

    var nextSeq:Int = 0;

    /** Paint operations (Rust `paint_operations`): `OP_*` kinds */
    final opKinds:Array<Int> = [];

    /** The primitive of each `OP_PRIMITIVE` operation (null for layers) */
    final opPrimitives:Array<Primitive> = [];

    /** Bounds of `OP_START_LAYER` operations, 4 floats per operation (unused otherwise) */
    final opLayerBounds:Array<Float> = [];

    static inline final OP_PRIMITIVE:Int = 0;
    static inline final OP_START_LAYER:Int = 1;
    static inline final OP_END_LAYER:Int = 2;

    public final shadows:Array<Shadow> = [];
    public final quads:Array<Quad> = [];
    public final paths:Array<PathSprite> = [];
    public final underlines:Array<Underline> = [];
    public final monochromeSprites:Array<MonochromeSprite> = [];
    public final polychromeSprites:Array<PolychromeSprite> = [];

    final shadowPool:Array<Shadow> = [];
    final quadPool:Array<Quad> = [];
    final pathPool:Array<PathSprite> = [];
    final underlinePool:Array<Underline> = [];
    final monochromeSpritePool:Array<MonochromeSprite> = [];
    final polychromeSpritePool:Array<PolychromeSprite> = [];

    /** Batch iteration state (see `nextBatch()`) */
    var shadowsStart:Int = 0;
    var quadsStart:Int = 0;
    var pathsStart:Int = 0;
    var underlinesStart:Int = 0;
    var monochromeSpritesStart:Int = 0;
    var polychromeSpritesStart:Int = 0;

    final batch:PrimitiveBatch = new PrimitiveBatch();

    public function new() {}

    public function clear():Void {

        primitiveBounds.clear();
        layerStack.resize(0);
        nextSeq = 0;
        opKinds.resize(0);
        opPrimitives.resize(0);
        opLayerBounds.resize(0);
        shadows.resize(0);
        quads.resize(0);
        paths.resize(0);
        underlines.resize(0);
        monochromeSprites.resize(0);
        polychromeSprites.resize(0);
        resetBatches();

    }

    /**
     * Number of committed primitives.
     */
    public function len():Int {

        return shadows.length + quads.length + paths.length + underlines.length + monochromeSprites.length + polychromeSprites.length;

    }

    /**
     * Starts a layer: every primitive committed until `popLayer()` shares
     * the same draw order, computed from the given bounds.
     */
    public function pushLayer(x:Float, y:Float, width:Float, height:Float):Void {

        layerStack.push(primitiveBounds.insert(x, y, width, height));
        final index = opKinds.length;
        opKinds.push(OP_START_LAYER);
        opPrimitives.push(null);
        opLayerBounds[index * 4] = x;
        opLayerBounds[index * 4 + 1] = y;
        opLayerBounds[index * 4 + 2] = width;
        opLayerBounds[index * 4 + 3] = height;

    }

    public function popLayer():Void {

        glaze.util.Stacks.drop(layerStack);
        opKinds.push(OP_END_LAYER);
        opPrimitives.push(null);

    }

/// Paint operations

    /**
     * Number of paint operations recorded so far (Rust `Scene::len`, which
     * counts paint operations; `len()` here counts primitives).
     */
    public inline function paintIndex():Int {

        return opKinds.length;

    }

    inline function recordPrimitive(primitive:Primitive):Void {

        opKinds.push(OP_PRIMITIVE);
        opPrimitives.push(primitive);

    }

    /**
     * Replays the paint operations `start...end` of the previous frame's
     * scene into this one (Rust `Scene::replay`): layers are pushed and
     * popped again, primitives are copied and committed again.
     */
    public function replay(start:Int, end:Int, previous:Scene):Void {

        final kinds = previous.opKinds;
        final primitives = previous.opPrimitives;
        final layerBounds = previous.opLayerBounds;
        for (i in start...end) {
            switch kinds[i] {
                case OP_START_LAYER:
                    pushLayer(layerBounds[i * 4], layerBounds[i * 4 + 1], layerBounds[i * 4 + 2], layerBounds[i * 4 + 3]);
                case OP_END_LAYER:
                    popLayer();
                case _:
                    final primitive = primitives[i];
                    switch primitive.kind() {
                        case Quad:
                            final quad = nextQuad();
                            quad.copyFrom(cast primitive);
                            commitQuad(quad);
                        case Shadow:
                            final shadow = nextShadow();
                            shadow.copyFrom(cast primitive);
                            commitShadow(shadow);
                        case Underline:
                            final underline = nextUnderline();
                            underline.copyFrom(cast primitive);
                            commitUnderline(underline);
                        case Path:
                            final path = nextPath();
                            path.copyFrom(cast primitive);
                            commitPath(path);
                        case MonochromeSprite:
                            final sprite = nextMonochromeSprite();
                            sprite.copyMonochromeFrom(cast primitive);
                            commitMonochromeSprite(sprite);
                        case PolychromeSprite:
                            final sprite = nextPolychromeSprite();
                            sprite.copyFrom(cast primitive);
                            commitPolychromeSprite(sprite);
                        case _:
                            throw 'Unsupported primitive kind: ${primitive.kind()}';
                    }
            }
        }

    }

    /**
     * The first difference between the paint operations `start...end` of
     * this scene and `otherStart...otherEnd` of `other` (layers and
     * primitives, draw orders aside), `null` when they draw the same. For
     * `glaze_verify_cache`.
     */
    public function rangeDifference(start:Int, end:Int, other:Scene, otherStart:Int, otherEnd:Int):Null<String> {

        if (end - start != otherEnd - otherStart) {
            return 'paint operations: ${otherEnd - otherStart} cached, ${end - start} rendered';
        }
        for (i in 0...end - start) {
            final index = start + i;
            final otherIndex = otherStart + i;
            final kind = opKinds[index];
            if (kind != other.opKinds[otherIndex]) {
                return 'paint operation $i: not the same kind';
            }
            switch kind {
                case OP_START_LAYER:
                    for (k in 0...4) {
                        if (opLayerBounds[index * 4 + k] != other.opLayerBounds[otherIndex * 4 + k]) {
                            return 'paint operation $i: layer bounds differ';
                        }
                    }
                case OP_PRIMITIVE:
                    final primitive = opPrimitives[index];
                    final cached = other.opPrimitives[otherIndex];
                    if (!primitive.sameDrawing(cached)) {
                        return 'paint operation $i: ${primitive.kind()} at ${primitive.boundsX},${primitive.boundsY} ${primitive.boundsWidth}x${primitive.boundsHeight} differs from the cached ${cached.kind()} at ${cached.boundsX},${cached.boundsY} ${cached.boundsWidth}x${cached.boundsHeight}';
                    }
                case _:
            }
        }
        return null;

    }

    /**
     * Computes the draw order of a primitive and returns true if it must be
     * kept, false if it is fully clipped by its content mask.
     */
    function assignOrder(primitive:Primitive):Bool {

        // Clipped bounds: intersection of the bounds and the content mask
        final left = Math.max(primitive.boundsX, primitive.contentMaskX);
        final top = Math.max(primitive.boundsY, primitive.contentMaskY);
        // In f32, like GPUI's `Bounds<ScaledPixels>::intersect`
        final right = Math.max(left, Math.min(glaze.SpringMath.f32(primitive.boundsX + primitive.boundsWidth), glaze.SpringMath.f32(primitive.contentMaskX + primitive.contentMaskWidth)));
        final bottom = Math.max(top, Math.min(glaze.SpringMath.f32(primitive.boundsY + primitive.boundsHeight), glaze.SpringMath.f32(primitive.contentMaskY + primitive.contentMaskHeight)));
        final width = glaze.SpringMath.f32(right - left);
        final height = glaze.SpringMath.f32(bottom - top);

        if (width <= 0 || height <= 0) {
            return false;
        }

        primitive.order = layerStack.length > 0
            ? layerStack[layerStack.length - 1]
            : primitiveBounds.insert(left, top, width, height);
        primitive.seq = nextSeq++;

        return true;

    }

/// Quads

    /**
     * Returns a pooled quad, reset to default values, to be filled then committed.
     */
    public function nextQuad():Quad {

        final index = quads.length;
        var quad = quadPool[index];
        if (quad == null) {
            quad = new Quad();
            quadPool[index] = quad;
        }
        else {
            quad.reset();
        }
        return quad;

    }

    public function commitQuad(quad:Quad):Void {

        if (assignOrder(quad)) {
            quads.push(quad);
            recordPrimitive(quad);
        }

    }

/// Shadows

    public function nextShadow():Shadow {

        final index = shadows.length;
        var shadow = shadowPool[index];
        if (shadow == null) {
            shadow = new Shadow();
            shadowPool[index] = shadow;
        }
        else {
            shadow.reset();
        }
        return shadow;

    }

    public function commitShadow(shadow:Shadow):Void {

        if (assignOrder(shadow)) {
            shadows.push(shadow);
            recordPrimitive(shadow);
        }

    }

/// Underlines

    public function nextUnderline():Underline {

        final index = underlines.length;
        var underline = underlinePool[index];
        if (underline == null) {
            underline = new Underline();
            underlinePool[index] = underline;
        }
        else {
            underline.reset();
        }
        return underline;

    }

    public function commitUnderline(underline:Underline):Void {

        if (assignOrder(underline)) {
            underlines.push(underline);
            recordPrimitive(underline);
        }

    }

/// Paths

    public function nextPath():PathSprite {

        final index = paths.length;
        var path = pathPool[index];
        if (path == null) {
            path = new PathSprite();
            pathPool[index] = path;
        }
        else {
            path.reset();
        }
        return path;

    }

    public function commitPath(path:PathSprite):Void {

        if (assignOrder(path)) {
            paths.push(path);
            recordPrimitive(path);
        }

    }

/// Monochrome sprites

    public function nextMonochromeSprite():MonochromeSprite {

        final index = monochromeSprites.length;
        var sprite = monochromeSpritePool[index];
        if (sprite == null) {
            sprite = new MonochromeSprite();
            monochromeSpritePool[index] = sprite;
        }
        else {
            sprite.reset();
        }
        return sprite;

    }

    public function commitMonochromeSprite(sprite:MonochromeSprite):Void {

        if (assignOrder(sprite)) {
            monochromeSprites.push(sprite);
            recordPrimitive(sprite);
        }

    }

/// Polychrome sprites

    public function nextPolychromeSprite():PolychromeSprite {

        final index = polychromeSprites.length;
        var sprite = polychromeSpritePool[index];
        if (sprite == null) {
            sprite = new PolychromeSprite();
            polychromeSpritePool[index] = sprite;
        }
        else {
            sprite.reset();
        }
        return sprite;

    }

    public function commitPolychromeSprite(sprite:PolychromeSprite):Void {

        if (assignOrder(sprite)) {
            polychromeSprites.push(sprite);
            recordPrimitive(sprite);
        }

    }

/// Sorting

    final shadowsScratch:Array<Shadow> = [];
    final quadsScratch:Array<Quad> = [];
    final pathsScratch:Array<PathSprite> = [];
    final underlinesScratch:Array<Underline> = [];
    final monochromeSpritesScratch:Array<MonochromeSprite> = [];
    final polychromeSpritesScratch:Array<PolychromeSprite> = [];

    /** `compareByOrder(a, b) < 0` */
    static inline function lessByOrder(a:Primitive, b:Primitive):Bool {

        return a.order < b.order || (a.order == b.order && a.seq < b.seq);

    }

    /** `compareSprites(a, b) < 0` */
    static inline function lessSprite(a:SpritePrimitive, b:SpritePrimitive):Bool {

        return a.order < b.order
            || (a.order == b.order && (a.textureIndex < b.textureIndex
                || (a.textureIndex == b.textureIndex && a.seq < b.seq)));

    }

    static inline final SORT_RUN:Int = 12;

    /**
     * Sorts `a` with `compareByOrder` (stable merge sort, nothing to do when
     * already sorted), `tmp` as scratch space.
     */
    @:generic static function sortByOrder<T:Primitive>(a:Array<T>, tmp:Array<T>):Void {

        final n = a.length;
        var i = 1;
        while (i < n && !lessByOrder(a[i], a[i - 1])) i++;
        if (i >= n) return;
        if (tmp.length < n) tmp.resize(n);

        // Bottom-up merge sort: insertion sort of runs, then merges of
        // runs of doubling width (left run copied to `tmp`)
        var from = 0;
        while (from < n) {
            final to = from + SORT_RUN < n ? from + SORT_RUN : n;
            for (i in (from + 1)...to) {
                final item = a[i];
                var j = i;
                while (j > from && lessByOrder(item, a[j - 1])) {
                    a[j] = a[j - 1];
                    j--;
                }
                a[j] = item;
            }
            from = to;
        }
        var width = SORT_RUN;
        while (width < n) {
            var from = 0;
            while (from + width < n) {
                final middle = from + width;
                final to = middle + width < n ? middle + width : n;
                if (lessByOrder(a[middle], a[middle - 1])) {
                    for (k in from...middle) tmp[k] = a[k];
                    var left = from;
                    var right = middle;
                    var k = from;
                    while (left < middle && right < to) {
                        if (lessByOrder(a[right], tmp[left])) {
                            a[k++] = a[right++];
                        }
                        else {
                            a[k++] = tmp[left++];
                        }
                    }
                    while (left < middle) {
                        a[k++] = tmp[left++];
                    }
                }
                from = to;
            }
            width *= 2;
        }

    }

    /**
     * Sorts `a` with `compareSprites`, like `sortByOrder()`.
     */
    @:generic static function sortSprites<T:SpritePrimitive>(a:Array<T>, tmp:Array<T>):Void {

        final n = a.length;
        var i = 1;
        while (i < n && !lessSprite(a[i], a[i - 1])) i++;
        if (i >= n) return;
        if (tmp.length < n) tmp.resize(n);

        // Bottom-up merge sort: insertion sort of runs, then merges of
        // runs of doubling width (left run copied to `tmp`)
        var from = 0;
        while (from < n) {
            final to = from + SORT_RUN < n ? from + SORT_RUN : n;
            for (i in (from + 1)...to) {
                final item = a[i];
                var j = i;
                while (j > from && lessSprite(item, a[j - 1])) {
                    a[j] = a[j - 1];
                    j--;
                }
                a[j] = item;
            }
            from = to;
        }
        var width = SORT_RUN;
        while (width < n) {
            var from = 0;
            while (from + width < n) {
                final middle = from + width;
                final to = middle + width < n ? middle + width : n;
                if (lessSprite(a[middle], a[middle - 1])) {
                    for (k in from...middle) tmp[k] = a[k];
                    var left = from;
                    var right = middle;
                    var k = from;
                    while (left < middle && right < to) {
                        if (lessSprite(a[right], tmp[left])) {
                            a[k++] = a[right++];
                        }
                        else {
                            a[k++] = tmp[left++];
                        }
                    }
                    while (left < middle) {
                        a[k++] = tmp[left++];
                    }
                }
                from = to;
            }
            width *= 2;
        }

    }

    static function compareByOrder(a:Primitive, b:Primitive):Int {

        if (a.order != b.order) return a.order < b.order ? -1 : 1;
        return a.seq < b.seq ? -1 : (a.seq > b.seq ? 1 : 0);

    }

    static function compareSprites(a:SpritePrimitive, b:SpritePrimitive):Int {

        if (a.order != b.order) return a.order < b.order ? -1 : 1;
        if (a.textureIndex != b.textureIndex) return a.textureIndex < b.textureIndex ? -1 : 1;
        return a.seq < b.seq ? -1 : (a.seq > b.seq ? 1 : 0);

    }

    /**
     * Sorts primitives by draw order (and atlas texture for sprites).
     * Must be called once painting is done, before iterating batches.
     */
    public function finish():Void {

        // Specialized merge sorts (no comparator closure, no allocation
        // once the scratch arrays have grown): the keys (order, texture,
        // seq) are unique, so the result is the one of any correct sort
        sortByOrder(shadows, shadowsScratch);
        sortByOrder(quads, quadsScratch);
        sortByOrder(paths, pathsScratch);
        sortByOrder(underlines, underlinesScratch);
        sortSprites(monochromeSprites, monochromeSpritesScratch);
        sortSprites(polychromeSprites, polychromeSpritesScratch);
        resetBatches();

    }

/// Batches

    /**
     * Restarts batch iteration from the first batch.
     */
    public function resetBatches():Void {

        shadowsStart = 0;
        quadsStart = 0;
        pathsStart = 0;
        underlinesStart = 0;
        monochromeSpritesStart = 0;
        polychromeSpritesStart = 0;

    }

    static inline final NO_ORDER:Int = 0x7FFFFFFF;

    /**
     * Returns the next batch of primitives of a single kind (and single
     * atlas texture for sprites) that can be drawn without breaking the
     * painter's order, or null when every primitive has been batched.
     *
     * The returned object is reused by the next call.
     */
    public function nextBatch():Null<PrimitiveBatch> {

        // Order of the next primitive of each kind (in PrimitiveKind order)
        final shadowOrder = shadowsStart < shadows.length ? shadows[shadowsStart].order : NO_ORDER;
        final quadOrder = quadsStart < quads.length ? quads[quadsStart].order : NO_ORDER;
        final pathOrder = pathsStart < paths.length ? paths[pathsStart].order : NO_ORDER;
        final underlineOrder = underlinesStart < underlines.length ? underlines[underlinesStart].order : NO_ORDER;
        final monoOrder = monochromeSpritesStart < monochromeSprites.length ? monochromeSprites[monochromeSpritesStart].order : NO_ORDER;
        final polyOrder = polychromeSpritesStart < polychromeSprites.length ? polychromeSprites[polychromeSpritesStart].order : NO_ORDER;

        // Like GPUI, consider the (order, kind) pair of every primitive kind
        // (exhausted or unsupported kinds count as (MAX, kind)) and find the
        // smallest and the second smallest pairs
        var firstOrder = NO_ORDER;
        var firstKind = 0x7FFFFFFF;
        var secondOrder = NO_ORDER;
        var secondKind = 0x7FFFFFFF;

        inline function consider(order:Int, kind:Int):Void {
            if (lessThan(order, kind, firstOrder, firstKind)) {
                secondOrder = firstOrder;
                secondKind = firstKind;
                firstOrder = order;
                firstKind = kind;
            }
            else if (lessThan(order, kind, secondOrder, secondKind)) {
                secondOrder = order;
                secondKind = kind;
            }
        }

        consider(shadowOrder, PrimitiveKind.Shadow);
        consider(quadOrder, PrimitiveKind.Quad);
        consider(pathOrder, PrimitiveKind.Path);
        consider(underlineOrder, PrimitiveKind.Underline);
        consider(monoOrder, PrimitiveKind.MonochromeSprite);
        consider(NO_ORDER, PrimitiveKind.SubpixelSprite);
        consider(polyOrder, PrimitiveKind.PolychromeSprite);
        consider(NO_ORDER, PrimitiveKind.Surface);

        if (firstOrder == NO_ORDER) {
            return null;
        }

        final kind:PrimitiveKind = firstKind;
        batch.kind = kind;
        batch.textureIndex = -1;

        switch kind {

            case Shadow:
                final start = shadowsStart;
                var end = start + 1;
                while (end < shadows.length && lessThan(shadows[end].order, firstKind, secondOrder, secondKind)) {
                    end++;
                }
                shadowsStart = end;
                batch.start = start;
                batch.end = end;

            case Quad:
                final start = quadsStart;
                var end = start + 1;
                while (end < quads.length && lessThan(quads[end].order, firstKind, secondOrder, secondKind)) {
                    end++;
                }
                quadsStart = end;
                batch.start = start;
                batch.end = end;

            case Path:
                final start = pathsStart;
                final textureIndex = paths[start].textureIndex;
                var end = start + 1;
                while (end < paths.length
                    && lessThan(paths[end].order, firstKind, secondOrder, secondKind)
                    && paths[end].textureIndex == textureIndex) {
                    end++;
                }
                pathsStart = end;
                batch.start = start;
                batch.end = end;
                batch.textureIndex = textureIndex;

            case Underline:
                final start = underlinesStart;
                var end = start + 1;
                while (end < underlines.length && lessThan(underlines[end].order, firstKind, secondOrder, secondKind)) {
                    end++;
                }
                underlinesStart = end;
                batch.start = start;
                batch.end = end;

            case MonochromeSprite:
                final start = monochromeSpritesStart;
                final textureIndex = monochromeSprites[start].textureIndex;
                var end = start + 1;
                while (end < monochromeSprites.length
                    && lessThan(monochromeSprites[end].order, firstKind, secondOrder, secondKind)
                    && monochromeSprites[end].textureIndex == textureIndex) {
                    end++;
                }
                monochromeSpritesStart = end;
                batch.start = start;
                batch.end = end;
                batch.textureIndex = textureIndex;

            case PolychromeSprite:
                final start = polychromeSpritesStart;
                final textureIndex = polychromeSprites[start].textureIndex;
                var end = start + 1;
                while (end < polychromeSprites.length
                    && lessThan(polychromeSprites[end].order, firstKind, secondOrder, secondKind)
                    && polychromeSprites[end].textureIndex == textureIndex) {
                    end++;
                }
                polychromeSpritesStart = end;
                batch.start = start;
                batch.end = end;
                batch.textureIndex = textureIndex;

            case _:
                throw 'Unsupported primitive kind: $kind';
        }

        return batch;

    }

    /** Lexicographic comparison of (order, kind) pairs */
    static inline function lessThan(orderA:Int, kindA:Int, orderB:Int, kindB:Int):Bool {

        return orderA < orderB || (orderA == orderB && kindA < kindB);

    }

}
