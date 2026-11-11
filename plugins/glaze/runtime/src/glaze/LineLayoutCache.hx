// Ported from gpui-pre 0.3.10: src/text_system/line_layout.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import haxe.ds.IntMap;

/**
 * Caches line layouts for the current and the previous frames: a layout
 * used during a frame is kept for the next two, and dropped if neither
 * uses it (`finishFrame()`).
 *
 * Difference with GPUI (cache policy only, the layouts are the same): Rust
 * keeps the current and the previous frame, so a line that is not shown for
 * one frame is shaped again when it comes back (a list filtered back and
 * forth). Here a third generation (`olderFrame`) keeps the layouts unused
 * during the previous frame for one more frame: a lookup missing in the
 * current and previous frames finds them there and moves them back to the
 * current frame. Shaping is deterministic, so a kept layout is the one the
 * shaping would make again.
 *
 * Like Rust (which hashes a borrowed key), an entry is found by an integer
 * hash of the text, the font size, the runs and the wrap width, then
 * confirmed by comparing those fields: no key string is built on a lookup.
 * Layouts by hash (`layoutLineByHash()`) use the caller's hash instead of
 * the text.
 */
class LineLayoutCache {

    /** Layouts used two frames ago and not since (see the class comment) */
    var olderFrame:FrameCache = new FrameCache();

    var previousFrame:FrameCache = new FrameCache();

    var currentFrame:FrameCache = new FrameCache();

    final platformTextSystem:PlatformTextSystem;

    /** Font generation source (advanced by `TextSystem.addFonts()`) */
    final textSystem:Null<TextSystem>;

    /** Records the generation represented by both frame caches. */
    var cachedFontGeneration:Int;

    public function new(platformTextSystem:PlatformTextSystem, ?textSystem:TextSystem) {
        this.platformTextSystem = platformTextSystem;
        this.textSystem = textSystem;
        cachedFontGeneration = fontGeneration();
    }

    inline function fontGeneration():Int {
        return textSystem != null ? textSystem.fontGeneration : 0;
    }

    public function layoutIndex():LineLayoutIndex {
        final fontGeneration = clearIfFontGenerationChanged();
        final frame = currentFrame;
        return new LineLayoutIndex(fontGeneration, frame.usedLines.length, frame.usedWrappedLines.length, frame.usedLinesByHash.length, frame.usedWrappedLinesByHash.length);
    }

    /**
     * Writes the current layout index into `index` (no allocation).
     */
    public function layoutIndexInto(index:LineLayoutIndex):Void {
        final fontGeneration = clearIfFontGenerationChanged();
        final frame = currentFrame;
        index.fontGeneration = fontGeneration;
        index.linesIndex = frame.usedLines.length;
        index.wrappedLinesIndex = frame.usedWrappedLines.length;
        index.linesByHashIndex = frame.usedLinesByHash.length;
        index.wrappedLinesByHashIndex = frame.usedWrappedLinesByHash.length;
    }

    public function reuseLayouts(start:LineLayoutIndex, end:LineLayoutIndex):Void {
        final fontGeneration = clearIfFontGenerationChanged();
        if (start.fontGeneration != fontGeneration || end.fontGeneration != fontGeneration) {
            return;
        }

        // While amending, the ranges index the amended frame, the current one
        final previous = amendedFrame != null ? amendedFrame : previousFrame;
        final older = olderFrame;
        final current = currentFrame;

        for (i in start.linesIndex...end.linesIndex) {
            final entry = previous.usedLines[i];
            final owner = entry.owner;
            if (owner == previous || owner == older) {
                owner.remove(owner.lines, entry);
                current.insert(current.lines, entry);
            }
            current.usedLines.push(entry);
        }

        for (i in start.wrappedLinesIndex...end.wrappedLinesIndex) {
            final entry = previous.usedWrappedLines[i];
            final owner = entry.owner;
            if (owner == previous || owner == older) {
                owner.remove(owner.wrappedLines, entry);
                current.insert(current.wrappedLines, entry);
            }
            current.usedWrappedLines.push(entry);
        }

        for (i in start.linesByHashIndex...end.linesByHashIndex) {
            final entry = previous.usedLinesByHash[i];
            final owner = entry.owner;
            if (owner == previous || owner == older) {
                owner.remove(owner.linesByHash, entry);
                current.insert(current.linesByHash, entry);
            }
            current.usedLinesByHash.push(entry);
        }

        for (i in start.wrappedLinesByHashIndex...end.wrappedLinesByHashIndex) {
            final entry = previous.usedWrappedLinesByHash[i];
            final owner = entry.owner;
            if (owner == previous || owner == older) {
                owner.remove(owner.wrappedLinesByHash, entry);
                current.insert(current.wrappedLinesByHash, entry);
            }
            current.usedWrappedLinesByHash.push(entry);
        }
    }

    public function truncateLayouts(index:LineLayoutIndex):Void {
        final fontGeneration = clearIfFontGenerationChanged();
        if (index.fontGeneration != fontGeneration) {
            return;
        }
        final frame = currentFrame;
        frame.usedLines.resize(index.linesIndex);
        frame.usedWrappedLines.resize(index.wrappedLinesIndex);
        frame.usedLinesByHash.resize(index.linesByHashIndex);
        frame.usedWrappedLinesByHash.resize(index.wrappedLinesByHashIndex);
    }

/// Amending the previous frame (in place rendering of a view, see `Window`)

    /** The frame being amended (then also `currentFrame`), null otherwise */
    var amendedFrame:Null<FrameCache> = null;

    var amendSavedCurrent:Null<FrameCache> = null;

    var amendSavedOlder:Null<FrameCache> = null;

    /**
     * Starts amending the previous frame: until `endAmend()`, the layouts
     * used are recorded in that frame (it is the current one), ranges reused
     * index it, and lookups search it, then the frame before it.
     */
    public function beginAmend():Void {
        clearIfFontGenerationChanged();
        amendSavedCurrent = currentFrame;
        amendSavedOlder = olderFrame;
        amendedFrame = previousFrame;
        currentFrame = previousFrame;
        previousFrame = amendSavedOlder;
        // The frame being drawn next is empty: nothing to find there
        olderFrame = amendSavedCurrent;
    }

    /** Whether the fonts changed since the layouts were cached (the frames are then dropped) */
    public inline function fontGenerationChanged():Bool {
        return fontGeneration() != cachedFontGeneration;
    }

    /** Ends `beginAmend()` */
    public function endAmend():Void {
        previousFrame = amendedFrame;
        currentFrame = amendSavedCurrent;
        olderFrame = amendSavedOlder;
        amendedFrame = null;
        amendSavedCurrent = null;
        amendSavedOlder = null;
    }

    final spliceScratch:Array<LineCacheEntry> = [];

    /**
     * While amending: applies the splices of the used layouts (one plan per
     * kind, in `LineLayoutIndex` order: lines, wrapped lines, lines by hash,
     * wrapped lines by hash).
     */
    public function spliceUsed(lines:FrameSplice, wrappedLines:FrameSplice, linesByHash:FrameSplice, wrappedLinesByHash:FrameSplice):Void {
        final frame = amendedFrame;
        FrameSplice.apply(frame.usedLines, lines, spliceScratch);
        FrameSplice.apply(frame.usedWrappedLines, wrappedLines, spliceScratch);
        FrameSplice.apply(frame.usedLinesByHash, linesByHash, spliceScratch);
        FrameSplice.apply(frame.usedWrappedLinesByHash, wrappedLinesByHash, spliceScratch);
    }

    /**
     * Drops the used layouts recorded after `index` in the amended frame
     * (an in place rendering abandoned for a full frame: the layouts stay
     * cached, the full frame records them again when it uses them).
     */
    public function truncateAmended(index:LineLayoutIndex):Void {
        final frame = amendedFrame;
        frame.usedLines.resize(index.linesIndex);
        frame.usedWrappedLines.resize(index.wrappedLinesIndex);
        frame.usedLinesByHash.resize(index.linesByHashIndex);
        frame.usedWrappedLinesByHash.resize(index.wrappedLinesByHashIndex);
    }

    public function finishFrame():Void {
        clearIfFontGenerationChanged();
        final older = olderFrame;
        olderFrame = previousFrame;
        previousFrame = currentFrame;
        currentFrame = older;
        currentFrame.clear();
    }

/// Hashing (an integer per key; equal keys hash equal, a collision is resolved by `LineCacheEntry.matches*`)

    static inline function mix(h:Int, v:Int):Int {
        return ((h << 5) - h + v) & 0x7FFFFFFF;
    }

    static function hashFloat(h:Int, value:Null<Float>):Int {
        if (value == null) {
            return mix(h, 0x5bd1e995);
        }
        final v:Float = value;
        if (!Math.isFinite(v)) {
            return mix(h, v > 0 ? 1 : (v < 0 ? 2 : 3));
        }
        // Lossy on purpose: a hash, confirmed by an exact comparison
        final clamped = Math.max(-1e6, Math.min(1e6, v));
        return mix(mix(h, Std.int(clamped)), Std.int((clamped - Math.ffloor(clamped)) * 1048576));
    }

    static function hashRuns(h:Int, runs:Array<FontRun>):Int {
        h = mix(h, runs.length);
        for (i in 0...runs.length) {
            final run = runs[i];
            h = mix(mix(h, run.len), (run.fontId:Int));
        }
        return h;
    }

    static function hashText(h:Int, text:String):Int {
        h = mix(h, text.length);
        for (i in 0...text.length) {
            h = mix(h, StringTools.fastCodeAt(text, i));
        }
        return h;
    }

    static function cacheHash(text:String, fontSize:Float, runs:Array<FontRun>, wrapWidth:Null<Float>, forceWidth:Null<Float>):Int {
        var h = hashFloat(17, fontSize);
        h = hashFloat(h, wrapWidth);
        h = hashFloat(h, forceWidth);
        h = hashRuns(h, runs);
        return hashText(h, text);
    }

    static function hashedCacheHash(textHash:Int, textLen:Int, fontSize:Float, runs:Array<FontRun>, wrapWidth:Null<Float>, forceWidth:Null<Float>):Int {
        var h = mix(mix(23, textHash), textLen);
        h = hashFloat(h, fontSize);
        h = hashFloat(h, wrapWidth);
        h = hashFloat(h, forceWidth);
        return hashRuns(h, runs);
    }

/// Lookups

    /**
     * Layout of a line wrapped at `wrapWidth` (cached). `maxLines` is -1
     * when there is no line clamp.
     */
    public function layoutWrappedLine(text:String, fontSize:Pixels, runs:Array<FontRun>, wrapWidth:Null<Float>, maxLines:Int = -1):WrappedLineLayout {
        clearIfFontGenerationChanged();
        // Rust leaves max_lines out of the key: same behavior here
        final hash = cacheHash(text, fontSize, runs, wrapWidth, null);
        final current = currentFrame;

        final cached = current.findText(current.wrappedLines, hash, text, fontSize, runs, wrapWidth, null);
        if (cached != null) {
            return cached.wrapped;
        }

        var previous = previousFrame;
        var entry = previous.findText(previous.wrappedLines, hash, text, fontSize, runs, wrapWidth, null);
        if (entry == null) {
            previous = olderFrame;
            entry = previous.findText(previous.wrappedLines, hash, text, fontSize, runs, wrapWidth, null);
        }
        if (entry != null) {
            previous.remove(previous.wrappedLines, entry);
            current.insert(current.wrappedLines, entry);
            current.usedWrappedLines.push(entry);
            return entry.wrapped;
        }
        else {
            final unwrappedLayout = layoutLine(text, fontSize, runs, null);
            final wrapBoundaries = wrapWidth != null ? unwrappedLayout.computeWrapBoundaries(text, wrapWidth, maxLines) : [];
            final layout = new WrappedLineLayout(unwrappedLayout, wrapBoundaries, wrapWidth);
            final entry = LineCacheEntry.ofText(hash, text, fontSize, runs, wrapWidth, null);
            entry.wrapped = layout;
            current.insert(current.wrappedLines, entry);
            current.usedWrappedLines.push(entry);
            return layout;
        }
    }

    /**
     * Layout of a single line (cached). `forceWidth` places glyphs on a
     * grid of cells of that width (monospace terminals).
     */
    public function layoutLine(text:String, fontSize:Pixels, runs:Array<FontRun>, forceWidth:Null<Float>):LineLayout {
        clearIfFontGenerationChanged();
        final hash = cacheHash(text, fontSize, runs, null, forceWidth);
        final current = currentFrame;

        final cached = current.findText(current.lines, hash, text, fontSize, runs, null, forceWidth);
        if (cached != null) {
            return cached.layout;
        }

        var previous = previousFrame;
        var entry = previous.findText(previous.lines, hash, text, fontSize, runs, null, forceWidth);
        if (entry == null) {
            previous = olderFrame;
            entry = previous.findText(previous.lines, hash, text, fontSize, runs, null, forceWidth);
        }
        if (entry != null) {
            previous.remove(previous.lines, entry);
            current.insert(current.lines, entry);
            current.usedLines.push(entry);
            return entry.layout;
        }
        else {
            final layout = platformTextSystem.layoutLine(text, fontSize, runs);

            if (forceWidth != null) {
                applyForceWidthToLayout(layout, forceWidth);
            }

            final entry = LineCacheEntry.ofText(hash, text, fontSize, runs, null, forceWidth);
            entry.layout = layout;
            current.insert(current.lines, entry);
            current.usedLines.push(entry);
            return layout;
        }
    }

    /**
     * Try to retrieve a previously-shaped line layout using a caller-provided content hash.
     * Returns null if the layout is not cached in the current or previous frame.
     *
     * Contract (caller enforced): same `textHash` implies identical text content,
     * `textLen` should be the UTF-8 byte length of the text.
     */
    public function tryLayoutLineByHash(textHash:Int, textLen:Int, fontSize:Pixels, runs:Array<FontRun>, forceWidth:Null<Float>):Null<LineLayout> {
        clearIfFontGenerationChanged();
        final hash = hashedCacheHash(textHash, textLen, fontSize, runs, null, forceWidth);
        final current = currentFrame.findHashed(currentFrame.linesByHash, hash, textHash, textLen, fontSize, runs, null, forceWidth);
        if (current != null)
            return current.layout;
        final previous = previousFrame.findHashed(previousFrame.linesByHash, hash, textHash, textLen, fontSize, runs, null, forceWidth);
        if (previous != null)
            return previous.layout;
        final older = olderFrame.findHashed(olderFrame.linesByHash, hash, textHash, textLen, fontSize, runs, null, forceWidth);
        return older != null ? older.layout : null;
    }

    /**
     * Layout a line of text using a caller-provided content hash as the cache key.
     * If the cache misses, `materializeText` is invoked to produce the text.
     */
    public function layoutLineByHash(textHash:Int, textLen:Int, fontSize:Pixels, runs:Array<FontRun>, forceWidth:Null<Float>, materializeText:() -> String):LineLayout {
        clearIfFontGenerationChanged();
        final hash = hashedCacheHash(textHash, textLen, fontSize, runs, null, forceWidth);
        final current = currentFrame;

        final cached = current.findHashed(current.linesByHash, hash, textHash, textLen, fontSize, runs, null, forceWidth);
        if (cached != null) {
            return cached.layout;
        }

        var previous = previousFrame;
        var entry = previous.findHashed(previous.linesByHash, hash, textHash, textLen, fontSize, runs, null, forceWidth);
        if (entry == null) {
            previous = olderFrame;
            entry = previous.findHashed(previous.linesByHash, hash, textHash, textLen, fontSize, runs, null, forceWidth);
        }
        if (entry != null) {
            previous.remove(previous.linesByHash, entry);
            current.insert(current.linesByHash, entry);
            current.usedLinesByHash.push(entry);
            return entry.layout;
        }

        final text = materializeText();
        final layout = platformTextSystem.layoutLine(text, fontSize, runs);

        if (forceWidth != null) {
            applyForceWidthToLayout(layout, forceWidth);
        }

        final newEntry = LineCacheEntry.ofHash(hash, textHash, textLen, fontSize, runs, null, forceWidth);
        newEntry.layout = layout;
        current.insert(current.linesByHash, newEntry);
        current.usedLinesByHash.push(newEntry);
        return layout;
    }

    function clearIfFontGenerationChanged():Int {
        final generation = fontGeneration();
        if (cachedFontGeneration == generation) {
            return generation;
        }

        currentFrame = new FrameCache();
        previousFrame = new FrameCache();
        olderFrame = new FrameCache();
        cachedFontGeneration = generation;
        return generation;
    }

    /**
     * Places glyphs on a grid of `forceWidth` cells.
     *
     * Combining marks (e.g. Thai vowel signs, Arabic diacritics) are shaped by
     * HarfBuzz at the same x position as their base character. The force-width
     * loop must not advance the cell counter for these zero-advance glyphs,
     * otherwise they get displaced into the next cell. We detect them by checking
     * whether shaped x has advanced by at least half a cell beyond the last base.
     */
    public static function applyForceWidthToLayout(layout:LineLayout, forceWidth:Pixels):Void {
        var glyphPos = 0;
        // NEG_INFINITY ensures the first glyph is always classified as a base.
        var lastBaseShapedX:Float = Math.NEGATIVE_INFINITY;
        var lastBaseActualX:Float = 0.0;

        for (run in layout.runs) {
            for (glyph in run.glyphs) {
                final shapedX = glyph.position.x;

                if (shapedX > lastBaseShapedX + forceWidth * 0.5) {
                    final forcedX = glyphPos * (forceWidth:Float);
                    if (Math.abs(shapedX - forcedX) > 1.0) {
                        glyph.position = new Point(forcedX, glyph.position.y);
                    }
                    lastBaseShapedX = shapedX;
                    lastBaseActualX = glyph.position.x;
                    glyphPos += 1;
                }
                else {
                    glyph.position = new Point(lastBaseActualX + (shapedX - lastBaseShapedX), glyph.position.y);
                }
            }
        }
    }

}

/**
 * A cached layout with the key it was shaped for (Rust `CacheKey`): the
 * text (or the caller's text hash and length), the font size, the font
 * runs, the wrap width and the force width.
 */
@:noCompletion
class LineCacheEntry {

    public final hash:Int;

    public final text:Null<String>;

    public final textHash:Int;

    public final textLen:Int;

    public final fontSize:Float;

    /** The runs (a copy: callers may reuse theirs) */
    public final runs:Array<FontRun>;

    public final wrapWidth:Null<Float>;

    public final forceWidth:Null<Float>;

    public var layout:Null<LineLayout> = null;

    public var wrapped:Null<WrappedLineLayout> = null;

    /** The frame cache holding this entry */
    public var owner:Null<FrameCache> = null;

    /** Next entry of the same bucket */
    public var next:Null<LineCacheEntry> = null;

    function new(hash:Int, text:Null<String>, textHash:Int, textLen:Int, fontSize:Float, runs:Array<FontRun>, wrapWidth:Null<Float>, forceWidth:Null<Float>) {
        this.hash = hash;
        this.text = text;
        this.textHash = textHash;
        this.textLen = textLen;
        this.fontSize = fontSize;
        this.runs = runs;
        this.wrapWidth = wrapWidth;
        this.forceWidth = forceWidth;
    }

    public static function ofText(hash:Int, text:String, fontSize:Float, runs:Array<FontRun>, wrapWidth:Null<Float>, forceWidth:Null<Float>):LineCacheEntry {
        return new LineCacheEntry(hash, text, 0, 0, fontSize, copyRuns(runs), wrapWidth, forceWidth);
    }

    public static function ofHash(hash:Int, textHash:Int, textLen:Int, fontSize:Float, runs:Array<FontRun>, wrapWidth:Null<Float>, forceWidth:Null<Float>):LineCacheEntry {
        return new LineCacheEntry(hash, null, textHash, textLen, fontSize, copyRuns(runs), wrapWidth, forceWidth);
    }

    /** The entry keeps its own runs: callers may pass scratch runs they reuse */
    static function copyRuns(runs:Array<FontRun>):Array<FontRun> {
        return [for (run in runs) new FontRun(run.len, run.fontId)];
    }

    static inline function sameOptional(a:Null<Float>, b:Null<Float>):Bool {
        return a == null ? b == null : (b != null && (a:Float) == (b:Float));
    }

    static function sameRuns(a:Array<FontRun>, b:Array<FontRun>):Bool {
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            final ra = a[i];
            final rb = b[i];
            if (ra.len != rb.len || (ra.fontId:Int) != (rb.fontId:Int))
                return false;
        }
        return true;
    }

    public function matchesText(text:String, fontSize:Float, runs:Array<FontRun>, wrapWidth:Null<Float>, forceWidth:Null<Float>):Bool {
        return this.fontSize == fontSize
            && sameOptional(this.wrapWidth, wrapWidth)
            && sameOptional(this.forceWidth, forceWidth)
            && sameRuns(this.runs, runs)
            && this.text == text;
    }

    public function matchesHash(textHash:Int, textLen:Int, fontSize:Float, runs:Array<FontRun>, wrapWidth:Null<Float>, forceWidth:Null<Float>):Bool {
        return this.textHash == textHash
            && this.textLen == textLen
            && this.fontSize == fontSize
            && sameOptional(this.wrapWidth, wrapWidth)
            && sameOptional(this.forceWidth, forceWidth)
            && sameRuns(this.runs, runs);
    }

}

/**
 * The layouts of one frame: buckets by hash (chained entries) and the
 * order in which they were used (for the view cache ranges).
 */
@:noCompletion
class FrameCache {

    public final lines:IntMap<LineCacheEntry> = new IntMap();
    public final wrappedLines:IntMap<LineCacheEntry> = new IntMap();
    public final usedLines:Array<LineCacheEntry> = [];
    public final usedWrappedLines:Array<LineCacheEntry> = [];

    public final linesByHash:IntMap<LineCacheEntry> = new IntMap();
    public final wrappedLinesByHash:IntMap<LineCacheEntry> = new IntMap();
    public final usedLinesByHash:Array<LineCacheEntry> = [];
    public final usedWrappedLinesByHash:Array<LineCacheEntry> = [];

    public function new() {}

    public function findText(map:IntMap<LineCacheEntry>, hash:Int, text:String, fontSize:Float, runs:Array<FontRun>, wrapWidth:Null<Float>, forceWidth:Null<Float>):Null<LineCacheEntry> {
        var entry = map.get(hash);
        while (entry != null) {
            if (entry.text != null && entry.matchesText(text, fontSize, runs, wrapWidth, forceWidth))
                return entry;
            entry = entry.next;
        }
        return null;
    }

    public function findHashed(map:IntMap<LineCacheEntry>, hash:Int, textHash:Int, textLen:Int, fontSize:Float, runs:Array<FontRun>, wrapWidth:Null<Float>, forceWidth:Null<Float>):Null<LineCacheEntry> {
        var entry = map.get(hash);
        while (entry != null) {
            if (entry.text == null && entry.matchesHash(textHash, textLen, fontSize, runs, wrapWidth, forceWidth))
                return entry;
            entry = entry.next;
        }
        return null;
    }

    public function insert(map:IntMap<LineCacheEntry>, entry:LineCacheEntry):Void {
        entry.owner = this;
        entry.next = map.get(entry.hash);
        map.set(entry.hash, entry);
    }

    public function remove(map:IntMap<LineCacheEntry>, entry:LineCacheEntry):Void {
        var head = map.get(entry.hash);
        if (head == entry) {
            if (entry.next != null) {
                map.set(entry.hash, entry.next);
            }
            else {
                map.remove(entry.hash);
            }
        }
        else {
            var prev = head;
            while (prev != null && prev.next != entry) {
                prev = prev.next;
            }
            if (prev != null) {
                prev.next = entry.next;
            }
        }
        entry.next = null;
        entry.owner = null;
    }

    public function clear():Void {
        lines.clear();
        wrappedLines.clear();
        usedLines.resize(0);
        usedWrappedLines.resize(0);
        linesByHash.clear();
        wrappedLinesByHash.clear();
        usedLinesByHash.resize(0);
        usedWrappedLinesByHash.resize(0);
    }

}
