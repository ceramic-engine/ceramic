// Ported from gpui-pre 0.3.10: src/text_system/line_layout.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;


/**
 * Caches line layouts for the current and the previous frame: a layout
 * used during a frame is kept for the next one, and dropped if the next
 * frame doesn't use it (`finishFrame()`).
 *
 * Keys are strings made of the text and the layout parameters (Rust hashes
 * the same fields). Layouts by hash (`layoutLineByHash()`) use the caller's
 * hash instead of the text.
 */
class LineLayoutCache {

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

        for (i in start.linesIndex...end.linesIndex) {
            final key = previousFrame.usedLines[i];
            final line = previousFrame.lines.get(key);
            if (line != null) {
                previousFrame.lines.remove(key);
                currentFrame.lines.set(key, line);
            }
            currentFrame.usedLines.push(key);
        }

        for (i in start.wrappedLinesIndex...end.wrappedLinesIndex) {
            final key = previousFrame.usedWrappedLines[i];
            final line = previousFrame.wrappedLines.get(key);
            if (line != null) {
                previousFrame.wrappedLines.remove(key);
                currentFrame.wrappedLines.set(key, line);
            }
            currentFrame.usedWrappedLines.push(key);
        }

        for (i in start.linesByHashIndex...end.linesByHashIndex) {
            final key = previousFrame.usedLinesByHash[i];
            final line = previousFrame.linesByHash.get(key);
            if (line != null) {
                previousFrame.linesByHash.remove(key);
                currentFrame.linesByHash.set(key, line);
            }
            currentFrame.usedLinesByHash.push(key);
        }

        for (i in start.wrappedLinesByHashIndex...end.wrappedLinesByHashIndex) {
            final key = previousFrame.usedWrappedLinesByHash[i];
            final line = previousFrame.wrappedLinesByHash.get(key);
            if (line != null) {
                previousFrame.wrappedLinesByHash.remove(key);
                currentFrame.wrappedLinesByHash.set(key, line);
            }
            currentFrame.usedWrappedLinesByHash.push(key);
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

    public function finishFrame():Void {
        clearIfFontGenerationChanged();
        final prev = previousFrame;
        previousFrame = currentFrame;
        currentFrame = prev;
        currentFrame.clear();
    }

    static function runsKey(buf:StringBuf, runs:Array<FontRun>):Void {
        for (run in runs) {
            buf.add(run.len);
            buf.add(':');
            buf.add((run.fontId:Int));
            buf.add(',');
        }
    }

    static function cacheKey(text:String, fontSize:Float, runs:Array<FontRun>, wrapWidth:Null<Float>, forceWidth:Null<Float>):String {
        final buf = new StringBuf();
        buf.add(fontSize);
        buf.add('|');
        buf.add(wrapWidth == null ? 'n' : Std.string(wrapWidth));
        buf.add('|');
        buf.add(forceWidth == null ? 'n' : Std.string(forceWidth));
        buf.add('|');
        runsKey(buf, runs);
        buf.add('|');
        buf.add(text);
        return buf.toString();
    }

    static function hashedCacheKey(textHash:Int, textLen:Int, fontSize:Float, runs:Array<FontRun>, wrapWidth:Null<Float>, forceWidth:Null<Float>):String {
        final buf = new StringBuf();
        buf.add(textHash);
        buf.add('|');
        buf.add(textLen);
        buf.add('|');
        buf.add(fontSize);
        buf.add('|');
        buf.add(wrapWidth == null ? 'n' : Std.string(wrapWidth));
        buf.add('|');
        buf.add(forceWidth == null ? 'n' : Std.string(forceWidth));
        buf.add('|');
        runsKey(buf, runs);
        return buf.toString();
    }

    /**
     * Layout of a line wrapped at `wrapWidth` (cached). `maxLines` is -1
     * when there is no line clamp.
     */
    public function layoutWrappedLine(text:String, fontSize:Pixels, runs:Array<FontRun>, wrapWidth:Null<Float>, maxLines:Int = -1):WrappedLineLayout {
        clearIfFontGenerationChanged();
        // Rust leaves max_lines out of the key: same behavior here
        final key = cacheKey(text, fontSize, runs, wrapWidth, null);

        final cached = currentFrame.wrappedLines.get(key);
        if (cached != null) {
            return cached;
        }

        final previous = previousFrame.wrappedLines.get(key);
        if (previous != null) {
            previousFrame.wrappedLines.remove(key);
            currentFrame.wrappedLines.set(key, previous);
            currentFrame.usedWrappedLines.push(key);
            return previous;
        }
        else {
            final unwrappedLayout = layoutLine(text, fontSize, runs, null);
            final wrapBoundaries = wrapWidth != null ? unwrappedLayout.computeWrapBoundaries(text, wrapWidth, maxLines) : [];
            final layout = new WrappedLineLayout(unwrappedLayout, wrapBoundaries, wrapWidth);
            currentFrame.wrappedLines.set(key, layout);
            currentFrame.usedWrappedLines.push(key);
            return layout;
        }
    }

    /**
     * Layout of a single line (cached). `forceWidth` places glyphs on a
     * grid of cells of that width (monospace terminals).
     */
    public function layoutLine(text:String, fontSize:Pixels, runs:Array<FontRun>, forceWidth:Null<Float>):LineLayout {
        clearIfFontGenerationChanged();
        final key = cacheKey(text, fontSize, runs, null, forceWidth);

        final cached = currentFrame.lines.get(key);
        if (cached != null) {
            return cached;
        }

        final previous = previousFrame.lines.get(key);
        if (previous != null) {
            previousFrame.lines.remove(key);
            currentFrame.lines.set(key, previous);
            currentFrame.usedLines.push(key);
            return previous;
        }
        else {
            final layout = platformTextSystem.layoutLine(text, fontSize, runs);

            if (forceWidth != null) {
                applyForceWidthToLayout(layout, forceWidth);
            }

            currentFrame.lines.set(key, layout);
            currentFrame.usedLines.push(key);
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
        final key = hashedCacheKey(textHash, textLen, fontSize, runs, null, forceWidth);
        final current = currentFrame.linesByHash.get(key);
        if (current != null)
            return current;
        return previousFrame.linesByHash.get(key);
    }

    /**
     * Layout a line of text using a caller-provided content hash as the cache key.
     * If the cache misses, `materializeText` is invoked to produce the text.
     */
    public function layoutLineByHash(textHash:Int, textLen:Int, fontSize:Pixels, runs:Array<FontRun>, forceWidth:Null<Float>, materializeText:() -> String):LineLayout {
        clearIfFontGenerationChanged();
        final key = hashedCacheKey(textHash, textLen, fontSize, runs, null, forceWidth);

        final cached = currentFrame.linesByHash.get(key);
        if (cached != null) {
            return cached;
        }

        final previous = previousFrame.linesByHash.get(key);
        if (previous != null) {
            previousFrame.linesByHash.remove(key);
            currentFrame.linesByHash.set(key, previous);
            currentFrame.usedLinesByHash.push(key);
            return previous;
        }

        final text = materializeText();
        final layout = platformTextSystem.layoutLine(text, fontSize, runs);

        if (forceWidth != null) {
            applyForceWidthToLayout(layout, forceWidth);
        }

        currentFrame.linesByHash.set(key, layout);
        currentFrame.usedLinesByHash.push(key);
        return layout;
    }

    function clearIfFontGenerationChanged():Int {
        final generation = fontGeneration();
        if (cachedFontGeneration == generation) {
            return generation;
        }

        currentFrame = new FrameCache();
        previousFrame = new FrameCache();
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

private class FrameCache {

    public final lines:Map<String, LineLayout> = new Map();
    public final wrappedLines:Map<String, WrappedLineLayout> = new Map();
    public final usedLines:Array<String> = [];
    public final usedWrappedLines:Array<String> = [];

    public final linesByHash:Map<String, LineLayout> = new Map();
    public final wrappedLinesByHash:Map<String, WrappedLineLayout> = new Map();
    public final usedLinesByHash:Array<String> = [];
    public final usedWrappedLinesByHash:Array<String> = [];

    public function new() {}

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
