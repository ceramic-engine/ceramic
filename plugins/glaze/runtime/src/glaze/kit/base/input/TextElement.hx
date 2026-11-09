// Ported from gpui-kit 0.8.1: crates/base/src/input/base/element.rs, crates/base/src/input/mod.rs (`MASK_CHAR`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified during the initial port: deviation DEV-016 (no notify when the input only moved). See docs/DEVIATIONS.md.
package glaze.kit.base.input;

import glaze.AnyElement;
import glaze.App;
import glaze.AvailableSpace;
import glaze.Bounds;
import glaze.Context;
import glaze.CornersOf;
import glaze.Edges;
import glaze.Element;
import glaze.ElementId;
import glaze.ElementInputHandler;
import glaze.Entity;
import glaze.GlobalElementId;
import glaze.HighlightStyle;
import glaze.Hitbox;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.Length;
import glaze.LineLayout;
import glaze.MouseButton;
import glaze.MouseMoveEvent;
import glaze.Path;
import glaze.PathBuilder;
import glaze.Pixels;
import glaze.Point;
import glaze.ScrollEvent;
import glaze.ShapedLine;
import glaze.Size;
import glaze.SizeOf;
import glaze.Style;
import glaze.TextAlign;
import glaze.TextRun;
import glaze.TextStyle;
import glaze.TransformationMatrix;
import glaze.UnderlineStyle;
import glaze.Window;
import glaze.kit.base.ScrollBounce;
import glaze.kit.base.input.InlineTokenPresentation.TokenLayoutCache;
import glaze.kit.base.input.InlineTokenPresentation.TokenLayoutKey;
import glaze.kit.base.input.InlineTokenPresentation.TokenMetric;
import glaze.kit.base.input.InputLine.InlineFragment;
import glaze.kit.base.input.LongestLineKey.LongestLineWidth;
import glaze.util.MathUtil;
import glaze.util.Utf8;
import ropey.Rope;

import glaze.Prelude.*;

import glaze.LongPressEvent;
import glaze.TouchDragEvent;
import glaze.kit.base.GlobalState;

using glaze.ScrollDelta.ScrollDeltaTools;
using glaze.kit.base.input.InputTouch;
using glaze.kit.base.input.InputTokenPresentation;
using glaze.kit.base.input.InputTokens;
using glaze.kit.base.input.RopeExt;

/**
 * The element drawing the text of an input: the visible lines laid out
 * through the display map, the selections, the carets, the IME marked text
 * underline, the placeholder, masked text, inline tokens and whitespace
 * indicators (gpui-kit's code editor parts, line numbers, indent guides,
 * fold icons, highlighting, diagnostics, decorations and inline completion,
 * are not part of Glaze: its code editor is Cityscape). Its paint registers the input
 * handler of the state (`window.handleInput`) and the mouse listeners of
 * the text.
 *
 * Rust keeps the state of `prepaint` in a `PrepaintState` value handed to
 * `paint`; the port keeps it in `prepaintState` (an element is drawn once).
 *
 * Not ported: the accessibility role, label and click action of inline
 * tokens (Glaze has no accessibility tree).
 */
@:access(glaze.kit.base.input.InputBaseState)
@:access(glaze.kit.base.input.LayoutMode)
@:access(glaze.kit.base.ScrollBounce)
class TextElement extends Element {

    /** Character used by masked editor modes (Rust `input::MASK_CHAR`, U+2022 BULLET, a code point). */
    public static inline final MASK_CHAR:Int = 0x2022;

    /** `MASK_CHAR.len_utf8()` */
    public static inline final MASK_CHAR_LEN_UTF8:Int = 3;

    static inline final CURSOR_WIDTH:Float = 1.; // BlinkCursor.CURSOR_WIDTH

    static inline final BOTTOM_MARGIN_ROWS:Int = 3;

    public static inline final RIGHT_MARGIN:Float = 10.;

    /** Room left around a reveal request for the field's padding and border. */
    static inline final REVEAL_MARGIN:Float = 8.;

    /** How much of a caretless multi-line input is revealed. */
    static inline final REVEAL_MAX_HEIGHT:Float = 120.;

    public final state:Entity<InputBaseState>;

    /** Rust field `placeholder` (renamed: the builder has that name). */
    var _placeholder:String = '';

    /** Rust `PrepaintState`, set by `prepaint` for `paint`. */
    var prepaintState:Null<TextElementPrepaintState> = null;

    public function new(state:Entity<InputBaseState>) {
        this.state = state;
    }

    /** Set the placeholder text of the input field. */
    public function placeholder(placeholder:String):TextElement {
        _placeholder = placeholder;
        return this;
    }

/// Free functions of element.rs

    /** Prepaint and retained state must use the same range, including after content shrinks. */
    public static function clampHorizontalScrollOffset(offset:Float, scrollWidth:Float, inputWidth:Float, textAlign:TextAlign):Float {
        final caretClearance:Float = textAlign == Left ? 0. : -CURSOR_WIDTH;
        final minOffset = pixelsMin(inputWidth - scrollWidth + caretClearance, caretClearance);
        return pixelsClamp(offset, minOffset, 0.);
    }

    static function clampVerticalScrollOffset(scrollTop:Float, scrollHeight:Float, inputHeight:Float):Float {
        return pixelsClamp(scrollTop, pixelsMin(inputHeight - scrollHeight, 0.), 0.);
    }

    /**
     * GPUI orders `Pixels` with `f32::total_cmp` (`impl Ord for Pixels`), so
     * `-0.0 < 0.0`: clamping `-0.0` to `min..0` gives `0.0` when `min` is
     * `0.0`, where a plain float clamp keeps `-0.0`.
     */
    static inline function pixelsLess(a:Float, b:Float):Bool {
        return a < b || (a == 0. && b == 0. && 1. / a < 0. && 1. / b > 0.);
    }

    /** Rust `Ord::min` on `Pixels`. */
    static inline function pixelsMin(a:Float, b:Float):Float {
        return pixelsLess(b, a) ? b : a;
    }

    /** Rust `Ord::clamp` on `Pixels`. */
    static inline function pixelsClamp(value:Float, min:Float, max:Float):Float {
        return pixelsLess(value, min) ? min : (pixelsLess(max, value) ? max : value);
    }

    /**
     * Convert a byte offset in the original text to a byte offset in the masked display string.
     *
     * The masked string consists of `MASK_CHAR` repeated once per character in the original text.
     * Since `MASK_CHAR` may be multi-byte in UTF-8, the byte offset in the masked string is
     * `char_index * MASK_CHAR.len_utf8()`.
     */
    static inline function maskedDisplayOffset(text:Rope, originalOffset:Int):Int {
        return text.offsetToCharIndex(originalOffset) * MASK_CHAR_LEN_UTF8;
    }

    /**
     * Move the IME marked range (tracked against the original text) into the display text
     * coordinate space, so that a run boundary can't land inside a multi-byte `MASK_CHAR`
     * and panic text shaping on a non-char-boundary slice.
     */
    static function imeMarkedDisplayRange(text:Rope, markedRange:Null<Range>, masked:Bool):Null<Range> {
        if (markedRange == null)
            return null;
        if (masked) {
            return new Range(maskedDisplayOffset(text, markedRange.start), maskedDisplayOffset(text, markedRange.end));
        }
        else {
            return markedRange;
        }
    }

    /**
     * Viewport capacity in display rows, independent of logical buffer lines.
     *
     * Shared by both scroll-into-view paths (`layoutCursors` and
     * `scrollToWithPadding`) so they agree on the visible-line count even
     * when soft-wrapped lines make logical and display rows diverge.
     */
    public static function viewportVisibleLines(viewportHeight:Float, lineHeight:Float):Int {
        return usize(viewportHeight / lineHeight);
    }

    /**
     * Minimum pixel padding the cursor is kept clear of the viewport's
     * top/bottom edges before auto-scroll engages. Backs
     * `InputBaseState.cursorSurroundingLines`.
     *
     * Auto-grow uses one line. Otherwise `null` falls back to the historical
     * heuristic (`BOTTOM_MARGIN_ROWS` lines, or one line on small
     * viewports); `n` uses `n` lines. The result is saturated against
     * half the viewport so an oversized override can't invert the
     * top/bottom thresholds into a scroll feedback loop. `visibleLines` is the
     * viewport capacity in display rows, independent of logical buffer lines.
     */
    public static function cursorSurroundingPadding(isAutoGrow:Bool, overrideLines:Null<Int>, visibleLines:Int, lineHeight:Float):Float {
        if (isAutoGrow) {
            return lineHeight;
        }
        final raw:Float = if (overrideLines != null) {
            overrideLines * lineHeight;
        }
        else {
            if (visibleLines < BOTTOM_MARGIN_ROWS * 8) {
                lineHeight;
            }
            else {
                BOTTOM_MARGIN_ROWS * lineHeight;
            }
        };
        // Saturate against half the viewport so top + bottom margins can coexist.
        final viewportHalf = (visibleLines * lineHeight) / 2.;
        return MathUtil.min(raw, viewportHalf);
    }

    /**
     * Reveal the whole visual row without changing the usual edge clearance.
     * Reserve the row's height below its insertion position before allocating
     * top padding. A viewport shorter than a row can only align its start.
     */
    public static function revealRow(offset:Float, rowTop:Float, lineHeight:Float, viewportHeight:Float, edgePadding:Float):Float {
        final rowHeight = MathUtil.min(lineHeight, viewportHeight);
        final bottom = MathUtil.min(MathUtil.max(edgePadding, rowHeight), viewportHeight);
        final top = MathUtil.min(edgePadding, viewportHeight - bottom);
        return MathUtil.min(MathUtil.clamp(offset, top - rowTop, viewportHeight - bottom - rowTop), 0.);
    }

    /**
     * Align a caret to whole device pixels.
     *
     * Text positions are fractional, and a one-pixel caret at a fractional x is
     * spread over two device pixels by antialiasing, which draws it faint and
     * thin. Rounding its edges to the device grid keeps every caret crisp.
     */
    static function snapCaretToDevicePixels(bounds:Bounds, scaleFactor:Float):Bounds {
        final x = MathUtil.round(bounds.origin.x * scaleFactor) / scaleFactor;
        final width = MathUtil.max(MathUtil.round(bounds.size.width * scaleFactor), 1.) / scaleFactor;
        return new Bounds(new Point(x, bounds.origin.y), new Size(width, bounds.size.height));
    }

    /** Split placeholder text into display lines and trim runs to each line. */
    static function frameOutlinePoints(corners:Array<CornersOf<Point>>):Array<Point> {
        final rects = [for (c in corners) new FrameRect(c.topLeft, c.bottomRight)];
        final points:Array<Point> = [];
        final first = rects[0];
        final last = rects[rects.length - 1];
        points.push(first.a);
        points.push(new Point(first.b.x, first.a.y));
        for (i in 0...rects.length - 1) {
            final current = rects[i];
            final next = rects[i + 1];
            points.push(current.b);
            points.push(new Point(next.b.x, current.b.y));
            points.push(new Point(next.b.x, next.b.y));
        }
        if (!points[points.length - 1].equals(last.b)) {
            points.push(last.b);
        }
        points.push(new Point(last.a.x, last.b.y));
        var i = rects.length - 2;
        while (i >= 0) {
            final current = rects[i + 1];
            final next = rects[i];
            points.push(new Point(current.a.x, current.a.y));
            points.push(new Point(next.a.x, current.a.y));
            points.push(new Point(next.a.x, next.a.y));
            i--;
        }
        if (!points[points.length - 1].equals(points[0])) {
            points.push(points[0]);
        }
        return points;
    }

    static function placeholderLineRuns(displayText:String, runs:Array<TextRun>):Array<PlaceholderLine> {
        final result:Array<PlaceholderLine> = [];
        var lineOffset = 0;

        for (line in displayText.split('\n')) {
            final len = Utf8.byteLength(line);
            final lineRuns = runsForRange(runs, lineOffset, new Range(0, len));
            result.push(new PlaceholderLine(line, lineRuns));
            // Advance in the whole-placeholder coordinate space, including the separator.
            lineOffset += len + 1;
        }

        return result;
    }

    /**
     * Get the runs for the given range.
     *
     * The range is the byte range of the wrapped line.
     */
    public static function runsForRange(runs:Array<TextRun>, lineOffset:Int, range:Range):Array<TextRun> {
        final result:Array<TextRun> = [];
        final rangeStart = lineOffset + range.start;
        final rangeEnd = lineOffset + range.end;
        var cursor = 0;

        for (run in runs) {
            final runStart = cursor;
            final runEnd = cursor + run.len;

            if (runEnd <= rangeStart) {
                cursor = runEnd;
                continue;
            }

            if (runStart >= rangeEnd) {
                break;
            }

            final start = (rangeStart > runStart ? rangeStart : runStart) - runStart;
            final end = (rangeEnd < runEnd ? rangeEnd : runEnd) - runStart;
            final len = end - start;

            if (len > 0) {
                result.push(run.withLen(len));
            }

            cursor = runEnd;
        }

        return result;
    }

    /**
     * Snap run boundaries to char boundaries of `text` and cap them at its
     * length. Style ranges are byte offsets that can drift off char boundaries
     * (a stale syntax tree, a range in the wrong coordinate space) and the
     * platform text system panics when a run splits a multi-byte character.
     *
     * Returns `null` when the runs are already aligned (the common case).
     */
    public static function alignRunsToCharBoundaries(text:String, runs:Array<TextRun>):Null<Array<TextRun>> {
        final textLen = Utf8.byteLength(text);
        final ascii = textLen == text.length;
        inline function isCharBoundary(offset:Int):Bool {
            return ascii ? offset <= textLen : Utf8.isCharBoundary(text, offset);
        }
        var end = 0;
        var aligned = true;
        for (run in runs) {
            end += run.len;
            if (!(end <= textLen && isCharBoundary(end))) {
                aligned = false;
                break;
            }
        }
        if (aligned) {
            return null;
        }

        final result:Array<TextRun> = [];
        var cursor = 0;
        var rawEnd = 0;
        for (run in runs) {
            rawEnd = rawEnd + run.len < textLen ? rawEnd + run.len : textLen;
            var end = rawEnd;
            while (!isCharBoundary(end)) {
                end++;
            }
            if (end > cursor) {
                result.push(run.withLen(end - cursor));
                cursor = end;
            }
        }

        return result;
    }

    static function splitRunForImeUnderline(run:TextRun, runRange:Range, markedRange:Null<Range>, markedUnderline:Null<UnderlineStyle>):Array<TextRun> {
        if (run.len == 0) {
            return [];
        }

        if (markedRange == null) {
            return [run];
        }

        final intersectionStart = runRange.start > markedRange.start ? runRange.start : markedRange.start;
        final intersectionEnd = runRange.end < markedRange.end ? runRange.end : markedRange.end;
        if (intersectionStart >= intersectionEnd) {
            return [run];
        }

        final marked = run.withLen(intersectionEnd - intersectionStart);
        marked.underline = markedUnderline;
        final result:Array<TextRun> = [];
        for (part in [run.withLen(intersectionStart - runRange.start), marked, run.withLen(runRange.end - intersectionEnd)]) {
            if (part.len > 0) {
                result.push(part);
            }
        }
        return result;
    }

    /**
     * Whether any of these runs paints a glyph background, used to skip the background
     * paint pass for lines without highlights.
     */
    static function hasBackground(runs:Array<TextRun>):Bool {
        for (run in runs) {
            if (run.backgroundColor != null)
                return true;
        }
        return false;
    }

    /** Rust `as usize` on a float: truncates, saturating at 0 (and NaN to 0). */
    static inline function usize(value:Float):Int {
        return value > 0. ? (value >= 2147483647. ? 2147483647 : Std.int(value)) : 0;
    }

    static inline function rangeIsEmpty(range:Range):Bool {
        return range.start >= range.end;
    }

/// impl TextElement

    function paintMouseListeners(hitbox:Hitbox, window:Window, cx:App):Void {
        // The listeners in entries, without closures (`TextScrollEntry`...),
        // registered in the same order
        final state = this.state;
        // Text with room to scroll keeps the wheel from the scroll areas
        // around it; its own listener scrolls it in the bubble phase.
        @:privateAccess window.addMouseListenerEntry(new TextScrollEntry(state, hitbox.id));
        // Every touch is offered as a drag first; that is how a tap's mouse
        // events are later told apart from a mouse's.
        @:privateAccess window.addMouseListenerEntry(TEXT_TOUCH_DRAG);
        // A long press is touch's way to select: the word under the finger,
        // then whatever the finger sweeps over. Claiming it keeps the moves
        // out of the pan recognizer, so the input does not scroll instead.
        @:privateAccess window.addMouseListenerEntry(new TextLongPressEntry(state, hitbox));
        @:privateAccess window.addMouseListenerEntry(new TextMouseMoveEntry(state));
        @:privateAccess window.addMouseListenerEntry(new TextMouseUpEntry(state));
    }

    /** The touch drag listener (captures nothing: one entry for every text element) */
    static final TEXT_TOUCH_DRAG = new TextTouchDragEntry();

    /**
     * Lays out the carets and updates the scroll position for the active one.
     *
     * Rust takes `bounds: &mut Bounds` and moves its origin by the scroll
     * offset: the moved bounds are returned in the result.
     */
    function layoutCursors(lastLayout:LastLayout, bounds:Bounds, scrollSize:Size, window:Window, cx:App):CursorsLayout {
        final state = this.state.read(cx);

        final lineHeight:Float = lastLayout.lineHeight;
        final visibleRange = lastLayout.visibleRange;
        final lines = lastLayout.lines;

        final activeId = state.activeSelection().id;
        var scrollOffsetX:Float = state.scrollHandle.offset().x;
        var scrollOffsetY:Float = state.scrollHandle.offset().y;
        final initialScrollOffset = state.scrollHandle.offset();
        var currentRow:Null<Int> = null;
        var resizeRevealOwned = false;
        final cursorInfos:Array<CursorRenderInfo> = [];

        // Padding kept between the cursor and the viewport's top/bottom
        // edges, used by the auto-scroll-into-view computation below.
        final topBottomMargin = cursorSurroundingPadding(state.mode.isAutoGrow(), state.cursorSurroundingLines,
            viewportVisibleLines(bounds.size.height, lineHeight), lineHeight);

        // Keep a visible, focused caret visible when its viewport reflows, but
        // do not undo deliberate scrolling away from an unchanged selection.
        final resized = (state.lastBounds != null && !state.lastBounds.size.equals(bounds.size))
            || (state.lastLayout != null && (state.lastLayout.lineHeight : Float) != (lineHeight : Float));
        final old = state.prepaintCaretGeometry;
        final revealOnResize = resized && state.deferredScrollOffset == null && state.focusHandle.isFocused(window) && old != null && {
            // An unshaped caret has provisional x until the notified
            // repaint. Consecutive resize frames retain ownership only
            // while no intervening scroll changed the viewport.
            if (old.resizeRevealOwned) {
                old.scrollOffset().equals(initialScrollOffset);
            }
            else {
                final caret = old.cursorBounds();
                final viewport = old.inputBounds();
                final top = caret.top() + initialScrollOffset.y;
                // Cached x already contains its painted scroll; account only
                // for a wheel offset change since that geometry was produced.
                final left = caret.left() + initialScrollOffset.x - old.scrollOffset().x;
                top >= viewport.top() && top + caret.size.height <= viewport.bottom() && left >= viewport.left()
                    && left + caret.size.width <= viewport.right();
            }
        };

        // Resolve a cursor or selection endpoint to a content-space position.
        final visibleBufferLines = lastLayout.visibleBufferLines;
        function caretFor(row:Int, offset:Int, affinity:Bool):Point {
            // y of the top of buffer line `row` in content space.
            final top = lineHeight * state.displayMap.bufferLineToDisplayRow(row);

            final vi = visibleBufferLines.indexOf(row);
            if (vi >= 0) {
                final line = lines[vi];
                final lineStart = lastLayout.visibleLineByteOffsets[vi];
                final local = offset > lineStart ? offset - lineStart : 0;
                final pos = line.positionForIndex(local, lastLayout, affinity);
                if (pos != null) {
                    return new Point(pos.x, top + pos.y);
                }
            }
            if (state.masked) {
                return new Point(0., top);
            }
            return new Point(0., lineHeight * state.displayMap.offsetToDisplayRow(offset, affinity));
        }

        final cursorHeight = 0.85 * lineHeight;

        for (selection in state.selections.iter()) {
            final isActive = selection.id == activeId;

            var selectedRange = selection.copy();
            var cursor = selection.cursorOffset();
            if (isActive) {
                final imeMarkedRange = state.imeMarkedRange;
                if (imeMarkedRange != null) {
                    selectedRange = CursorSelection.fromRange(new Range(imeMarkedRange.end, imeMarkedRange.end));
                    cursor = imeMarkedRange.end;
                }
            }
            final isSelectedAll = selectedRange.len() == state.text.len();

            // Buffer rows from the raw (pre-mask) offsets, used to locate the cursor line.
            final cursorRow = state.text.offsetToPoint(cursor).row;

            // Skip inactive cursors that are far outside the visible range. The
            // active cursor is always processed so scroll tracking keeps working.
            if (!isActive && (cursorRow + 2 < visibleRange.start || cursorRow > visibleRange.end + 2)) {
                continue;
            }

            final selStartRow = state.text.offsetToPoint(selectedRange.start).row;
            final selEndRow = state.text.offsetToPoint(selectedRange.end).row;
            if (state.masked) {
                selectedRange.start = maskedDisplayOffset(state.text, selectedRange.start);
                selectedRange.end = maskedDisplayOffset(state.text, selectedRange.end);
                cursor = maskedDisplayOffset(state.text, cursor);
            }

            final affinity = isActive && state.cursorLineEndAffinity;
            final cursorPos = caretFor(cursorRow, cursor, affinity);
            final cursorStart = caretFor(selStartRow, selectedRange.start, false);
            final cursorEnd = caretFor(selEndRow, selectedRange.end, false);

            if (isActive) {
                currentRow = cursorRow;

                final selectionChanged = !selectedRange.equals(state.lastSelectedRange);
                final autoScrolling = state.autoScroll.isActive();
                if ((selectionChanged || revealOnResize) && !isSelectedAll) {
                    // Resize-follow owns only vertical visibility. An unshaped
                    // target has no reliable x; retain the existing x offset.
                    if (selectionChanged) {
                        // Right-aligned carets are clamped instead of scrolling.
                        final safetyMargin:Float = switch lastLayout.textAlign {
                            case Left: RIGHT_MARGIN;
                            case Right: 0.;
                            case Center: CURSOR_WIDTH;
                        };
                        scrollOffsetX = if (scrollOffsetX + cursorPos.x > (bounds.size.width - safetyMargin)) {
                            bounds.size.width - safetyMargin - cursorPos.x;
                        }
                        else if (scrollOffsetX + cursorPos.x < 0.) {
                            -cursorPos.x;
                        }
                        else {
                            scrollOffsetX;
                        };
                    }

                    // Vertical cursor-follow is suppressed while auto-scroll manages the y axis,
                    // to prevent fighting the background scroll task.
                    if (!autoScrolling) {
                        scrollOffsetY = revealRow(scrollOffsetY, cursorPos.y, lineHeight, bounds.size.height, topBottomMargin);
                        resizeRevealOwned = revealOnResize;
                    }

                    // For selection to move scroll
                    if (selection.reversed) {
                        if (selectionChanged && scrollOffsetX + cursorStart.x < 0.) {
                            // selection start is out of left
                            scrollOffsetX = -cursorStart.x;
                        }
                        if (!autoScrolling && scrollOffsetY + cursorStart.y < 0.) {
                            // selection start is out of top
                            scrollOffsetY = -cursorStart.y;
                        }
                    }
                    else {
                        // TODO: Consider to remove this part,
                        // maybe is not necessary (But selection_reversed is needed).
                        if (selectionChanged && scrollOffsetX + cursorEnd.x <= 0.) {
                            // selection end is out of left
                            scrollOffsetX = -cursorEnd.x;
                        }
                        if (!autoScrolling && scrollOffsetY + cursorEnd.y <= 0.) {
                            // selection end is out of top
                            scrollOffsetY = -cursorEnd.y;
                        }
                    }
                }
            }

            // Apply the final horizontal offset to every caret after cursor-follow and
            // deferred scrolling have been resolved, regardless of selection order.
            final cursorX = bounds.left() + cursorPos.x;
            cursorInfos.push(new CursorRenderInfo(new Bounds(new Point(cursorX, bounds.top() + cursorPos.y + ((lineHeight - cursorHeight) / 2.)),
                new Size(CURSOR_WIDTH, cursorHeight)), isActive));
        }

        final deferredScrollOffset = state.deferredScrollOffset;
        if (deferredScrollOffset != null) {
            scrollOffsetX = deferredScrollOffset.x;
            scrollOffsetY = deferredScrollOffset.y;
        }
        scrollOffsetX = clampHorizontalScrollOffset(scrollOffsetX, scrollSize.width, bounds.size.width, lastLayout.textAlign);
        for (info in cursorInfos) {
            var x = info.bounds.origin.x + scrollOffsetX;
            // Right-aligned text keeps the caret inside the viewport edge.
            if (lastLayout.textAlign == Right) {
                x = MathUtil.min(x, bounds.right() - CURSOR_WIDTH);
            }
            info.bounds = new Bounds(new Point(x, info.bounds.origin.y), info.bounds.size);
        }
        scrollOffsetY = clampVerticalScrollOffset(scrollOffsetY, scrollSize.height, bounds.size.height);

        final scrollOffset = new Point(scrollOffsetX, scrollOffsetY);
        final movedBounds = new Bounds(bounds.origin.add(scrollOffset), bounds.size);

        return new CursorsLayout(cursorInfos, scrollOffset, currentRow, resizeRevealOwned, movedBounds);
    }

    /** Layout the match range to a Path. */
    public static function layoutMatchRange(range:Range, lastLayout:LastLayout, bounds:Bounds):Null<Path> {
        final corners = layoutRangeCorners(range, lastLayout);
        if (corners == null)
            return null;
        final points = frameOutlinePoints(corners);
        if (points.length == 0)
            return null;
        final origin = bounds.origin;
        final builder = PathBuilder.fill();
        builder.moveTo(origin.add(points[0]));
        for (i in 1...points.length) {
            builder.lineTo(origin.add(points[i]));
        }
        builder.close();
        return buildPath(builder);
    }

    /** Rust `builder.build().ok()` */
    static function buildPath(builder:PathBuilder):Null<Path> {
        try {
            return builder.build();
        }
        catch (e:Dynamic) {
            return null;
        }
    }

    /**
     * Project a buffer range through the visible (non-folded) shaped lines.
     * Half-open intersections give soft-wrap ends their trailing affinity and
     * prevent ranges on later lines from painting an earlier line's first glyph.
     */
    static function layoutRangeCorners(range:Range, lastLayout:LastLayout):Null<Array<CornersOf<Point>>> {
        final rangeStart = range.start > lastLayout.visibleRangeOffset.start ? range.start : lastLayout.visibleRangeOffset.start;
        final rangeEnd = range.end < lastLayout.visibleRangeOffset.end ? range.end : lastLayout.visibleRangeOffset.end;
        if (rangeStart >= rangeEnd) {
            return null;
        }

        var y:Float = lastLayout.visibleTop;
        final corners:Array<CornersOf<Point>> = [];
        final count = lastLayout.visibleLineByteOffsets.length < lastLayout.lines.length ? lastLayout.visibleLineByteOffsets.length : lastLayout.lines.length;
        for (li in 0...count) {
            final lineOffset = lastLayout.visibleLineByteOffsets[li];
            final line = lastLayout.lines[li];
            var offset = lineOffset;
            final alignment:Float = lastLayout.alignmentOffset(line.longestWidth);
            for (row in 0...line.wrappedLines.length) {
                final shaped = line.wrappedLines[row];
                final end = offset + shaped.len;
                final startIx = rangeStart > offset ? rangeStart : offset;
                final endIx = rangeEnd < end ? rangeEnd : end;
                final isLast = row + 1 == line.wrappedLines.length;
                // A selected newline has a one-space cell, including empty lines.
                // A wrap boundary is not a newline and must not get such a cell.
                final newline = isLast && rangeStart <= end && rangeEnd > end;
                if (startIx < endIx || newline) {
                    final indent = row == 0 ? 0. : line.wrapIndent;
                    final left = alignment + indent + shaped.xForIndex((startIx < end ? startIx : end) - offset);
                    final right = alignment + indent + (newline ? shaped.width + lastLayout.spaceWidth : shaped.xForIndex(endIx - offset));
                    corners.push(new CornersOf<Point>(new Point(left, y), new Point(right, y), new Point(right, y + lastLayout.lineHeight),
                        new Point(left, y + lastLayout.lineHeight)));
                }
                offset = end;
                y += lastLayout.lineHeight;
            }
        }
        return corners.length > 0 ? corners : null;
    }

    function layoutSearchMatches(lastLayout:LastLayout, bounds:Bounds, cx:App):Array<MatchPath> {
        final state = this.state.read(cx);
        if (!state.searchSession.isActive()) {
            return [];
        }
        final ranges = state.searchSession.matcher.matchedRanges();
        final currentMatchIx = state.searchSession.matcher.currentMatchIndex();

        // Matches are sorted and do not overlap, so only the ones that reach
        // into the visible range need a layout.
        final visibleRange = lastLayout.visibleRangeOffset;
        final first = partitionPoint(ranges.length, i -> ranges[i].end <= visibleRange.start);
        final paths:Array<MatchPath> = [];
        var index = first;
        while (index < ranges.length && ranges[index].start < visibleRange.end) {
            final path = layoutMatchRange(ranges[index], lastLayout, bounds);
            if (path != null) {
                paths.push(new MatchPath(path, currentMatchIx == index));
            }
            index++;
        }

        return paths;
    }

    /** Rust `slice::partition_point` over `len` items. */
    static function partitionPoint(len:Int, pred:(Int) -> Bool):Int {
        var lo = 0;
        var hi = len;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (pred(mid)) {
                lo = mid + 1;
            }
            else {
                hi = mid;
            }
        }
        return lo;
    }

    function layoutSelections(lastLayout:LastLayout, bounds:Bounds, window:Window, cx:App):Array<Path> {
        final state = this.state.read(cx);
        if (!state.hasSelectionFocus(window, cx)) {
            return [];
        }

        final activeId = state.activeSelection().id;
        final paths:Array<Path> = [];

        for (selection in state.selections.iter()) {
            final isActive = selection.id == activeId;
            var selectedRange = selection.copy();

            // IME composition replaces the active selection with a collapsed
            // caret, so it never paints a selection highlight.
            if (isActive) {
                final imeMarkedRange = state.imeMarkedRange;
                if (imeMarkedRange != null) {
                    if (!imeMarkedRange.isEmpty()) {
                        selectedRange = CursorSelection.fromRange(new Range(imeMarkedRange.end, imeMarkedRange.end));
                    }
                }
            }
            if (selectedRange.isEmpty()) {
                continue;
            }

            if (state.masked) {
                selectedRange.start = maskedDisplayOffset(state.text, selectedRange.start);
                selectedRange.end = maskedDisplayOffset(state.text, selectedRange.end);
            }

            final startIx = selectedRange.start < selectedRange.end ? selectedRange.start : selectedRange.end;
            final endIx = selectedRange.start < selectedRange.end ? selectedRange.end : selectedRange.start;

            final rangeStart = startIx > lastLayout.visibleRangeOffset.start ? startIx : lastLayout.visibleRangeOffset.start;
            final rangeEnd = endIx < lastLayout.visibleRangeOffset.end ? endIx : lastLayout.visibleRangeOffset.end;

            if (rangeStart >= rangeEnd) {
                continue;
            }

            // A selected token shows its own selected state, so the text
            // highlight stops at its edges instead of painting behind it.
            var start = rangeStart;
            if (state.tokensVisible()) {
                final spans = state.tokenSpans();
                var ix = partitionPoint(spans.length, i -> spans[i].range().end <= rangeStart);
                while (ix < spans.length && spans[ix].range().start < rangeEnd) {
                    final span = spans[ix];
                    if (start < span.range().start) {
                        final path = layoutMatchRange(new Range(start, span.range().start), lastLayout, bounds);
                        if (path != null)
                            paths.push(path);
                    }
                    start = span.range().end > start ? span.range().end : start;
                    ix++;
                }
            }
            if (start < rangeEnd) {
                final path = layoutMatchRange(new Range(start, rangeEnd), lastLayout, bounds);
                if (path != null)
                    paths.push(path);
            }
        }

        return paths;
    }

    /**
     * Calculate the visible range of lines in the viewport.
     *
     * Returns
     *
     * - visibleRange: The visible range is based on unwrapped lines (Zero based).
     * - visibleBufferLines: Indices of non-hidden buffer lines within the visible range.
     * - visibleTop: The top position of the first visible line in the scroll viewport.
     */
    function calculateVisibleRange(state:InputBaseState, lineHeight:Float, inputHeight:Float):VisibleLines {
        // Add extra rows to avoid showing empty space when scroll to bottom.
        final extraRows = 1;
        if (state.isSingleLine()) {
            return new VisibleLines(new Range(0, 1), [0], 0.);
        }

        final totalLines = state.displayMap.wrapRowCount();
        final displayCount = state.displayMap.displayRowCount();
        final bufferLineCount = state.displayMap.bufferLineCount();
        if (displayCount == 0 || bufferLineCount == 0) {
            return new VisibleLines(new Range(0, 0), [], 0.);
        }

        var scrollTop:Float = state.deferredScrollOffset != null ? state.deferredScrollOffset.y : state.scrollHandle.offset().y;
        // Clamp as `layoutCursors` does, so we lay out the rows we paint.
        final scrollHeight = lineHeight * totalLines;
        scrollTop = clampVerticalScrollOffset(scrollTop, scrollHeight, inputHeight);

        // Display rows are uniformly `lineHeight` tall, so the visible window maps
        // directly to a display-row range.
        final viewportTop = MathUtil.max(-scrollTop, 0.);
        final viewportBottom = viewportTop + inputHeight;
        final lineHeightF:Float = lineHeight;
        final firstDisplay = minInt(usize(Math.ffloor(viewportTop / lineHeightF)), displayCount - 1);
        final lastDisplay = minInt(usize(Math.fceil(viewportBottom / lineHeightF)), displayCount - 1);

        final startLine = state.displayMap.displayRowToBufferLine(firstDisplay);
        final endLine = state.displayMap.displayRowToBufferLine(lastDisplay);

        // y of the top of the first visible buffer line (in content space).
        final rowRange = state.displayMap.bufferLineToDisplayRowRange(startLine);
        final visibleTop:Float = rowRange != null ? lineHeight * rowRange.start : lineHeight * firstDisplay;

        final visibleRange = new Range(startLine, minInt(endLine + 1 + extraRows, bufferLineCount));

        // Collect non-hidden buffer lines within the visible range
        final visibleBufferLines:Array<Int> = [];
        for (ix in visibleRange.start...visibleRange.end) {
            if (state.displayMap.visibleWrapRowCountForBufferLine(ix) > 0) {
                visibleBufferLines.push(ix);
            }
        }

        return new VisibleLines(visibleRange, visibleBufferLines, visibleTop);
    }

    static inline function minInt(a:Int, b:Int):Int {
        return a < b ? a : b;
    }

    /**
     * Layout shaped lines for whitespace indicators (space and tab).
     *
     * Returns `WhitespaceIndicators` with shaped lines for space and tab characters.
     */
    static function layoutWhitespaceIndicators(state:InputBaseState, textSize:Float, style:TextStyle, window:Window, cx:App):Null<WhitespaceIndicators> {
        if (!state.showWhitespaces) {
            return null;
        }

        final invisibleColor = state.editorStyle.editorInvisible != null ? state.editorStyle.editorInvisible : state.editorStyle.mutedForeground;

        final spaceFontSize:Float = textSize / 2.;
        final tabFontSize = textSize;

        final spaceText = '•';
        final space = window.textSystem().shapeLine(spaceText, spaceFontSize,
            [new TextRun(Utf8.byteLength(spaceText), style.font(), invisibleColor, null, null, null)]);

        final tabText = '→';
        final tab = window.textSystem().shapeLine(tabText, tabFontSize, [new TextRun(Utf8.byteLength(tabText), style.font(), invisibleColor, null, null, null)]);

        return new WhitespaceIndicators(space, tab);
    }

    function tokenElement(token:InlineTokenContext, window:Window, cx:App):AnyElement {
        final presentation = this.state.read(cx).tokenPresentation;
        final child = presentation.render(token, window, cx);
        // Preserve interaction state only for the same token occurrence and
        // hover eligibility. Replacements and re-enabling start fresh.
        final start = token.range().start;
        final entity = this.state;
        final hoverToken = token.token();
        final disabled = token.isDisabled();
        final hoverEnabled = presentation.hasHoverListener() && !disabled;
        var id = ElementId.NamedInteger('inline-token', start);
        id = ElementId.NamedChild(id, token.token().id());
        id = ElementId.NamedChild(id, token.token().text());
        id = ElementId.NamedChild(id, token.token().label());
        id = ElementId.NamedChild(id, hoverEnabled ? 'hover-enabled' : 'hover-disabled');
        // Not ported: the `Button` role, aria label and accessible click
        // action (`presentation.has_listener() && !disabled`): Glaze
        // has no accessibility tree.
        return (div()
            .id(id)
            .flex()
            .itemsCenter()
            .h(token.lineHeight())
            .maxW(token.availableWidth())
            .overflowHidden()
            // A token is an object, not text: the arrow, never the I-beam.
            .cursorDefault()
            .captureAnyMouseDown((_, window, cx) -> {
                if (disabled) {
                    window.preventDefault();
                    cx.stopPropagation();
                }
            })
            .captureAnyMouseUp((_, window, cx) -> {
                if (disabled) {
                    window.preventDefault();
                    cx.stopPropagation();
                }
            })
            .captureKeyDown((_, _, cx) -> {
                if (disabled) {
                    cx.stopPropagation();
                }
            })
            .onMouseDown(Left, (event, window, cx) -> {
                if (window.defaultPrevented()) {
                    return;
                }
                entity.update(cx, (state, cx) -> {
                    state.pressedToken = null;
                    if (event.clickCount == 2) {
                        final span = findSpan(state, start);
                        if (span != null) {
                            state.setSelectedRange(span.range(), cx);
                            state.focus(window, cx);
                            window.preventDefault();
                        }
                    }
                    else if (event.clickCount == 1 && !event.modifiers.shift && !event.modifiers.alt) {
                        state.pressedToken = {start: start, revision: state.documentRevision, position: event.position};
                    }
                });
            })
            .onMouseMove((event, _, cx) -> {
                entity.update(cx, (state, _) -> {
                    final pressed = state.pressedToken;
                    if (pressed != null && Math.abs(event.position.x - pressed.position.x) + Math.abs(event.position.y - pressed.position.y) > 4.) {
                        state.pressedToken = null;
                    }
                });
            })
            .onClick((event, window, cx) -> {
                final activation = entity.update(cx, (state, cx) -> {
                    final pressed = state.pressedToken;
                    state.pressedToken = null;
                    if (pressed == null) {
                        return null;
                    }
                    if (pressed.start != start || pressed.revision != state.documentRevision) {
                        return null;
                    }
                    if (event.modifiers().shift || event.modifiers().alt) {
                        return null;
                    }
                    final span = findSpan(state, start);
                    if (span == null) {
                        return null;
                    }
                    // A click selects the whole token; opening it is the
                    // listener's decision.
                    state.setSelectedRange(span.range(), cx);
                    final bounds = state.rangeToBounds(span.range());
                    if (bounds == null) {
                        return null;
                    }
                    return state.tokenActivation(start, bounds, event);
                });
                if (activation != null) {
                    activation.listener(activation.event, window, cx);
                }
            })
            .onHover((hovered, window, cx) -> {
                // Hover never selects or edits; it only reports presence so the
                // application can show a tooltip or run custom logic.
                final activation = entity.update(cx, (state, _) -> {
                    // Anchor to the real laid-out token rect, not the
                    // range-to-bounds guess: a token at a soft-wrap boundary
                    // would otherwise report a zero/negative width or a
                    // two-row height.
                    final bounds = if (hovered) {
                        final found = state.tokenBounds.get(start);
                        if (found == null) {
                            return null;
                        }
                        found;
                    }
                    else {
                        // Exits use entry geometry even if an earlier callback
                        // removed the token and its current bounds.
                        new Bounds();
                    };
                    return state.tokenHover(start, bounds, hovered, hoverToken);
                });
                if (activation != null) {
                    activation.listener(activation.event, window, cx);
                }
            })
            .child(child) : IntoElement).intoAnyElement();
    }

    static function findSpan(state:InputBaseState, start:Int):Null<InlineTokenSpan> {
        for (span in state.tokenSpans()) {
            if (span.range().start == start)
                return span;
        }
        return null;
    }

    /** Run the hover exits `reconcileTokenHover` hands out until there are none. */
    function drainTokenHoverExits(clearBounds:Null<Map<Int, Bounds>>, window:Window, cx:App):Void {
        var exit = this.state.update(cx, (state, _) -> {
            state.tokenBounds = clearBounds != null ? clearBounds : new Map();
            return state.reconcileTokenHover();
        });
        while (exit != null) {
            exit.listener(exit.event, window, cx);
            exit = this.state.update(cx, (state, _) -> state.reconcileTokenHover());
        }
    }

    function measureTokens(width:Float, lineHeight:Float, viewport:Float, window:Window, cx:App):Map<Int, MeasuredToken> {
        final style = window.textStyle();
        final state = this.state.read(cx);
        final key = new TokenLayoutKey(style.font(), style.fontSize.toPixels(window.remSize()), width, lineHeight, state.isSingleLine() || !state.softWrap);
        if (!state.tokensVisible()) {
            if (state.tokenLayoutCache == null) {
                drainTokenHoverExits(null, window, cx);
                return new Map();
            }
            this.state.update(cx, (state, cx) -> {
                state.displayMap.setInlineMetrics([], cx.app);
            });
            drainTokenHoverExits(null, window, cx);
            return new Map();
        }
        final revision = state.documentRevision;
        final cache = state.tokenLayoutCache;
        final all = cache == null || !key.equals(cache.key) || cache.revision != revision || {
            var missing = false;
            for (span in state.tokenSpans()) {
                if (!cache.widths.exists(span.token().hashKey())) {
                    missing = true;
                    break;
                }
            }
            missing;
        };
        final visible = calculateVisibleRange(state, lineHeight, viewport).range;
        final start = state.text.lineStartOffset(visible.start);
        final end = state.text.lineEndOffset(visible.end > 0 ? visible.end - 1 : 0);
        final spans = state.tokenSpans();
        final first = all ? 0 : partitionPoint(spans.length, i -> spans[i].range().end <= start);
        final contexts:Array<InlineTokenContext> = [];
        var ix = first;
        while (ix < spans.length && (all || spans[ix].range().start <= end)) {
            final span = spans[ix];
            final range = span.range();
            if ((range.start <= end && range.end >= start)
                || cache == null
                || !key.equals(cache.key)
                || !cache.widths.exists(span.token().hashKey())) {
                contexts.push(state.tokenContext(span, lineHeight, width));
            }
            ix++;
        }
        final elements = new Map<Int, MeasuredToken>();
        final measured:Array<{token:InlineToken, width:Float}> = [];
        for (token in contexts) {
            final element = tokenElement(token, window, cx);
            final size = element.layoutAsRoot(new SizeOf<AvailableSpace>(MaxContent, Definite(lineHeight)), window, cx);
            measured.push({token: token.token(), width: MathUtil.max(MathUtil.min(size.width, width), 1.)});
            elements.set(token.range().start, new MeasuredToken(element, size));
        }
        this.state.update(cx, (state, cx) -> {
            final cache = state.tokenLayoutCache != null ? state.tokenLayoutCache : new TokenLayoutCache();
            state.tokenLayoutCache = null;
            var changed = !key.equals(cache.key) || cache.revision != revision;
            if (!key.equals(cache.key)) {
                cache.widths.clear();
            }
            for (m in measured) {
                final k = m.token.hashKey();
                changed = changed || !cache.widths.exists(k) || (cache.widths.get(k) : Float) != (m.width : Float);
                cache.widths.set(k, m.width);
            }
            cache.key = key;
            if (changed) {
                final spans = state.tokenSpans();
                final tokens = new Map<String, Bool>();
                for (s in spans)
                    tokens.set(s.token().hashKey(), true);
                for (k in [for (k in cache.widths.keys()) k]) {
                    if (!tokens.exists(k))
                        cache.widths.remove(k);
                }
                cache.metrics = [
                    for (span in spans)
                        if (cache.widths.exists(span.token().hashKey()))
                            new TokenMetric(span.range(), cache.widths.get(span.token().hashKey()))
                ];
                cache.revision = revision;
                if (state.isSingleLine() || !state.softWrap) {
                    final rows:Array<Int> = [for (s in spans) state.text.offsetToPoint(s.range().start).row];
                    rows.push(state.displayMap.longestRow());
                    rows.sort((a, b) -> a - b);
                    final unique:Array<Int> = [];
                    for (row in rows) {
                        if (unique.length == 0 || unique[unique.length - 1] != row)
                            unique.push(row);
                    }
                    final fontSize = style.fontSize.toPixels(window.remSize());
                    var best:Null<Float> = null;
                    for (row in unique) {
                        final start = state.text.lineStartOffset(row);
                        final text = state.text.sliceLine(row).toString();
                        final textLen = Utf8.byteLength(text);
                        var offset = 0;
                        var width:Float = 0.;
                        var ix = partitionPoint(spans.length, i -> spans[i].range().end <= start);
                        while (ix < spans.length && spans[ix].range().start < start + textLen) {
                            final span = spans[ix];
                            final localStart = span.range().start - start;
                            final localEnd = span.range().end - start;
                            final part = Utf8.substring(text, offset, localStart);
                            width += window.textSystem().shapeLine(part, fontSize, [style.toRun(Utf8.byteLength(part))]).width();
                            final w = cache.widths.get(span.token().hashKey());
                            width += w != null ? w : 0.;
                            offset = localEnd;
                            ix++;
                        }
                        final part = Utf8.substringFrom(text, offset);
                        final total = width + window.textSystem().shapeLine(part, fontSize, [style.toRun(Utf8.byteLength(part))]).width();
                        if (best == null || total > best)
                            best = total;
                    }
                    cache.unwrappedWidth = best != null ? best : 0.;
                }
            }
            final metrics = [for (m in cache.metrics) new InlineMetric(m.range, m.width)];
            state.tokenLayoutCache = cache;
            state.displayMap.setInlineMetrics(metrics, cx.app);
            if (state.mode.isAutoGrow()) {
                final rows = state.mode.rows();
                state.mode.updateAutoGrow(state.displayMap);
                if (state.mode.rows() != rows) {
                    cx.notify();
                }
            }
        });
        return elements;
    }

    static function layoutTokenLines(state:InputBaseState, lastLayout:LastLayout, fontSize:Float, runs:Array<TextRun>, window:Window):Array<InputLineLayout> {
        final spans = state.tokenSpans();
        final cache = state.tokenLayoutCache;
        if (cache == null)
            throw 'tokens measured before shaping';
        var runOffset = 0;
        final result:Array<InputLineLayout> = [];
        for (row in lastLayout.visibleBufferLines) {
            final lineStart = state.text.lineStartOffset(row);
            final text = state.text.sliceLine(row).toString();
            final textLen = Utf8.byteLength(text);
            final ranges = if (state.isSingleLine()) {
                [new Range(0, textLen)];
            }
            else {
                final item = state.displayMap.line(row);
                if (item == null)
                    throw 'prepared line';
                item.wrappedLines.copy();
            };
            final lines:Array<InputLine> = [];
            for (range in ranges) {
                final fragments:Array<InlineFragment> = [];
                var offset = range.start;
                var x:Float = 0.;
                var ix = partitionPoint(spans.length, i -> spans[i].range().end <= lineStart + range.start);
                while (ix < spans.length && spans[ix].range().start < lineStart + range.end) {
                    final span = spans[ix];
                    final localStart = span.range().start - lineStart;
                    final localEnd = span.range().end - lineStart;
                    if (offset < localStart) {
                        final part = new Range(offset, localStart);
                        final shaped = window.textSystem().shapeLine(Utf8.substring(text, part.start, part.end), fontSize, runsForRange(runs, runOffset, part));
                        final width:Float = shaped.width();
                        fragments.push(new InlineFragment(new Range(part.start - range.start, part.end - range.start), x, width, shaped));
                        x += width;
                    }
                    final w = cache.widths.get(span.token().hashKey());
                    final width:Float = w != null ? w : 0.;
                    fragments.push(new InlineFragment(new Range(localStart - range.start, localEnd - range.start), x, width, null));
                    x += width;
                    offset = localEnd;
                    ix++;
                }
                if (offset < range.end) {
                    final part = new Range(offset, range.end);
                    final shaped = window.textSystem().shapeLine(Utf8.substring(text, part.start, part.end), fontSize, runsForRange(runs, runOffset, part));
                    final width:Float = shaped.width();
                    fragments.push(new InlineFragment(new Range(part.start - range.start, part.end - range.start), x, width, shaped));
                }
                lines.push(InputLine.inlineLine(Utf8.substring(text, range.start, range.end), fragments));
            }
            final item = state.displayMap.line(row);
            final indent = item != null ? item.indent : 0;
            final wrapIndent:Float = if (indent > 0 && lines.length > 1) {
                lines[0].xForIndex(charIndexToByte(text, indent));
            }
            else {
                0.;
            };
            runOffset += textLen + 1;
            result.push(new InputLineLayout().inlineLines(lines).withWrapIndent(wrapIndent));
        }
        return result;
    }

    /** Byte offset of the char at `charIndex` of `text`, or its length (Rust `char_indices().nth(n)`). */
    static function charIndexToByte(text:String, charIndex:Int):Int {
        final codePoints:Array<Int> = [];
        final byteOffsets:Array<Int> = [];
        final count = Utf8.decode(text, codePoints, byteOffsets);
        return charIndex < count ? byteOffsets[charIndex] : Utf8.byteLength(text);
    }

    /**
     * Asks the scroll containers around a focused input to bring it into
     * view, once when it gains focus and again whenever the fully visible
     * part of the window changes, so manual scrolling in between is left
     * alone. Ancestors must support autoscroll requests; inset-only keyboard
     * avoidance additionally requires the ancestor to use the fully visible
     * viewport for its scrolling bounds and scroll range. Stock GPUI's List
     * uses layout bounds and does not avoid inset-only occlusion.
     *
     * A single-line input asks for all of itself. A taller one asks for the
     * line with the caret, or its top part when it has no caret.
     */
    function requestReveal(inputBounds:Bounds, cursorInfos:Array<CursorRenderInfo>, cursorScrollOffset:Point, lineHeight:Float, window:Window, cx:App):Void {
        final focused = this.state.read(cx).focusHandle.isFocused(window);
        // `Window::fully_visible_bounds`: Glaze has no safe area insets
        // nor visual viewport, so it is the whole viewport.
        final viewport = new Bounds(new Point(0., 0.), window.viewportSize());
        final reveal = this.state.update(cx, (state, _) -> {
            final target = focused ? viewport : null;
            final changed = !(state.revealedViewport == null ? target == null : state.revealedViewport.equals(target));
            state.revealedViewport = target;
            return focused && changed;
        });
        if (!reveal || inputBounds.size.height <= 0.) {
            return;
        }

        var top:Float;
        var height:Float;
        var caret:Null<CursorRenderInfo> = null;
        for (info in cursorInfos) {
            if (info.isActive) {
                caret = info;
                break;
            }
        }
        if (!this.state.read(cx).isMultiLine()) {
            top = inputBounds.top();
            height = inputBounds.size.height;
        }
        else if (caret != null) {
            top = MathUtil.clamp(caret.bounds.top() + cursorScrollOffset.y, inputBounds.top(), inputBounds.bottom());
            height = MathUtil.min(lineHeight, inputBounds.bottom() - top);
        }
        else {
            top = inputBounds.top();
            height = MathUtil.min(inputBounds.size.height, REVEAL_MAX_HEIGHT);
        }
        final request = new Bounds(new Point(inputBounds.left(), top), new Size(inputBounds.size.width, height));
        window.requestAutoscroll(request.dilate(REVEAL_MARGIN));
    }

    function prepaintTokens(layout:LastLayout, bounds:Bounds, measured:Map<Int, MeasuredToken>, window:Window, cx:App):Array<AnyElement> {
        final state = this.state.read(cx);
        if (!state.tokensVisible()) {
            drainTokenHoverExits(null, window, cx);
            return [];
        }
        final width:Float = state.tokenLayoutCache != null && state.tokenLayoutCache.key != null ? state.tokenLayoutCache.key.width : bounds.size.width;
        final placements:Array<TokenPlacement> = [];
        var y:Float = layout.visibleTop;
        for (ix in 0...layout.visibleBufferLines.length) {
            final row = layout.visibleBufferLines[ix];
            final start = state.text.lineStartOffset(row);
            final end = state.text.lineEndOffset(row);
            final spans = state.tokenSpans();
            var si = partitionPoint(spans.length, i -> spans[i].range().end <= start);
            while (si < spans.length && spans[si].range().start < end) {
                final span = spans[si];
                final position = layout.lines[ix].positionForIndex(span.range().start - start, layout, false);
                if (position != null) {
                    placements.push(new TokenPlacement(state.tokenContext(span, layout.lineHeight, width),
                        bounds.origin.add(position).add(new Point(0., y))));
                }
                si++;
            }
            y += layout.lines[ix].size(layout.lineHeight).height;
        }
        final out:Array<AnyElement> = [];
        final tokenBounds = new Map<Int, Bounds>();
        for (placement in placements) {
            final token = placement.token;
            final origin = placement.origin;
            var found = measured.get(token.range().start);
            if (found != null) {
                measured.remove(token.range().start);
            }
            else {
                final element = tokenElement(token, window, cx);
                final elementSize = element.layoutAsRoot(new SizeOf<AvailableSpace>(MaxContent, Definite(layout.lineHeight)), window, cx);
                found = new MeasuredToken(element, elementSize);
            }
            found.element.prepaintAt(origin, window, cx);
            tokenBounds.set(token.range().start, new Bounds(origin, found.size));
            out.push(found.element);
        }
        drainTokenHoverExits(tokenBounds, window, cx);
        return out;
    }

    static function layoutLines(state:InputBaseState, displayText:Rope, lastLayout:LastLayout, fontSize:Float, runs:Array<TextRun>,
            whitespaceIndicators:Null<WhitespaceIndicators>, window:Window):Array<InputLineLayout> {
        final isSingleLine = state.isSingleLine();
        if (state.tokensVisible()) {
            return layoutTokenLines(state, lastLayout, fontSize, runs, window);
        }

        final tabStop = TabStops.tabStopWidth(window.textSystem(), window.textStyle().font(), fontSize, state.mode.tabSize().tabSize);

        if (isSingleLine) {
            final text = displayText.toString();
            final alignedRuns = alignRunsToCharBoundaries(text, runs);
            final lineRuns = alignedRuns != null ? alignedRuns : runs;
            final shapedLine = window.textSystem().shapeLine(text, fontSize, lineRuns);
            TabStops.expandTabs(shapedLine, tabStop);

            final lineLayout = new InputLineLayout().lines([shapedLine]).withBackground(hasBackground(lineRuns)).withWhitespaces(whitespaceIndicators);
            return [lineLayout];
        }

        // Empty to use placeholder, the placeholder is not in the wrapper map.
        if (state.text.len() == 0) {
            final placeholderText = displayText.toString();
            final placeholderLines:Array<ShapedLine> = [];
            var lineHasBackground = false;

            for (entry in placeholderLineRuns(placeholderText, runs)) {
                final shapedLine = window.textSystem().shapeLine(entry.line, fontSize, entry.runs);
                lineHasBackground = lineHasBackground || hasBackground(entry.runs);
                placeholderLines.push(shapedLine);
            }

            // Keep placeholder lines in a single layout to stay parallel with visible_* metadata.
            final lineLayout = new InputLineLayout().lines(placeholderLines).withBackground(lineHasBackground).withWhitespaces(whitespaceIndicators);
            return [lineLayout];
        }

        final lines:Array<InputLineLayout> = [];
        // runOffset tracks position in the runs vec coordinate space (only visible line bytes).
        // This is separate from the visible_text offset because runs from highlightLines
        // only cover visible (non-folded) lines.
        var runOffset = 0;

        for (vi in 0...lastLayout.visibleBufferLines.length) {
            final bufferLine = lastLayout.visibleBufferLines[vi];
            final lineText = displayText.sliceLine(bufferLine).toString();
            final lineItem = state.displayMap.line(bufferLine);
            if (lineItem == null)
                throw 'line should exists in wrapper';

            final wrappedLines:Array<ShapedLine> = [];
            var lineHasBackground = false;

            for (range in lineItem.wrappedLines) {
                var lineRuns = runsForRange(runs, runOffset, range);

                final subLine = Utf8.substring(lineText, range.start, range.end);
                final aligned = alignRunsToCharBoundaries(subLine, lineRuns);
                if (aligned != null)
                    lineRuns = aligned;
                final shapedLine = window.textSystem().shapeLine(subLine, fontSize, lineRuns);
                TabStops.expandTabs(shapedLine, tabStop);

                lineHasBackground = lineHasBackground || hasBackground(lineRuns);
                wrappedLines.push(shapedLine);
            }

            // Use the first visual line's indentation width for continuation lines.
            final wrapIndent:Float = if (lineItem.indent > 0 && wrappedLines.length > 1) {
                wrappedLines[0].xForIndex(charIndexToByte(lineText, lineItem.indent));
            }
            else {
                0.;
            };

            final lineLayout = new InputLineLayout().lines(wrappedLines)
                .withWrapIndent(wrapIndent)
                .withBackground(lineHasBackground)
                .withWhitespaces(whitespaceIndicators != null ? whitespaceIndicators.clone() : null);
            lines.push(lineLayout);

            // +1 for the `\n`
            runOffset += Utf8.byteLength(lineText) + 1;
        }

        return lines;
    }

/// impl Element for TextElement

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final state = this.state.read(cx);
        final lineHeight:Float = window.lineHeight();

        final style = new Style();
        style.sizeWidth = Length.Definite(relative(1.));
        if (state.isMultiLine()) {
            style.flexGrow = 1.0;
            style.sizeHeight = Length.Definite(relative(1.));
            // At least `rows` tall (auto grow: the content's rows, capped at
            // `max_rows`); a taller parent still fills it.
            final rows = minInt(state.mode.maxRows(), state.mode.rows());
            final minHeight:Float = rows * lineHeight;
            style.minSizeHeight = px(minHeight).toLength();
        }
        else {
            // For single-line inputs, the minimum height should be the line height
            style.sizeHeight = px(lineHeight).toLength();
        };

        return window.requestLayout(style, [], cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final style = window.textStyle();
        final font = style.font();
        final textSize = style.fontSize.toPixels(window.remSize());
        // Past the end of a line there are no glyphs to hit-test against, so a pointer
        // out there is measured in spaces instead.
        final spaceWidth = {
            final fontId = window.textSystem().resolveFont(font);
            window.textSystem().layoutWidth(fontId, textSize, ' '.code);
        };

        // Text stretched past an end is drawn that far from where it scrolled
        // to, inside the frame that clips it, and springs back over the next
        // frames. Scrolling and everything measured from it stay exact.
        var stretch:Float = this.state.update(cx, (state, cx) -> {
            state.displayMap.setFont(font, textSize, cx.app);
            final tabSize = state.mode.tabSize().tabSize;
            state.displayMap.setTabSize(tabSize, cx.app);
            state.displayMap.ensureTextPrepared(state.text, cx.app);
            if (cx.app.reduceMotion()) {
                state.overscroll.reset();
            }
            else if (state.overscroll.step(cx.app.backgroundExecutor().now())) {
                window.requestAnimationFrame();
            }
            return state.overscroll.offset();
        });

        var state = this.state.read(cx);
        final multiLine = state.isMultiLine();
        final text = state.text.clone();
        final isEmpty = text.len() == 0;
        final placeholder = _placeholder;

        final textStyle = window.textStyle();
        final disabled = state.disabled;
        inline function dim(color:Hsla):Hsla {
            return disabled ? color.opacity(0.5) : color;
        }
        final fg = dim(textStyle.color);
        final displayText:Rope = if (isEmpty) {
            Rope.fromStr(placeholder);
        }
        else if (state.masked) {
            Rope.fromStr(StringTools.lpad('', Utf8.fromCodePoint(MASK_CHAR), text.lenChars()));
        }
        else {
            text;
        };
        final textColor = isEmpty ? dim(state.editorStyle.mutedForeground) : fg;

        var bounds = bounds;
        final wrapWidth:Null<Float> = if (multiLine && state.softWrap) {
            bounds.size.width - RIGHT_MARGIN;
        }
        else {
            null;
        };

        final wrappingIndent = state.wrappingIndent;
        final wrapWidthChanged = state.lastLayout != null ? !sameWidth(state.lastLayout.wrapWidth, wrapWidth) : true;

        final wrappingIndentChanged = state.lastLayout != null ? state.lastLayout.wrappingIndent != wrappingIndent : true;

        if (wrapWidthChanged || wrappingIndentChanged) {
            this.state.update(cx, (state, cx) -> {
                state.displayMap.onLayoutChanged(wrapWidth, cx.app);
                state.displayMap.setWrappingIndent(wrappingIndent, cx.app);
            });
        }

        final lineHeight:Float = window.lineHeight();
        final tokenElements = measureTokens(MathUtil.max(bounds.size.width - RIGHT_MARGIN, 1.), lineHeight, bounds.size.height, window, cx);
        state = this.state.read(cx);

        final visible = calculateVisibleRange(state, lineHeight, bounds.size.height);
        final visibleRange = visible.range;
        final visibleBufferLines = visible.bufferLines;
        final visibleTop = visible.top;
        final visibleStartOffset = state.text.lineStartOffset(visibleRange.start);
        final visibleEndOffset = state.text.lineEndOffset(visibleRange.end > 0 ? visibleRange.end - 1 : 0);

        state = this.state.read(cx);

        var visibleLineByteOffsets:Array<Int> = [for (bl in visibleBufferLines) state.text.lineStartOffset(bl)];

        // For password input (masked: true), convert byte offsets to masked display byte offsets so that
        // layoutMatchRange and positionForIndex work in the correct coordinate space.
        final visibleRangeOffset = if (state.masked) {
            visibleLineByteOffsets = [for (o in visibleLineByteOffsets) maskedDisplayOffset(text, o)];
            new Range(maskedDisplayOffset(text, visibleStartOffset), maskedDisplayOffset(text, visibleEndOffset));
        }
        else {
            new Range(visibleStartOffset, visibleEndOffset);
        };

        final lastLayout = new LastLayout(visibleRange, visibleBufferLines, visibleLineByteOffsets, visibleTop, visibleRangeOffset, [], lineHeight,
            wrapWidth, wrappingIndent, spaceWidth, null, state.textAlign, bounds.size.width);

        final run = new TextRun(displayText.len(), style.font(), textColor, null, null, null);
        final markedUnderline = new UnderlineStyle(1., textColor, false);

        final imeMarkedRange = imeMarkedDisplayRange(text, state.imeMarkedRange != null ? new Range(state.imeMarkedRange.start, state.imeMarkedRange.end) : null,
            state.masked);

        // gpui-kit's code editor styles the runs with its highlighter,
        // diagnostics and decorations; inputs and textareas have one style.
        final runs:Array<TextRun> = splitRunForImeUnderline(run, new Range(0, displayText.len()), imeMarkedRange, markedUnderline);

        // Create shaped lines for whitespace indicators before layout
        final whitespaceIndicators = layoutWhitespaceIndicators(state, textSize, textStyle, window, cx);

        final lines = layoutLines(state, displayText, lastLayout, textSize, runs, whitespaceIndicators, window);

        var longestLineWidth:Float = wrapWidth != null ? wrapWidth : 0.;
        // 1. Single line
        // 2. Multi-line with soft wrap disabled.
        if (state.isSingleLine() || !state.softWrap) {
            // The longest line by byte length is only a candidate: a shorter
            // line can render wider (wide glyphs, proportional fonts). The
            // visible lines have already been shaped, so keep their widest
            // measured width as a lower bound. Caching it with the candidate
            // keeps the scroll extent stable while scrolling the line away.
            // Empty inputs lay out the placeholder, which is not scrollable content.
            final widestLaidOutLine:Float = if (isEmpty) {
                0.;
            }
            else {
                var widest:Float = 0.;
                for (line in lines) {
                    if (line.longestWidth > widest)
                        widest = line.longestWidth;
                }
                widest;
            };

            final longestRow = state.displayMap.longestRow();
            final longestLine = state.text.sliceLine(longestRow);
            final key = new LongestLineKey(state.documentRevision, longestRow, longestLine.len(), style.font(), textSize, wrapWidth,
                state.mode.tabSize().tabSize);
            final cached = state.longestLineWidth;
            state.longestLineWidth = null;
            longestLineWidth = if (cached != null && cached.key.equals(key)) {
                MathUtil.max(cached.width, widestLaidOutLine);
            }
            else {
                final longestLine = longestLine.toString();
                final tabStop = TabStops.tabStopWidth(window.textSystem(), key.font, textSize, key.tabSize);
                final shaped = window.textSystem().shapeLine(longestLine, textSize,
                    [new TextRun(Utf8.byteLength(longestLine), key.font, black(), null, null, null)], wrapWidth);
                MathUtil.max(TabStops.expandedWidth(shaped.layout, longestLine, tabStop), widestLaidOutLine);
            };
            state.longestLineWidth = new LongestLineWidth(key, longestLineWidth);
        }
        if (state.tokensVisible()) {
            longestLineWidth = if (wrapWidth != null) {
                wrapWidth;
            }
            else {
                state.tokenLayoutCache != null ? state.tokenLayoutCache.unwrappedWidth : 0.;
            };
        }
        lastLayout.lines = lines;

        final totalWrappedLines = state.displayMap.wrapRowCount();

        // gpui-kit's code editor adds empty rows and inline completion ghost
        // lines past the last content row; inputs and textareas have none.
        var scrollSize = new Size(if (longestLineWidth + RIGHT_MARGIN > bounds.size.width) {
            longestLineWidth + RIGHT_MARGIN;
        }
        else {
            longestLineWidth;
        }, MathUtil.max(totalWrappedLines * lineHeight, bounds.size.height));

        // TODO: should be add some gap to right, to convenient to focus on boundary position
        if (lastLayout.textAlign == Right || lastLayout.textAlign == Center) {
            scrollSize = new Size(longestLineWidth, scrollSize.height);
        }

        // `positionForIndex` for example
        //
        // #### text
        //
        // Hello 世界，this is GPUI component.
        // The GPUI Component is a collection of UI components for
        // GPUI framework, including Button, Input, Checkbox, Radio,
        // Dropdown, Tab, and more...
        //
        // wrap_width: 444px, line_height: 20px
        //
        // #### lines[0]
        //
        // | index | pos              | line |
        // |-------|------------------|------|
        // | 5     | (37 px, 0.0)     | 0    |
        // | 38    | (261.7 px, 20.0) | 0    |
        // | 40    | None             | -    |
        //
        // #### lines[1]
        //
        // | index | position              | line |
        // |-------|-----------------------|------|
        // | 5     | (43.578125 px, 0.0)   | 0    |
        // | 56    | (422.21094 px, 0.0)   | 0    |
        // | 57    | (11.6328125 px, 20.0) | 1    |
        // | 114   | (429.85938 px, 20.0)  | 1    |
        // | 115   | (11.3125 px, 40.0)    | 2    |

        // Calculate the scroll offset to keep the cursor in view

        final inputBounds = bounds;
        // Resolved content and viewport sizes can change during a gesture.
        // A non-scrolling input must not retain a drag that will no longer
        // receive its Ended packet through the overscroll path.
        if (scrollSize.height <= inputBounds.size.height) {
            this.state.update(cx, (state, _) -> state.overscroll.reset());
            stretch = 0.;
        }
        // Keep viewport geometry for scrollbars and hitboxes fixed; only
        // text, its carets and selections are displaced.
        bounds = new Bounds(new Point(bounds.origin.x, bounds.origin.y + stretch), bounds.size);

        final cursorLayout = layoutCursors(lastLayout, bounds, scrollSize, window, cx);
        bounds = cursorLayout.bounds;
        final cursorInfos = cursorLayout.cursorInfos;
        final cursorScrollOffset = cursorLayout.scrollOffset;
        final currentRow = cursorLayout.currentRow;
        final resizeRevealOwned = cursorLayout.resizeRevealOwned;
        // Completion/code-action menus position at the active caret.
        lastLayout.cursorBounds = null;
        for (info in cursorInfos) {
            if (info.isActive) {
                lastLayout.cursorBounds = info.bounds;
                break;
            }
        }

        // Stash the fresh caret geometry for caret-anchored popups. Their
        // deferred prepaint runs after this prepaint but before paint, so
        // they anchor to the current frame's caret instead of the previous
        // frame's. Only the positioning geometry is stashed here; the rest
        // of the paint-time state updates stay where they are.
        final caretGeometry = if (lastLayout.cursorBounds != null) {
            // Mirror updateScrollOffset's clamping with the fresh values,
            // so the stash matches what paint will publish.
            final state = this.state.read(cx);
            final safeYStart = MathUtil.min(-scrollSize.height + inputBounds.size.height, 0.);
            final scrollY = state.isSingleLine() ? 0. : MathUtil.clamp(cursorScrollOffset.y, safeYStart, 0.);
            final scrollX = clampHorizontalScrollOffset(cursorScrollOffset.x, scrollSize.width, inputBounds.size.width, lastLayout.textAlign);
            final geometry = new PrepaintCaretGeometry(lastLayout.cursorBounds, lineHeight, inputBounds, new Point(scrollX, scrollY));
            geometry.resizeRevealOwned = resizeRevealOwned;
            geometry;
        }
        else {
            null;
        };
        this.state.update(cx, (state, _) -> {
            state.prepaintCaretGeometry = caretGeometry;
        });

        final searchMatchPaths = layoutSearchMatches(lastLayout, bounds, cx);
        final selectionPaths = layoutSelections(lastLayout, bounds, window, cx);

        state = this.state.read(cx);
        state.editorScrollbarSnapshot = EditorScrollbarSnapshot.create(inputBounds, lastLayout, scrollSize, cursorScrollOffset, state);
        final hitbox = window.insertHitbox(inputBounds, Normal);
        requestReveal(inputBounds, cursorInfos, cursorScrollOffset, lineHeight, window, cx);

        final tokenElements = prepaintTokens(lastLayout, bounds, tokenElements, window, cx);
        prepaintState = new TextElementPrepaintState(lastLayout, tokenElements, scrollSize, cursorInfos, cursorScrollOffset, currentRow, selectionPaths,
            searchMatchPaths, hitbox, bounds);
    }

    static inline function sameWidth(a:Null<Float>, b:Null<Float>):Bool {
        return a == null ? b == null : (b != null && (a : Float) == (b : Float));
    }

    public function paint(id:Null<GlobalElementId>, inputBounds:Bounds, window:Window, cx:App):Void {
        final prepaint = prepaintState;
        prepaintState = null;
        if (prepaint == null)
            return;

        final state = this.state.read(cx);
        final focusHandle = state.focusHandle;
        final showCursor = state.showCursor(window, cx);
        final disabled = state.disabled;
        final selectedRange = state.activeSelection().copy();
        final editorStyle = state.editorStyle;

        final focused = focusHandle.isFocused(window);
        final bounds = prepaint.bounds;
        final textAlign = prepaint.lastLayout.textAlign;

        window.handleInput(focusHandle, new ElementInputHandler(bounds, this.state), cx);

        // Paint multi line text
        final lineHeight:Float = window.lineHeight();
        final origin = bounds.origin;

        final invisibleTopPadding:Float = prepaint.lastLayout.visibleTop;

        // Keep scrollbar offset always be positive, Start from the left position
        final scrollOffset:Float = if (textAlign == Right) {
            MathUtil.max(prepaint.scrollSize.width - prepaint.bounds.size.width, 0.);
        }
        else if (textAlign == Center) {
            MathUtil.max((prepaint.scrollSize.width - prepaint.bounds.size.width) / 2., 0.);
        }
        else {
            0.;
        };

        final lineCount = prepaint.lastLayout.lines.length < prepaint.lastLayout.visibleBufferLines.length ? prepaint.lastLayout.lines.length : prepaint.lastLayout.visibleBufferLines.length;

        // Paint glyph backgrounds
        //
        // gpui's `paint` only draws glyphs, underlines, and strikethroughs, so decoration
        // backgrounds need their own pass. It runs ahead of the indent guides, selections,
        // and text so a highlighted range sits under them instead of covering them.
        var offsetY:Float = invisibleTopPadding;
        for (li in 0...lineCount) {
            final line = prepaint.lastLayout.lines[li];
            final p = new Point(origin.x + scrollOffset, origin.y + offsetY);

            line.paintBackgroundAligned(p, lineHeight, textAlign, prepaint.lastLayout.contentWidth, window, cx);

            offsetY += line.size(lineHeight).height;
        }

        // Paint selections
        if (window.isWindowActive()) {
            final selection = editorStyle.selection;
            final secondarySelection = new Hsla(selection.h, 0.1, selection.l, selection.a);
            for (entry in prepaint.searchMatchPaths) {
                window.paintPath(entry.path, secondarySelection);

                if (entry.isActive) {
                    window.paintPath(entry.path, editorStyle.selection);
                }
            }

            for (path in prepaint.selectionPaths) {
                window.paintPath(path, editorStyle.selection);
            }
            prepaint.selectionPaths = [];
        }

        // Paint text
        var offsetY:Float = invisibleTopPadding;
        for (li in 0...lineCount) {
            final line = prepaint.lastLayout.lines[li];
            final lineY = origin.y + offsetY;
            final p = new Point(origin.x + scrollOffset, lineY);

            // Paint the actual line
            line.paintAligned(p, lineHeight, textAlign, prepaint.lastLayout.contentWidth, window, cx);
            offsetY += line.size(lineHeight).height;
        }

        for (element in prepaint.tokenElements) {
            element.paint(window, cx);
        }

        // Paint blinking cursors (shared blink state for all carets)
        if (focused && showCursor) {
            for (cursorInfo in prepaint.cursorInfosWithScroll()) {
                window.paintQuad(fill(snapCaretToDevicePixels(cursorInfo.bounds, window.scaleFactor()), editorStyle.caret));
            }
        }

        this.state.update(cx, (state, cx) -> {
            final geometryChanged = state.lastBounds == null
                || !state.lastBounds.equals(bounds)
                || !state.inputBounds.equals(inputBounds)
                || !state.scrollSize.equals(prepaint.scrollSize)
                || state.lastLayout == null
                || !sameBounds(state.lastLayout.cursorBounds, prepaint.lastLayout.cursorBounds)
                || (state.lastLayout.lineHeight : Float) != (prepaint.lastLayout.lineHeight : Float);
            // Deviation DEV-016: when the input only moved (a scrolled page),
            // its own render reads nothing that changed, and the caret,
            // selection and IME bounds follow from this paint and prepaint.
            // (gpui-kit's code editor also keeps the notify while its hover or
            // diagnostic popover is shown; Glaze's code editor is Cityscape.)
            final movedOnly = geometryChanged
                && onlyMoved(state, bounds, inputBounds, prepaint);
            state.lastLayout = prepaint.lastLayout.clone();
            state.lastBounds = bounds;
            state.lastCursor = state.cursor();
            state.setInputBounds(inputBounds, cx);
            state.lastSelectedRange = selectedRange;
            state.scrollSize = prepaint.scrollSize;
            state.updateScrollOffset(prepaint.cursorScrollOffset, cx);
            state.deferredScrollOffset = null;

            // Layout consumers need changed geometry, not another notification
            // for every paint of an unchanged input.
            if (geometryChanged && !movedOnly) {
                cx.notify();
            }
        });

        paintMouseListeners(prepaint.hitbox, window, cx);
    }

    /**
     * Deviation DEV-016: whether the geometry painted last time and the new
     * one differ only by their place in the window: same sizes, same scroll
     * size and line height, and the text bounds and the caret at the same
     * offset (within 0.01 px of float rounding) from the input bounds.
     */
    static function onlyMoved(state:InputBaseState, bounds:Bounds, inputBounds:Bounds, prepaint:TextElementPrepaintState):Bool {
        final oldBounds = state.lastBounds;
        final oldLayout = state.lastLayout;
        if (oldBounds == null || oldLayout == null) {
            return false;
        }
        final oldInput = state.inputBounds;
        final newLayout = prepaint.lastLayout;
        if (!oldBounds.size.equals(bounds.size)
            || !oldInput.size.equals(inputBounds.size)
            || !state.scrollSize.equals(prepaint.scrollSize)
            || (oldLayout.lineHeight : Float) != (newLayout.lineHeight : Float)
            || !sameOffset(oldBounds.origin.x - oldInput.origin.x, oldBounds.origin.y - oldInput.origin.y,
                bounds.origin.x - inputBounds.origin.x, bounds.origin.y - inputBounds.origin.y)) {
            return false;
        }
        final oldCursor = oldLayout.cursorBounds;
        final newCursor = newLayout.cursorBounds;
        if (oldCursor == null || newCursor == null) {
            return oldCursor == null && newCursor == null;
        }
        return oldCursor.size.equals(newCursor.size)
            && sameOffset(oldCursor.origin.x - oldInput.origin.x, oldCursor.origin.y - oldInput.origin.y,
                newCursor.origin.x - inputBounds.origin.x, newCursor.origin.y - inputBounds.origin.y);
    }

    static inline function sameOffset(ax:Float, ay:Float, bx:Float, by:Float):Bool {
        return Math.abs(ax - bx) < 0.01 && Math.abs(ay - by) < 0.01;
    }

    static inline function sameBounds(a:Null<Bounds>, b:Null<Bounds>):Bool {
        return a == null ? b == null : (b != null && a.equals(b));
    }

}

/** Layout data for a single caret, produced by `TextElement.layoutCursors`. */
class CursorRenderInfo {

    public var bounds:Bounds;

    public final isActive:Bool;

    public inline function new(bounds:Bounds, isActive:Bool) {
        this.bounds = bounds;
        this.isActive = isActive;
    }

}

/**
 * The result of `TextElement.layoutCursors` (Rust returns a tuple and moves
 * the `&mut Bounds` it was given: `bounds` is that moved value).
 */
class CursorsLayout {

    public final cursorInfos:Array<CursorRenderInfo>;

    public final scrollOffset:Point;

    public final currentRow:Null<Int>;

    public final resizeRevealOwned:Bool;

    public final bounds:Bounds;

    public inline function new(cursorInfos:Array<CursorRenderInfo>, scrollOffset:Point, currentRow:Null<Int>, resizeRevealOwned:Bool, bounds:Bounds) {
        this.cursorInfos = cursorInfos;
        this.scrollOffset = scrollOffset;
        this.currentRow = currentRow;
        this.resizeRevealOwned = resizeRevealOwned;
        this.bounds = bounds;
    }

}

/** A search match path and whether it is the current match (Rust tuple `(Path<Pixels>, bool)`). */
class MatchPath {

    public final path:Path;

    public final isActive:Bool;

    public inline function new(path:Path, isActive:Bool) {
        this.path = path;
        this.isActive = isActive;
    }

}

/** The result of `TextElement.calculateVisibleRange` (Rust tuple). */
class VisibleLines {

    public final range:Range;

    public final bufferLines:Array<Int>;

    public final top:Float;

    public inline function new(range:Range, bufferLines:Array<Int>, top:Float) {
        this.range = range;
        this.bufferLines = bufferLines;
        this.top = top;
    }

}

/** A placeholder line and its runs (Rust tuple `(&str, Vec<TextRun>)`). */
class PlaceholderLine {

    public final line:String;

    public final runs:Array<TextRun>;

    public inline function new(line:String, runs:Array<TextRun>) {
        this.line = line;
        this.runs = runs;
    }

}

/** A measured token element (Rust tuple `(AnyElement, Size<Pixels>)`). */
class MeasuredToken {

    public final element:AnyElement;

    public final size:Size;

    public inline function new(element:AnyElement, size:Size) {
        this.element = element;
        this.size = size;
    }

}

private class TokenPlacement {

    public final token:InlineTokenContext;

    public final origin:Point;

    public inline function new(token:InlineTokenContext, origin:Point) {
        this.token = token;
        this.origin = origin;
    }

}

/** Rust `PrepaintState` of `TextElement`. */
class TextElementPrepaintState {

    /** The lines of entire lines. */
    public final lastLayout:LastLayout;

    public final tokenElements:Array<AnyElement>;

    /** Size of the scrollable area by entire lines. */
    public final scrollSize:Size;

    /** Caret bounds for every selection, active flagged. */
    public final cursorInfos:Array<CursorRenderInfo>;

    public final cursorScrollOffset:Point;

    /** row index (zero based), no wrap, same line as the cursor. */
    public final currentRow:Null<Int>;

    public var selectionPaths:Array<Path>;

    public final searchMatchPaths:Array<MatchPath>;

    /** The whole input, for deciding whether a long press started in it. */
    public final hitbox:Hitbox;

    public final bounds:Bounds;

    public function new(lastLayout:LastLayout, tokenElements:Array<AnyElement>, scrollSize:Size, cursorInfos:Array<CursorRenderInfo>,
            cursorScrollOffset:Point, currentRow:Null<Int>, selectionPaths:Array<Path>, searchMatchPaths:Array<MatchPath>, hitbox:Hitbox, bounds:Bounds) {
        this.lastLayout = lastLayout;
        this.tokenElements = tokenElements;
        this.scrollSize = scrollSize;
        this.cursorInfos = cursorInfos;
        this.cursorScrollOffset = cursorScrollOffset;
        this.currentRow = currentRow;
        this.selectionPaths = selectionPaths;
        this.searchMatchPaths = searchMatchPaths;
        this.hitbox = hitbox;
        this.bounds = bounds;
    }

    /** Returns all cursor infos adjusted for scroll offset. */
    public function cursorInfosWithScroll():Array<CursorRenderInfo> {
        return [
            for (info in cursorInfos)
                new CursorRenderInfo(new Bounds(new Point(info.bounds.origin.x, info.bounds.origin.y + cursorScrollOffset.y), info.bounds.size), info.isActive)
        ];
    }

}

/** Claims the wheel of text with room to scroll (`TextElement.paintMouseListeners`) */
private class TextScrollEntry extends glaze.Window.MouseListenerEntry {

    final state:Entity<InputBaseState>;

    final hitboxId:Int;

    public function new(state:Entity<InputBaseState>, hitboxId:Int) {
        super(Scroll, null, null, null);
        this.state = state;
        this.hitboxId = hitboxId;
    }

    override function call(event:glaze.PlatformInput, phase:glaze.DispatchPhase, window:Window, cx:App):Void {
        final event:ScrollEvent = cast event;
        if (phase == Capture && window.shouldHitboxIdHandleScroll(hitboxId)
            && state.read(cx).takesScroll(event.delta.pixelDelta(window.lineHeight()))) {
            ScrollBounce.claimScroll(hitboxId, cx);
        }
    }

}

/** Notes touches (`TextElement.paintMouseListeners`) */
private class TextTouchDragEntry extends glaze.Window.MouseListenerEntry {

    public function new() {
        super(TouchDrag, null, null, null);
    }

    override function call(event:glaze.PlatformInput, phase:glaze.DispatchPhase, window:Window, cx:App):Void {
        final event:TouchDragEvent = cast event;
        if (phase.capture() && event.phase == Started) {
            GlobalState.noteTouch(cx);
        }
    }

}

/** Long press selection (`TextElement.paintMouseListeners`) */
private class TextLongPressEntry extends glaze.Window.MouseListenerEntry {

    final state:Entity<InputBaseState>;

    final textHitbox:Hitbox;

    public function new(state:Entity<InputBaseState>, textHitbox:Hitbox) {
        super(LongPress, null, null, null);
        this.state = state;
        this.textHitbox = textHitbox;
    }

    override function call(event:glaze.PlatformInput, phase:glaze.DispatchPhase, window:Window, cx:App):Void {
        final event:LongPressEvent = cast event;
        if (!phase.bubble()) {
            return;
        }
        if (event.phase == Started) {
            if (window.defaultPrevented() || !textHitbox.isHovered(window)) {
                return;
            }
            if (!state.update(cx, (state, cx) -> state.onLongPress(event, window, cx))) {
                return;
            }
            window.captureLongPress(state);
        }
        else if (!window.hasLongPressCapture(state)) {
            return;
        }
        else {
            state.update(cx, (state, cx) -> {
                state.onLongPress(event, window, cx);
            });
        }
        window.preventDefault();
        cx.stopPropagation();
    }

}

/** Drag selection moves (`TextElement.paintMouseListeners`) */
private class TextMouseMoveEntry extends glaze.Window.MouseListenerEntry {

    final state:Entity<InputBaseState>;

    public function new(state:Entity<InputBaseState>) {
        super(MouseMove, null, null, null);
        this.state = state;
    }

    override function call(event:glaze.PlatformInput, phase:glaze.DispatchPhase, window:Window, cx:App):Void {
        final event:MouseMoveEvent = cast event;
        if (event.pressedButton == Left) {
            state.update(cx, (state, cx) -> {
                state.onDragMove(event, window, cx);
            });
        }
    }

}

/** Ends the drag selection (`TextElement.paintMouseListeners`) */
private class TextMouseUpEntry extends glaze.Window.MouseListenerEntry {

    final state:Entity<InputBaseState>;

    public function new(state:Entity<InputBaseState>) {
        super(MouseUp, null, null, null);
        this.state = state;
    }

    override function call(event:glaze.PlatformInput, phase:glaze.DispatchPhase, window:Window, cx:App):Void {
        if (phase != Bubble) {
            return;
        }

        // Stop auto-scroll when mouse up, and also stop selecting.
        state.update(cx, (state, _) -> {
            state.autoScroll.stop();
            state.selecting = false;
            state.columnSelectStart = null;
        });
    }

}

/** A rectangle as its (top left, bottom right) points. */
private class FrameRect {

    public final a:Point;

    public final b:Point;

    public inline function new(a:Point, b:Point) {
        this.a = a;
        this.b = b;
    }

}
