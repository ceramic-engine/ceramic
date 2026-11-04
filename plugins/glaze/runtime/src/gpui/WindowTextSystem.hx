// Ported from gpui-pre 0.3.10: src/text_system.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.util.Utf8;

/**
 * The GPUI text layout subsystem of a window: the shared `TextSystem`
 * plus a line layout cache (Rust derefs to `TextSystem`: use the
 * `textSystem` field, or the forwarding methods below).
 */
class WindowTextSystem {

    final lineLayoutCache:LineLayoutCache;

    /** Font runs of `shapeText()`, reused from call to call (null while in use) */
    var scratchFontRuns:Null<Array<FontRun>> = [];

    var scratchFontRunPool:Null<Array<FontRun>> = [];

    public final textSystem:TextSystem;

    /**
     * Create a new WindowTextSystem with the given TextSystem.
     */
    public function new(textSystem:TextSystem) {
        this.textSystem = textSystem;
        lineLayoutCache = new LineLayoutCache(textSystem.platformTextSystem, textSystem);
    }

    public inline function layoutIndex():LineLayoutIndex {
        return lineLayoutCache.layoutIndex();
    }

    public inline function layoutIndexInto(index:LineLayoutIndex):Void {
        lineLayoutCache.layoutIndexInto(index);
    }

    public inline function reuseLayouts(start:LineLayoutIndex, end:LineLayoutIndex):Void {
        lineLayoutCache.reuseLayouts(start, end);
    }

    public inline function truncateLayouts(index:LineLayoutIndex):Void {
        lineLayoutCache.truncateLayouts(index);
    }

    public inline function finishFrame():Void {
        lineLayoutCache.finishFrame();
    }

    static function decorationRunsOf(runs:Array<TextRun>):Array<DecorationRun> {
        final decorationRuns:Array<DecorationRun> = [];
        for (run in runs) {
            if (decorationRuns.length > 0) {
                final lastRun = decorationRuns[decorationRuns.length - 1];
                if (lastRun.color.equals(run.color)
                    && TextRun.sameUnderline(lastRun.underline, run.underline)
                    && TextRun.sameStrikethrough(lastRun.strikethrough, run.strikethrough)
                    && TextRun.sameColor(lastRun.backgroundColor, run.backgroundColor)) {
                    lastRun.len += run.len;
                    continue;
                }
            }
            decorationRuns.push(new DecorationRun(run.len, run.color, run.backgroundColor, run.underline, run.strikethrough));
        }
        return decorationRuns;
    }

    /**
     * Shape the given line, at the given font_size, for painting to the screen.
     * Subsets of the line can be styled independently with the `runs` parameter.
     *
     * Note that this method can only shape a single line of text. If you need to
     * shape multiple lines of text, use `shapeText()` instead.
     */
    public function shapeLine(text:String, fontSize:Pixels, runs:Array<TextRun>, ?forceWidth:Float):ShapedLine {
        final decorationRuns = decorationRunsOf(runs);
        final layout = layoutLine(text, fontSize, runs, forceWidth);
        return new ShapedLine(layout, text, decorationRuns);
    }

    /**
     * Shape the given line using a caller-provided content hash as the cache key.
     *
     * This enables cache hits without materializing the text. If the cache misses,
     * `materializeText` is invoked to produce the text for shaping. The returned
     * line has an empty `text` (callers must not rely on it).
     */
    public function shapeLineByHash(textHash:Int, textLen:Int, fontSize:Pixels, runs:Array<TextRun>, forceWidth:Null<Float>, materializeText:() -> String):ShapedLine {
        final decorationRuns = decorationRunsOf(runs);
        final layout = layoutLineByHash(textHash, textLen, fontSize, runs, forceWidth, materializeText);
        return new ShapedLine(layout, '', decorationRuns);
    }

    /**
     * Shape a multi line string of text, at the given font_size, for painting to the screen.
     * Subsets of the text can be styled independently with the `runs` parameter.
     * If `wrapWidth` is provided, the line breaks will be adjusted to fit within the given width.
     * `lineClamp` is -1 when there is no limit.
     */
    public function shapeText(text:String, fontSize:Pixels, runs:Array<TextRun>, ?wrapWidth:Float, lineClamp:Int = -1):Array<WrappedLine> {
        // Rust copies the runs with a length because their length is consumed
        // line by line: here the current run and what is left of it are kept
        // in locals instead (`runs` is not changed)
        var runIndex = nextRunWithLength(runs, 0);
        var runLeft = runIndex < runs.length ? runs[runIndex].len : 0;

        final lines:Array<WrappedLine> = [];
        final maxWrapLines = lineClamp;
        var wrappedLines = 0;

        // Scratch font runs (the line cache copies what it keeps); a nested
        // call gets its own
        var fontRuns = scratchFontRuns;
        scratchFontRuns = null;
        if (fontRuns == null) fontRuns = [];
        var fontRunPool = scratchFontRunPool;
        scratchFontRunPool = null;
        if (fontRunPool == null) fontRunPool = [];

        // Lines split at `\n` (the text itself when it has none)
        final splitLines:Null<Array<String>> = text.indexOf('\n') >= 0 ? text.split('\n') : null;
        final lineCount = splitLines != null ? splitLines.length : 1;
        var lineStart = 0;
        for (i in 0...lineCount) {
            final lineText = splitLines != null ? splitLines[i] : text;
            final lineLen = Utf8.byteLength(lineText);
            final lineEnd = lineStart + lineLen;

            fontRuns.resize(0);
            final decorationRuns:Array<DecorationRun> = [];
            var runStart = lineStart;
            while (runStart < lineEnd) {
                if (runIndex >= runs.length) {
                    ceramic.Shortcuts.log.warning('`TextRun`s do not cover the entire to be shaped text');
                    break;
                }
                final run = runs[runIndex];

                final runLenWithinLine = Std.int(Math.min(lineEnd - runStart, runLeft));

                var decorationChanged = true;
                if (decorationRuns.length > 0) {
                    final lastRun = decorationRuns[decorationRuns.length - 1];
                    if (lastRun.color.equals(run.color)
                        && TextRun.sameUnderline(lastRun.underline, run.underline)
                        && TextRun.sameStrikethrough(lastRun.strikethrough, run.strikethrough)
                        && TextRun.sameColor(lastRun.backgroundColor, run.backgroundColor)) {
                        lastRun.len += runLenWithinLine;
                        decorationChanged = false;
                    }
                }
                if (decorationChanged) {
                    decorationRuns.push(new DecorationRun(runLenWithinLine, run.color, run.backgroundColor, run.underline, run.strikethrough));
                }

                final fontId = textSystem.resolveFont(run.font);
                final lastFontRun = fontRuns.length > 0 ? fontRuns[fontRuns.length - 1] : null;
                if (lastFontRun != null && (fontId:Int) == (lastFontRun.fontId:Int) && !decorationChanged) {
                    lastFontRun.len += runLenWithinLine;
                }
                else {
                    final index = fontRuns.length;
                    if (index < fontRunPool.length) {
                        final fontRun = fontRunPool[index];
                        fontRun.len = runLenWithinLine;
                        fontRun.fontId = fontId;
                        fontRuns.push(fontRun);
                    }
                    else {
                        final fontRun = new FontRun(runLenWithinLine, fontId);
                        fontRunPool.push(fontRun);
                        fontRuns.push(fontRun);
                    }
                }

                // Preserve the remainder of the run for the next line
                runLeft -= runLenWithinLine;
                if (runLeft == 0) {
                    runIndex = nextRunWithLength(runs, runIndex + 1);
                    runLeft = runIndex < runs.length ? runs[runIndex].len : 0;
                }
                runStart += runLenWithinLine;
            }

            final layout = lineLayoutCache.layoutWrappedLine(lineText, fontSize, fontRuns, wrapWidth, maxWrapLines >= 0 ? Std.int(Math.max(0, maxWrapLines - wrappedLines)) : -1);
            wrappedLines += layout.wrapBoundaries.length;

            lines.push(new WrappedLine(layout, lineText, decorationRuns));

            // Skip `\n` character.
            if (runIndex < runs.length) {
                runLeft -= 1;
                if (runLeft == 0) {
                    runIndex = nextRunWithLength(runs, runIndex + 1);
                    runLeft = runIndex < runs.length ? runs[runIndex].len : 0;
                }
            }
            lineStart += lineLen + 1;
        }

        fontRuns.resize(0);
        scratchFontRuns = fontRuns;
        scratchFontRunPool = fontRunPool;
        return lines;
    }

    /** The first run from `start` with a length (`runs.length` when none) */
    static function nextRunWithLength(runs:Array<TextRun>, start:Int):Int {
        var i = start;
        while (i < runs.length && runs[i].len <= 0) {
            i++;
        }
        return i;
    }

    function fontRunsOf(runs:Array<TextRun>):Array<FontRun> {
        var lastRun:TextRun = null;
        final fontRuns:Array<FontRun> = [];

        for (run in runs) {
            var decorationChanged = true;
            if (lastRun != null
                && lastRun.color.equals(run.color)
                && TextRun.sameUnderline(lastRun.underline, run.underline)
                && TextRun.sameStrikethrough(lastRun.strikethrough, run.strikethrough)) {
                // we do not consider differing background color relevant, as it does not affect glyphs
                decorationChanged = false;
            }
            else {
                lastRun = run;
            }

            final fontId = textSystem.resolveFont(run.font);
            final lastFontRun = fontRuns.length > 0 ? fontRuns[fontRuns.length - 1] : null;
            if (lastFontRun != null && (fontId:Int) == (lastFontRun.fontId:Int) && !decorationChanged) {
                lastFontRun.len += run.len;
            }
            else {
                fontRuns.push(new FontRun(run.len, fontId));
            }
        }

        return fontRuns;
    }

    /**
     * Layout the given line of text, at the given font_size.
     * Subsets of the line can be styled independently with the `runs` parameter.
     * Generally, you should prefer to use `shapeLine()` instead, which
     * can be painted directly.
     */
    public function layoutLine(text:String, fontSize:Pixels, runs:Array<TextRun>, ?forceWidth:Float):LineLayout {
        return lineLayoutCache.layoutLine(text, fontSize, fontRunsOf(runs), forceWidth);
    }

    /**
     * Returns the shaped layout width of for the given character, in the given font and size.
     */
    public function layoutWidth(fontId:FontId, fontSize:Pixels, ch:Int):Pixels {
        final run = new FontRun(Utf8.codePointLength(ch), fontId);
        return lineLayoutCache.layoutLine(Utf8.fromCodePoint(ch), fontSize, [run], null).width;
    }

    /**
     * Returns the shaped layout width of an `em`.
     */
    public inline function emLayoutWidth(fontId:FontId, fontSize:Pixels):Pixels {
        return layoutWidth(fontId, fontSize, 'm'.code);
    }

    /**
     * Probe the line layout cache using a caller-provided content hash, without shaping.
     * Returns null if the layout is not cached in the current or previous frame.
     */
    public function tryLayoutLineByHash(textHash:Int, textLen:Int, fontSize:Pixels, runs:Array<TextRun>, ?forceWidth:Float):Null<LineLayout> {
        return lineLayoutCache.tryLayoutLineByHash(textHash, textLen, fontSize, fontRunsOf(runs), forceWidth);
    }

    /**
     * Layout the given line of text using a caller-provided content hash as the cache key.
     */
    public function layoutLineByHash(textHash:Int, textLen:Int, fontSize:Pixels, runs:Array<TextRun>, forceWidth:Null<Float>, materializeText:() -> String):LineLayout {
        return lineLayoutCache.layoutLineByHash(textHash, textLen, fontSize, fontRunsOf(runs), forceWidth, materializeText);
    }

/// Forwarded `TextSystem` methods (Rust `Deref`)

    public inline function resolveFont(font:Font):FontId {
        return textSystem.resolveFont(font);
    }

    public inline function boundingBox(fontId:FontId, fontSize:Pixels):Bounds {
        return textSystem.boundingBox(fontId, fontSize);
    }

    public inline function ascent(fontId:FontId, fontSize:Pixels):Pixels {
        return textSystem.ascent(fontId, fontSize);
    }

    public inline function descent(fontId:FontId, fontSize:Pixels):Pixels {
        return textSystem.descent(fontId, fontSize);
    }

    public inline function baselineOffset(fontId:FontId, fontSize:Pixels, lineHeight:Pixels):Pixels {
        return textSystem.baselineOffset(fontId, fontSize, lineHeight);
    }

    public inline function advance(fontId:FontId, fontSize:Pixels, ch:Int):Size {
        return textSystem.advance(fontId, fontSize, ch);
    }

    public inline function emWidth(fontId:FontId, fontSize:Pixels):Pixels {
        return textSystem.emWidth(fontId, fontSize);
    }

    public inline function emAdvance(fontId:FontId, fontSize:Pixels):Pixels {
        return textSystem.emAdvance(fontId, fontSize);
    }

    public inline function lineWrapper(font:Font, fontSize:Pixels):LineWrapper {
        return textSystem.lineWrapper(font, fontSize);
    }

}
