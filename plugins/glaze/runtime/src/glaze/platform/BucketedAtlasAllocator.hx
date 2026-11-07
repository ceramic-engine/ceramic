// Ported from etagere 0.2.15: src/bucketed.rs (BucketedAtlasAllocator)
// Original code Copyright 2020 Nicolas Silva, licensed under MIT or Apache-2.0 (at your option).
// Modified: translated from Rust to Haxe for Ceramic (default options only:
// horizontal shelves, alignment 1x1, one column; no grow() or SVG dump). See NOTICE.md.
package gpui.platform;

/**
 * A faster but less precise shelf packing dynamic texture atlas allocator,
 * inspired by https://github.com/mapbox/shelf-pack/
 *
 * Items are accumulated into buckets which are laid out in rows (shelves)
 * of variable height. When allocating, a suitable bucket is looked up first.
 * If none is found, a new shelf of the desired height is pushed.
 *
 * Lifetime isn't tracked at item granularity: items are grouped into
 * buckets and deallocation happens per bucket when all items of the bucket
 * are removed. When the top-most shelf is empty, it is removed, potentially
 * cascading into garbage-collecting the next shelf, etc.
 *
 * This is the allocator of GPUI's Metal atlas (`MetalAtlasTexture`): the
 * port uses it for polychrome pages so that tiles land exactly where GPUI
 * puts them (tiles are not padded, the neighbours of a tile take part in
 * its bilinear filtering like in GPUI).
 */
class BucketedAtlasAllocator {

    static inline final BIN_BITS:Int = 12;
    static inline final ITEM_BITS:Int = 12;
    static inline final GEN_BITS:Int = 8;

    static inline final BIN_MASK:Int = (1 << BIN_BITS) - 1;
    static inline final ITEM_MASK:Int = ((1 << ITEM_BITS) - 1) << BIN_BITS;
    static inline final GEN_MASK:Int = ((1 << GEN_BITS) - 1) << (BIN_BITS + ITEM_BITS);

    static inline final MAX_ITEMS_PER_BIN:Int = ITEM_MASK >> 12;
    static inline final MAX_BIN_COUNT:Int = BIN_MASK;
    static inline final MAX_SHELF_COUNT:Int = 65535;

    /** `BucketIndex::INVALID` */
    static inline final INVALID:Int = 65535;

    final shelves:Array<AtlasShelf> = [];
    final buckets:Array<AtlasBucket> = [];
    var availableHeight:Int;
    public final width:Int;
    public final height:Int;
    var firstUnallocatedBucket:Int = INVALID;
    var currentColumn:Int = 0;
    final columnWidth:Int;
    final numColumns:Int = 1;
    var allocatedSpace:Int = 0;

    /** Result of the last successful `allocate()` */
    public var allocationId(default, null):Int = 0;
    public var allocationX(default, null):Int = 0;
    public var allocationY(default, null):Int = 0;

    public function new(width:Int, height:Int) {
        if (width >= 65535 || height >= 65535)
            throw 'Atlas size too large: ${width}x$height';
        this.width = width;
        this.height = height;
        availableHeight = height;
        columnWidth = Std.int(width / numColumns);
    }

    public function clear():Void {
        shelves.resize(0);
        buckets.resize(0);
        firstUnallocatedBucket = INVALID;
        availableHeight = height;
        currentColumn = 0;
        allocatedSpace = 0;
    }

    public inline function isEmpty():Bool {
        return shelves.length == 0;
    }

    /** Amount of occupied space in the atlas. */
    public inline function getAllocatedSpace():Int {
        return allocatedSpace;
    }

    /** How much space is available for future allocations. */
    public inline function freeSpace():Int {
        return width * height - allocatedSpace;
    }

    /**
     * Allocate a rectangle in the atlas. Returns false when it does not fit,
     * otherwise the allocation is in `allocationId`, `allocationX` and
     * `allocationY`.
     */
    public function allocate(requestedWidth:Int, requestedHeight:Int):Bool {
        if (requestedWidth <= 0 || requestedHeight <= 0 || requestedWidth > 65535 || requestedHeight > 65535)
            return false;

        // adjust_size() with the default 1x1 alignment is a no-op

        if (requestedWidth > columnWidth || requestedHeight > height)
            return false;

        final w = requestedWidth;
        final h = requestedHeight;

        var selectedShelf = -1;
        var selectedBucket = INVALID;
        var bestWaste = 65535;

        final canAddShelf = (availableHeight >= h || currentColumn + 1 < numColumns)
            && shelves.length < MAX_SHELF_COUNT
            && buckets.length < MAX_BIN_COUNT;

        var shelfIndex = 0;
        final shelfCount = shelves.length;
        while (shelfIndex < shelfCount) {
            final shelf = shelves[shelfIndex];
            if (shelf.height < h || shelf.bucketWidth < w) {
                shelfIndex++;
                continue;
            }

            final yWaste = shelf.height - h;
            if (yWaste > bestWaste || (canAddShelf && yWaste > h)) {
                shelfIndex++;
                continue;
            }

            var found = false;
            var bucketIndex = shelf.firstBucket;
            while (bucketIndex != INVALID) {
                final bucket = buckets[bucketIndex];

                if (bucket.freeSpace >= w && bucket.itemCount < MAX_ITEMS_PER_BIN) {
                    if (yWaste == 0 && bucket.freeSpace == w) {
                        selectedShelf = shelfIndex;
                        selectedBucket = bucketIndex;
                        found = true;
                        break;
                    }

                    if (yWaste < bestWaste) {
                        bestWaste = yWaste;
                        selectedShelf = shelfIndex;
                        selectedBucket = bucketIndex;
                        break;
                    }
                }

                bucketIndex = bucket.next;
            }
            // `break 'shelves` on an exact fit
            if (found)
                break;
            shelfIndex++;
        }

        if (selectedBucket == INVALID) {
            if (canAddShelf) {
                selectedShelf = addShelf(w, h);
                selectedBucket = shelves[selectedShelf].firstBucket;
            }
            else {
                // Attempt to merge some empty shelves to make a big enough spot.
                selectedShelf = coalesceShelves(w, h);
                selectedBucket = selectedShelf >= 0 ? shelves[selectedShelf].firstBucket : INVALID;
                if (selectedShelf < 0)
                    selectedShelf = 0;
            }
        }

        if (selectedBucket != INVALID) {
            allocFromBucket(selectedShelf, selectedBucket, w);
            return true;
        }

        return false;
    }

    /**
     * Deallocate a rectangle in the atlas.
     *
     * Space is only reclaimed when all items of the same bucket are deallocated.
     */
    public function deallocate(id:Int):Void {
        if (deallocateFromBucket(id))
            cleanupShelves();
    }

    function allocFromBucket(shelfIndex:Int, bucketIndex:Int, width:Int):Void {
        final shelf = shelves[shelfIndex];
        final bucket = buckets[bucketIndex];

        final minX = bucket.x + shelf.bucketWidth - bucket.freeSpace;
        final minY = shelf.y;

        bucket.freeSpace -= width;
        bucket.refcount += 1;
        bucket.itemCount += 1;

        allocationId = (bucketIndex & BIN_MASK)
            | ((bucket.itemCount << 12) & ITEM_MASK)
            | ((bucket.generation & 0xFF) << 24);
        allocationX = minX;
        allocationY = minY;

        allocatedSpace += width * shelf.height;
    }

    function addBucket(bucket:AtlasBucket):Int {
        var bucketIndex = firstUnallocatedBucket;

        if (bucketIndex == INVALID) {
            bucketIndex = buckets.length;
            buckets.push(bucket);
        }
        else {
            bucket.generation = (buckets[bucketIndex].generation + 1) & 0xFF;
            firstUnallocatedBucket = buckets[bucketIndex].next;
            buckets[bucketIndex] = bucket;
        }

        return bucketIndex;
    }

    function addShelf(width:Int, height:Int):Int {
        final canAddColumn = currentColumn + 1 < numColumns;

        if (availableHeight != 0 && availableHeight < height && canAddColumn) {
            // We have room to add a shelf in a new column but current one doesn't have
            // enough available space. First add a shelf to fill the current column's
            // remaining height.
            addShelf(0, availableHeight);
        }

        if (availableHeight == 0 && canAddColumn) {
            currentColumn += 1;
            availableHeight = this.height;
        }

        final height = Std.int(Math.min(shelfHeight(height), availableHeight));
        final numBuckets = this.numBuckets(width, height);
        // Alignment of 1: no rounding of the bucket width
        final bucketWidth = Std.int(columnWidth / numBuckets);
        final y = this.height - availableHeight;
        availableHeight -= height;

        final shelfIndex = shelves.length;

        // Initialize the buckets for our new shelf.
        var x = currentColumn * columnWidth;
        var bucketNext = INVALID;
        for (_ in 0...numBuckets) {
            final bucket = new AtlasBucket(x, bucketWidth, bucketNext, shelfIndex);
            x += bucketWidth;
            bucketNext = addBucket(bucket);
        }

        shelves.push(new AtlasShelf(currentColumn * columnWidth, y, height, bucketWidth, bucketNext));

        return shelfIndex;
    }

    /**
     * Find a sequence of consecutive shelves that can be coalesced into a single one
     * tall enough to fit the provided size, grow the height of the first shelf and
     * squash the other ones to zero. Returns the index of the first shelf, or -1.
     */
    function coalesceShelves(w:Int, h:Int):Int {
        final len = shelves.length;
        var rangeStart = -1;
        var rangeEnd = -1;
        var coalescedHeight = 0;

        for (shelfIndex in 0...len) {
            if (shelves[shelfIndex].bucketWidth < w)
                continue;
            if (!shelfIsEmpty(shelfIndex))
                continue;
            final shelfX = shelves[shelfIndex].x;
            coalescedHeight = shelves[shelfIndex].height;
            var stop = false;
            for (i in 1...3) {
                // etagere indexes `shelf_index + i` before checking the length
                // (a panic past the end): stop there instead
                if (shelfIndex + i >= len) {
                    stop = true;
                    break;
                }
                if (shelves[shelfIndex + i].x != shelfX) {
                    // Can't coalesce shelves from different columns.
                    break;
                }
                if (!shelfIsEmpty(shelfIndex + i))
                    break;

                coalescedHeight += shelves[shelfIndex + i].height;

                if (coalescedHeight >= h) {
                    rangeStart = shelfIndex;
                    rangeEnd = shelfIndex + i + 1;
                    stop = true;
                    break;
                }
            }
            if (stop)
                break;
        }

        if (rangeStart >= 0) {
            final yTop = shelves[rangeStart].y + coalescedHeight;
            for (i in rangeStart + 1...rangeEnd) {
                shelves[i].y = yTop;
                shelves[i].height = 0;
            }
            shelves[rangeStart].height = coalescedHeight;
            return rangeStart;
        }

        return -1;
    }

    function numBuckets(width:Int, height:Int):Int {
        final n = Std.int(columnWidth / Std.int(Math.max(width, height)));
        final count = if (n <= 4) {
            1;
        }
        else if (n <= 16) {
            2;
        }
        else if (n <= 32) {
            4;
        }
        else {
            nextPowerOfTwo(Std.int(n / 16) - 1);
        }
        return Std.int(Math.min(count, MAX_BIN_COUNT - buckets.length));
    }

    /**
     * Returns true if we should garbage-collect the shelves as a result of
     * removing this element (we deallocated the last item from the bucket on
     * the top-most shelf).
     */
    function deallocateFromBucket(id:Int):Bool {
        final bucketIndex = id & BIN_MASK;
        final generation = (id & GEN_MASK) >>> 24;

        final bucket = buckets[bucketIndex];

        if (generation != bucket.generation)
            throw 'Atlas allocation $id has a stale generation';
        if (bucket.refcount <= 0)
            throw 'Atlas allocation $id was already deallocated';
        bucket.refcount -= 1;

        final shelf = shelves[bucket.shelf];

        final bucketIsEmpty = bucket.refcount == 0;
        if (bucketIsEmpty) {
            allocatedSpace -= (shelf.bucketWidth - bucket.freeSpace) * shelf.height;
            bucket.freeSpace = shelf.bucketWidth;
        }

        return bucketIsEmpty && bucket.shelf == shelves.length - 1;
    }

    function cleanupShelves():Void {
        while (shelves.length > 0) {
            final shelf = shelves[shelves.length - 1];
            var bucketIndex = shelf.firstBucket;
            var lastBucket = shelf.firstBucket;

            while (bucketIndex != INVALID) {
                final bucket = buckets[bucketIndex];

                if (bucket.refcount != 0)
                    return;

                lastBucket = bucketIndex;
                bucketIndex = bucket.next;
            }

            // We didn't run into any bucket on this shelf with live elements,
            // this means we can remove it.

            // Add the buckets to the free list.
            buckets[lastBucket].next = firstUnallocatedBucket;
            firstUnallocatedBucket = shelf.firstBucket;

            if (shelf.y == 0 && currentColumn > 0) {
                currentColumn -= 1;
                final prevShelf = shelves[shelves.length - 2];
                availableHeight = height - (prevShelf.y + prevShelf.height);
            }
            else {
                // Reclaim the height of the shelf.
                availableHeight += shelf.height;
            }

            shelves.pop();
        }
    }

    function shelfIsEmpty(idx:Int):Bool {
        final shelf = shelves[idx];
        var bucketIndex = shelf.firstBucket;

        while (bucketIndex != INVALID) {
            final bucket = buckets[bucketIndex];

            if (bucket.refcount != 0)
                return false;

            bucketIndex = bucket.next;
        }

        return true;
    }

    static function shelfHeight(size:Int):Int {
        final alignment = if (size <= 31) {
            8;
        }
        else if (size <= 127) {
            16;
        }
        else if (size <= 511) {
            32;
        }
        else {
            64;
        }

        final rem = size % alignment;
        if (rem > 0)
            size += alignment - rem;

        return size;
    }

    static function nextPowerOfTwo(n:Int):Int {
        var p = 1;
        while (p < n)
            p <<= 1;
        return p;
    }

}

private class AtlasShelf {

    public var x:Int;
    public var y:Int;
    public var height:Int;
    public var bucketWidth:Int;
    public var firstBucket:Int;

    public function new(x:Int, y:Int, height:Int, bucketWidth:Int, firstBucket:Int) {
        this.x = x;
        this.y = y;
        this.height = height;
        this.bucketWidth = bucketWidth;
        this.firstBucket = firstBucket;
    }

}

private class AtlasBucket {

    public var x:Int;
    public var freeSpace:Int;
    public var next:Int;
    /** Buckets are cleared when their reference count goes back to zero. */
    public var refcount:Int = 0;
    /**
     * Similar to refcount except that the counter is not decremented when an
     * item is deallocated (allocation ids stay unique within a bucket).
     */
    public var itemCount:Int = 0;
    public var shelf:Int;
    public var generation:Int = 0;

    public function new(x:Int, freeSpace:Int, next:Int, shelf:Int) {
        this.x = x;
        this.freeSpace = freeSpace;
        this.next = next;
        this.shelf = shelf;
    }

}
