// Ported from gpui-pre 0.3.10: src/elements/text.rs (TextLayout, TextLayoutInner)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.LineWrapper;
import gpui.util.Utf8;

/**
 * The Layout for a text element. This can be used to map indices to pixels and vice versa.
 *
 * Rust shares it through `Rc<RefCell<Option<TextLayoutInner>>>`: here the
 * instance itself is shared, `measured` tells whether the inner state exists.
 */
class TextLayout extends TaffyLayoutEngine.MeasuredNode {

    /** `true` once measured (Rust `Some(TextLayoutInner)`) */
    public var measured(default, null):Bool = false;

    var _len:Int = 0;

    var lines:Array<WrappedLine> = [];

    var _lineHeight:Pixels = 0;

    var wrapWidth:Null<Float> = null;

    var truncateWidth:Null<Float> = null;

    var size:Null<Size> = null;

    var _bounds:Null<Bounds> = null;

    public function new() {
        super();
    }

    /**
     * Requests a measured layout node for `text` with the current text style
     * of the window (the runs default to one run of that style).
     */
    /**
     * `[style.toRun(len)]`, shared with the last texts laid out with the
     * same style values and length (the runs are only read: shaping and
     * truncation copy what they change). 4 ways per length slot.
     */
    static final recentRuns:Array<Array<TextRun>> = [for (_ in 0...RECENT_RUNS) null];

    static inline final RECENT_RUNS = 256;

    static inline final RUN_SLOTS = 64;

    static function defaultRuns(style:TextStyle, len:Int):Array<TextRun> {
        // 4 ways per length slot (texts of one length in several styles)
        final base = (len & (RUN_SLOTS - 1)) * 4;
        for (way in 0...4) {
            final cached = recentRuns[base + way];
            if (cached == null)
                continue;
            final run = cached[0];
            final font = run.font;
            if (run.len == len && font.family == style.fontFamily && font.features.equals(style.fontFeatures)
                && (font.fallbacks == null ? style.fontFallbacks == null : font.fallbacks.equals(style.fontFallbacks))
                && (font.weight:Float) == (style.fontWeight:Float) && font.style == style.fontStyle
                && run.color.equals(style.color) && TextRun.sameColor(run.backgroundColor, style.backgroundColor)
                && TextRun.sameUnderline(run.underline, style.underline)
                && TextRun.sameStrikethrough(run.strikethrough, style.strikethrough)) {
                return cached;
            }
        }
        final runs = [style.toRun(len)];
        final way = recentRunsNext[len & (RUN_SLOTS - 1)];
        recentRunsNext[len & (RUN_SLOTS - 1)] = (way + 1) & 3;
        recentRuns[base + way] = runs;
        return runs;
    }

    /** The way of each slot replaced next */
    static final recentRunsNext:Array<Int> = [for (_ in 0...RUN_SLOTS) 0];

    public function layout(text:String, runs:Null<Array<TextRun>>, window:Window, cx:App):LayoutId {
        final textStyle = window.currentTextStyle();
        final fontSize = textStyle.fontSize.toPixels(window.remSize());
        final lineHeight = window.pixelSnap(textStyle.lineHeight.toPixelsOf(fontSize, window.remSize()));

        final runs:Array<TextRun> = runs != null ? runs : defaultRuns(textStyle, Utf8.byteLength(text));

        // The measure is this object (`measureNode`), with the values it reads
        // kept here: no closure and no node context per text node
        pendingText = text;
        pendingRuns = runs;
        pendingStyle = textStyle;
        pendingFontSize = fontSize;
        pendingLineHeight = lineHeight;
        return @:privateAccess window.requestMeasuredNode(@:privateAccess gpui.Style.sharedDefaultStyle(), this);
    }

    var pendingText:String = '';

    var pendingRuns:Null<Array<TextRun>> = null;

    var pendingStyle:Null<TextStyle> = null;

    var pendingFontSize:Float = 0.0;

    var pendingLineHeight:Float = 0.0;

    @:noCompletion
    override function measureNode(knownDimensions:SizeOf<Null<Float>>, availableSpace:SizeOf<AvailableSpace>, window:Window, cx:App):Size {
        final text = pendingText;
        final runs = pendingRuns;
        final textStyle = pendingStyle;
        final fontSize:Pixels = pendingFontSize;
        final lineHeight:Pixels = pendingLineHeight;
        // The available width as a value (a `Null<Float>` boxes it on hxcpp)
        var hasAvailableWidth = false;
        var availableWidthValue = 0.0;
        switch availableSpace.width {
            case Definite(x):
                hasAvailableWidth = true;
                availableWidthValue = x;
            case _:
        }
        final wrapWidth:Null<Float> = if (textStyle.whiteSpace == Normal) {
            knownDimensions.width != null ? knownDimensions.width
                : (hasAvailableWidth ? sameBox(this.wrapWidth, availableWidthValue) : null);
        }
        else {
            null;
        };

        var truncateWidth:Null<Float> = null;
        var truncationAffix = '';
        var truncateFrom:TruncateFrom = End;
        if (textStyle.textOverflow != null) {
            truncateWidth = if (knownDimensions.width != null) {
                knownDimensions.width;
            }
            else if (hasAvailableWidth) {
                textStyle.lineClamp >= 0 ? availableWidthValue * textStyle.lineClamp : availableWidthValue;
            }
            else {
                null;
            };
            switch textStyle.textOverflow {
                case Truncate(s):
                    truncationAffix = s;
                    truncateFrom = End;
                case TruncateStart(s):
                    truncationAffix = s;
                    truncateFrom = Start;
                case TruncateMiddle(s):
                    truncationAffix = s;
                    truncateFrom = Middle;
            }
        }

        // Only use cached layout if:
        // 1. We have a cached size
        // 2. wrap_width matches (or both are None)
        // 3. truncate_width is None (if truncate_width is Some, we need to re-layout
        //    because the previous layout may have been computed without truncation)
        // 4. the cached layout was not truncated (a truncated layout answers an
        //    unconstrained probe with the truncated size, which poisons intrinsic
        //    sizing with whatever width some earlier measure pass happened to use)
        if (this.measured
            && this.size != null
            && (wrapWidth == null || wrapWidth == this.wrapWidth)
            && truncateWidth == null
            && this.truncateWidth == null) {
            return this.size;
        }

        final lineWrapper = @:privateAccess cx.textSystem().lineWrapperOfStyle(textStyle, fontSize);
        var finalText = text;
        var finalRuns = runs;
        // The unclipped shaping of a text that fits: the same call as
        // the final one when the text does not wrap (reused, not repeated)
        var fittingLines:Null<Array<WrappedLine>> = null;
        if (truncateWidth != null) {
            if (textStyle.lineClamp >= 0 && wrapWidth != null) {
                final truncated = lineWrapper.truncateWrappedLine(text, wrapWidth, textStyle.lineClamp, truncationAffix, runs, truncateFrom);
                finalText = truncated.text;
                finalRuns = truncated.runs;
            }
            else {
                var fits = false;
                final unclipped = try @:privateAccess window.textSystem().shapeTextWith(text, fontSize, runs, null, -1, true) catch (e:Dynamic) null;
                if (unclipped != null) {
                    fits = true;
                    for (line in unclipped) {
                        if (line.width() > truncateWidth) {
                            fits = false;
                            break;
                        }
                    }
                }
                if (fits)
                    fittingLines = unclipped;
                if (!fits) {
                    // The truncation decision sums per-character advances,
                    // which overestimates the shaped width (no kerning), truncating
                    // text that fits exactly in its measured width. Skip truncation
                    // whenever the honestly-shaped text fits.
                    final truncated = lineWrapper.truncateLine(text, truncateWidth, truncationAffix, runs, truncateFrom);
                    finalText = truncated.text;
                    finalRuns = truncated.runs;
                }
            }
        }
        final len = Utf8.byteLength(finalText);

        final lines = if (fittingLines != null && wrapWidth == null && textStyle.lineClamp < 0) {
            fittingLines;
        }
        else {
            try @:privateAccess window.textSystem().shapeTextWith(finalText, fontSize, finalRuns, wrapWidth, textStyle.lineClamp, true) catch (e:Dynamic) {
                ceramic.Shortcuts.log.error('Failed to shape text: $e');
                null;
            };
        }
        if (lines == null) {
            this.setInner([], 0, lineHeight, wrapWidth, truncateWidth, new Size(0, 0));
            return new Size(0, 0);
        }

        var width:Float = 0;
        var height:Float = 0;
        for (line in lines) {
            height += line.sizeHeight(lineHeight);
            width = Math.fceil(Math.max(width, line.width()));
        }
        // Sizes are immutable: the last one is kept when it is the same
        final previous = this.size;
        final size = previous != null && sameFloat(previous.width, width) && sameFloat(previous.height, height)
            ? previous
            : new Size(width, height);
        this.setInner(lines, len, lineHeight, wrapWidth, truncateWidth, size);
        return size;
    }

    /**
     * `previous` when it holds `value` (no new box for the same width),
     * else `value`
     */
    static inline function sameBox(previous:Null<Float>, value:Float):Null<Float> {
        return previous != null && sameFloat(previous, value) ? previous : value;
    }

    /** The same value, zero signs included */
    static inline function sameFloat(a:Float, b:Float):Bool {
        return a == b && (b != 0.0 || 1.0 / a == 1.0 / b);
    }

    function setInner(lines:Array<WrappedLine>, len:Int, lineHeight:Pixels, wrapWidth:Null<Float>, truncateWidth:Null<Float>, size:Size):Void {
        this.lines = lines;
        this._len = len;
        this._lineHeight = lineHeight;
        this.wrapWidth = wrapWidth;
        this.truncateWidth = truncateWidth;
        this.size = size;
        this._bounds = null;
        measured = true;
    }

    /**
     * Stores the bounds of the element (called from prepaint).
     */
    public function prepaint(bounds:Bounds, text:String):Void {
        if (!measured)
            throw 'measurement has not been performed on $text';
        _bounds = bounds;
    }

    /**
     * Paints the backgrounds of the runs and the glyphs.
     */
    public function paint(text:String, window:Window, cx:App):Void {
        paintLines(All, window, cx);
    }

    /**
     * Paints the backgrounds of the text runs without the glyphs, so that callers can paint
     * content, such as highlights, between the backgrounds and the text. Follow it with
     * `paintForeground()` to paint the glyphs.
     */
    public function paintBackground(window:Window, cx:App):Void {
        paintLines(Background, window, cx);
    }

    /**
     * Paints the glyphs and decorations of the text without the run backgrounds.
     */
    public function paintForeground(window:Window, cx:App):Void {
        paintLines(Foreground, window, cx);
    }

    function paintLines(pass:TextPaintPass, window:Window, cx:App):Void {
        if (!measured)
            throw 'measurement has not been performed';
        final bounds = _bounds;
        if (bounds == null)
            throw 'prepaint has not been performed';

        final lineHeight = _lineHeight;
        var originY = bounds.origin.y;
        final textStyle = window.currentTextStyle();
        var first = true;
        for (line in lines) {
            // The first line starts at the bounds' origin (immutable, so shared)
            final lineOrigin = first ? bounds.origin : new Point(bounds.origin.x, originY);
            first = false;
            if (pass == All || pass == Background) {
                line.paintBackground(lineOrigin, lineHeight, textStyle.textAlign, bounds, window.textPainter());
            }
            if (pass == All || pass == Foreground) {
                line.paint(lineOrigin, lineHeight, textStyle.textAlign, bounds, window.textPainter());
            }
            originY += line.sizeHeight(lineHeight);
        }
    }

    /**
     * Get the byte index into the input of the pixel position.
     */
    public function indexForPosition(position:Point):IndexResult {
        if (!measured)
            throw 'measurement has not been performed';
        final bounds = _bounds;
        if (bounds == null)
            throw 'prepaint has not been performed';

        if (position.y < bounds.top())
            return Err(0);

        final lineHeight = _lineHeight;
        var lineOriginY = bounds.origin.y;
        var lineStartIx = 0;
        for (line in lines) {
            final lineBottom = lineOriginY + line.sizeHeight(lineHeight);
            if (position.y > lineBottom) {
                lineOriginY = lineBottom;
                lineStartIx += line.len() + 1;
            }
            else {
                final positionWithinLine = new Point(position.x - bounds.origin.x, position.y - lineOriginY);
                return switch line.indexForPosition(positionWithinLine, lineHeight) {
                    case Ok(indexWithinLine): Ok(lineStartIx + indexWithinLine);
                    case Err(indexWithinLine): Err(lineStartIx + indexWithinLine);
                }
            }
        }

        return Err(lineStartIx > 0 ? lineStartIx - 1 : 0);
    }

    /**
     * Get the pixel position for the given byte index.
     */
    public function positionForIndex(index:Int):Null<Point> {
        if (!measured)
            throw 'measurement has not been performed';
        final bounds = _bounds;
        if (bounds == null)
            throw 'prepaint has not been performed';
        final lineHeight = _lineHeight;

        var lineOriginY = bounds.origin.y;
        var lineStartIx = 0;

        for (line in lines) {
            final lineEndIx = lineStartIx + line.len();
            if (index < lineStartIx) {
                break;
            }
            else if (index > lineEndIx) {
                lineOriginY += line.sizeHeight(lineHeight);
                lineStartIx = lineEndIx + 1;
                continue;
            }
            else {
                final ixWithinLine = index - lineStartIx;
                final position = line.positionForIndex(ixWithinLine, lineHeight);
                if (position == null)
                    return null;
                return new Point(bounds.origin.x + position.x, lineOriginY + position.y);
            }
        }

        return null;
    }

    /**
     * Retrieve the layout for the line containing the given byte index.
     */
    public function lineLayoutForIndex(index:Int):Null<WrappedLineLayout> {
        if (!measured)
            throw 'measurement has not been performed';
        var lineStartIx = 0;

        for (line in lines) {
            final lineEndIx = lineStartIx + line.len();
            if (index < lineStartIx) {
                break;
            }
            else if (index > lineEndIx) {
                lineStartIx = lineEndIx + 1;
                continue;
            }
            else {
                return line.layout;
            }
        }

        return null;
    }

    /**
     * Retrieve all line layouts in source order.
     */
    public function lineLayouts():Array<WrappedLineLayout> {
        if (!measured)
            throw 'measurement has not been performed';
        return [for (line in lines) line.layout];
    }

    /** The bounds of this layout. */
    public function bounds():Bounds {
        return _bounds;
    }

    /** The line height for this layout. */
    public function lineHeight():Pixels {
        return _lineHeight;
    }

    /** The UTF-8 length of the underlying text. */
    public function len():Int {
        return _len;
    }

    /** The text for this layout. */
    public function text():String {
        return [for (line in lines) line.text].join('\n');
    }

    /** The text for this layout (with soft-wraps as newlines) */
    public function wrappedText():String {
        final accumulator = new StringBuf();

        for (wrapped in lines) {
            var seen = 0;
            for (boundary in wrapped.layout.wrapBoundaries) {
                final index = wrapped.layout.unwrappedLayout.runs[boundary.runIx].glyphs[boundary.glyphIx].index;
                accumulator.add(Utf8.substring(wrapped.text, seen, index));
                accumulator.add('\n');
                seen = index;
            }
            accumulator.add(Utf8.substringFrom(wrapped.text, seen));
            accumulator.add('\n');
        }
        // Remove trailing newline
        final result = accumulator.toString();
        return result.length > 0 ? result.substr(0, result.length - 1) : result;
    }

}

private enum abstract TextPaintPass(Int) {
    var All;
    var Background;
    var Foreground;
}
