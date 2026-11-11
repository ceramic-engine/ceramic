// New code for the Haxe port of GPUI (no GPUI origin): in place rendering
// of a view (see Window and NOTICE.md).
package glaze;

/**
 * How one array of the last frame (hitboxes, dispatch nodes, accessed
 * element states, paint operations...) changes when a view is rendered
 * again alone, in place (see `Window`, in place rendering).
 *
 * While the view renders, its new entries are appended to the array (after
 * `base`, the length of the frame's part), one block per range the view
 * had in the frame (most arrays have one range: the view's prepaint or
 * paint range; the accessed element states have three: layout, prepaint
 * and paint). `apply()` then puts each block in place of the view's old
 * range, and keeps the other appended entries (drawn after the view, like
 * a tooltip shown in this frame) after the frame's part, in order.
 *
 * The indices recorded by the views of the frame (`PrepaintStateIndex`,
 * `PaintIndex`, ...) are positions between entries, each captured at a
 * time of `Window.captureClock`: `remapOld()` moves an index recorded in
 * the frame (the capture time tells on which side of an empty range it
 * lies, and whether it was recorded inside the view, then stale),
 * `remapNew()` an index recorded while the view rendered again.
 * `remapEntry()` moves the index of an entry (a dispatch node's parent).
 */
@:noCompletion
class FrameSplice {

    /** Length of the frame's part of the array (where the appended entries start) */
    public var base(default, null):Int = 0;

    /** Length of the array before `apply()` */
    public var length(default, null):Int = 0;

    /** Number of ranges */
    public var count(default, null):Int = 0;

    /**
     * Whether the array is rebuilt by the window (paint operations, tab
     * stops): there is nothing to apply; the view's block was recorded in
     * an array of its own (from 0) and replayed in place of its range, the
     * other indices recorded while it rendered again are final.
     */
    public var rebuilt(default, null):Bool = false;

    final oldStarts:Array<Int> = [];
    final oldEnds:Array<Int> = [];
    final oldStartTimes:Array<Float> = [];
    final oldEndTimes:Array<Float> = [];
    final blockStarts:Array<Int> = [];
    final blockEnds:Array<Int> = [];
    final blockStartTimes:Array<Float> = [];
    final blockEndTimes:Array<Float> = [];

    /** Position of each block after `apply()` */
    final newStarts:Array<Int> = [];

    /** Length of the frame's part after `apply()` */
    var newBase:Int = 0;

    /** Whether every block has the length of the range it replaces */
    var sameLengths:Bool = true;

    /**
     * Whether the appended entries before the first block are dropped
     * (`dropLeading` of `reset`): entries of no range, recorded before the
     * view's ranges (line layouts used while the view rendered).
     */
    var dropLeading:Bool = false;

    /** Number of entries dropped by `dropLeading` */
    var leading:Int = 0;

    public function new() {}

    /**
     * Starts a new plan for an array whose frame part has `base` entries.
     */
    public function reset(base:Int, rebuilt:Bool = false, dropLeading:Bool = false):Void {
        this.base = base;
        this.length = base;
        this.rebuilt = rebuilt;
        this.dropLeading = dropLeading;
        leading = 0;
        count = 0;
        oldStarts.resize(0);
        oldEnds.resize(0);
        oldStartTimes.resize(0);
        oldEndTimes.resize(0);
        blockStarts.resize(0);
        blockEnds.resize(0);
        blockStartTimes.resize(0);
        blockEndTimes.resize(0);
        newStarts.resize(0);
        newBase = base;
        sameLengths = true;
    }

    /**
     * Adds a range of the view, in position order: `oldStart...oldEnd`
     * recorded at times `oldStartTime` and `oldEndTime` in the frame, to be
     * replaced by `blockStart...blockEnd` recorded at `blockStartTime` and
     * `blockEndTime` (for a rebuilt array, the block is already in place:
     * `blockStart` is `oldStart`).
     */
    public function addRange(oldStart:Int, oldEnd:Int, oldStartTime:Float, oldEndTime:Float, blockStart:Int, blockEnd:Int, blockStartTime:Float, blockEndTime:Float):Void {
        oldStarts.push(oldStart);
        oldEnds.push(oldEnd);
        oldStartTimes.push(oldStartTime);
        oldEndTimes.push(oldEndTime);
        blockStarts.push(blockStart);
        blockEnds.push(blockEnd);
        blockStartTimes.push(blockStartTime);
        blockEndTimes.push(blockEndTime);
        count++;
    }

    /**
     * Ends the plan: the array has `length` entries (frame part and
     * appended part).
     */
    public function prepare(length:Int):Void {
        this.length = length;
        var shift = 0;
        sameLengths = true;
        for (k in 0...count) {
            newStarts.push(oldStarts[k] + shift);
            final delta = (blockEnds[k] - blockStarts[k]) - (oldEnds[k] - oldStarts[k]);
            if (delta != 0) {
                sameLengths = false;
            }
            shift += delta;
        }
        newBase = base + shift;
        leading = dropLeading && count > 0 ? blockStarts[0] - base : 0;
    }

    /** Whether the indices recorded in the frame outside the view keep their values */
    public inline function framePartUnchanged():Bool {
        return sameLengths;
    }

    /** Whether nothing moves at all (no range, nothing appended) */
    public inline function isEmpty():Bool {
        return count == 0 && length == base;
    }

    /** Length of the array after `apply()` */
    public inline function newLength():Int {
        return rebuilt ? length : newBase + (length - base) - appendedInBlocks() - leading;
    }

    function appendedInBlocks():Int {
        var total = 0;
        for (k in 0...count) {
            total += blockEnds[k] - blockStarts[k];
        }
        return total;
    }

    /**
     * The index, after the splice, of an index recorded in the frame at
     * capture time `time`: -1 when it was recorded inside the view (stale).
     */
    public function remapOld(index:Int, time:Float):Int {
        var result = index;
        for (k in 0...count) {
            final endTime = oldEndTimes[k];
            if (time > oldStartTimes[k] && time < endTime) {
                return -1;
            }
            if (time >= endTime) {
                result += (blockEnds[k] - blockStarts[k]) - (oldEnds[k] - oldStarts[k]);
            }
        }
        return result;
    }

    /**
     * The index, after the splice, of an index recorded while the view
     * rendered again (at capture time `time`).
     */
    public function remapNew(index:Int, time:Float):Int {
        if (rebuilt) {
            // The block was recorded from 0 (see `rebuilt`), the rest in place
            for (k in 0...count) {
                if (time >= blockStartTimes[k] && time <= blockEndTimes[k]) {
                    return newStarts[k] + (index - blockStarts[k]);
                }
            }
            return index;
        }
        for (k in 0...count) {
            if (time >= blockStartTimes[k] && time <= blockEndTimes[k]) {
                return newStarts[k] + (index - blockStarts[k]);
            }
        }
        var result = newBase + (index - base) - leading;
        for (k in 0...count) {
            if (time > blockEndTimes[k]) {
                result -= blockEnds[k] - blockStarts[k];
            }
        }
        return result;
    }

    /**
     * The index, after the splice, of the entry at `index` (-1 when it was
     * in a replaced range).
     */
    public function remapEntry(index:Int):Int {
        if (index < base) {
            var result = index;
            for (k in 0...count) {
                if (index < oldStarts[k]) {
                    break;
                }
                if (index < oldEnds[k]) {
                    return -1;
                }
                result += (blockEnds[k] - blockStarts[k]) - (oldEnds[k] - oldStarts[k]);
            }
            return result;
        }
        for (k in 0...count) {
            if (index >= blockStarts[k] && index < blockEnds[k]) {
                return newStarts[k] + (index - blockStarts[k]);
            }
        }
        var result = newBase + (index - base);
        for (k in 0...count) {
            if (index >= blockEnds[k]) {
                result -= blockEnds[k] - blockStarts[k];
            }
        }
        return result;
    }

    public inline function oldStart(k:Int):Int return oldStarts[k];

    public inline function oldEnd(k:Int):Int return oldEnds[k];

    public inline function blockStart(k:Int):Int return blockStarts[k];

    public inline function blockEnd(k:Int):Int return blockEnds[k];

    /** First position whose entry may change */
    inline function firstChange():Int {
        return count > 0 ? oldStarts[0] : base;
    }

    /**
     * Applies the plan to `array` (`scratch`: an array of the same type,
     * empty, used when the lengths differ). Entries of the replaced ranges
     * are dropped.
     */
    @:generic
    public static function apply<T>(array:Array<T>, plan:FrameSplice, scratch:Array<T>):Void {
        if (plan.rebuilt || plan.isEmpty()) {
            return;
        }
        final count = plan.count;
        final length = plan.length;
        final base = plan.base;
        if (plan.sameLengths) {
            // Blocks over their ranges, then the other appended entries down
            for (k in 0...count) {
                final from = plan.blockStarts[k];
                final to = plan.oldStarts[k];
                for (j in 0...plan.blockEnds[k] - from) {
                    array[to + j] = array[from + j];
                }
            }
            var write = base;
            var read = base + plan.leading;
            for (k in 0...count) {
                final start = plan.blockStarts[k];
                while (read < start) {
                    array[write++] = array[read++];
                }
                read = plan.blockEnds[k];
            }
            while (read < length) {
                array[write++] = array[read++];
            }
            array.resize(write);
            return;
        }
        final first = plan.firstChange();
        var position = first;
        for (k in 0...count) {
            for (i in position...plan.oldStarts[k]) scratch.push(array[i]);
            for (i in plan.blockStarts[k]...plan.blockEnds[k]) scratch.push(array[i]);
            position = plan.oldEnds[k];
        }
        for (i in position...base) scratch.push(array[i]);
        var read = base + plan.leading;
        for (k in 0...count) {
            final start = plan.blockStarts[k];
            while (read < start) {
                scratch.push(array[read++]);
            }
            read = plan.blockEnds[k];
        }
        while (read < length) {
            scratch.push(array[read++]);
        }
        final newLength = first + scratch.length;
        for (i in 0...scratch.length) {
            array[first + i] = scratch[i];
        }
        array.resize(newLength);
        scratch.resize(0);
    }

    /**
     * `apply()` for an array of pooled objects (dispatch nodes): the entries
     * of the replaced ranges are kept after the new length (with the rest
     * of the pool) instead of being dropped. Returns the new length.
     */
    @:generic
    public static function applyPooled<T>(array:Array<T>, plan:FrameSplice, scratch:Array<T>):Int {
        if (plan.isEmpty()) {
            return plan.length;
        }
        final count = plan.count;
        final length = plan.length;
        final base = plan.base;
        if (plan.sameLengths) {
            for (k in 0...count) {
                final from = plan.blockStarts[k];
                final to = plan.oldStarts[k];
                for (j in 0...plan.blockEnds[k] - from) {
                    final entry = array[to + j];
                    array[to + j] = array[from + j];
                    array[from + j] = entry;
                }
            }
            var write = base;
            var read = base;
            for (k in 0...count) {
                final start = plan.blockStarts[k];
                while (read < start) {
                    final entry = array[write];
                    array[write++] = array[read];
                    array[read++] = entry;
                }
                read = plan.blockEnds[k];
            }
            while (read < length) {
                final entry = array[write];
                array[write++] = array[read];
                array[read++] = entry;
            }
            return write;
        }
        final first = plan.firstChange();
        var position = first;
        for (k in 0...count) {
            for (i in position...plan.oldStarts[k]) scratch.push(array[i]);
            for (i in plan.blockStarts[k]...plan.blockEnds[k]) scratch.push(array[i]);
            position = plan.oldEnds[k];
        }
        for (i in position...base) scratch.push(array[i]);
        var read = base;
        for (k in 0...count) {
            final start = plan.blockStarts[k];
            while (read < start) {
                scratch.push(array[read++]);
            }
            read = plan.blockEnds[k];
        }
        while (read < length) {
            scratch.push(array[read++]);
        }
        final newLength = first + scratch.length;
        // The entries of the replaced ranges, kept for the pool
        for (k in 0...count) {
            for (i in plan.oldStarts[k]...plan.oldEnds[k]) scratch.push(array[i]);
        }
        for (i in 0...scratch.length) {
            array[first + i] = scratch[i];
        }
        scratch.resize(0);
        return newLength;
    }

}
