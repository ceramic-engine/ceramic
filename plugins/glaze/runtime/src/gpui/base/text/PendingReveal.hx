// Ported from gpui-kit 0.8.1: crates/base/src/text/range_highlight.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Bounds;
import gpui.Range;
import gpui.base.text.RenderedIndex.RevealTarget;

/**
 * Where the line a reveal starts on was laid out in one frame, in window
 * coordinates, and whether it was inside the visible area.
 */
class RevealReport {
    public final line:Bounds;
    public final visible:Bool;

    public inline function new(line:Bounds, visible:Bool) {
        this.line = line;
        this.visible = visible;
    }
}

/** Rust `Arc<Mutex<Option<RevealReport>>>`. */
class RevealReportCell {
    public var value:Null<RevealReport> = null;

    public function new() {}
}

/** How a pending reveal went in one frame. */
enum RevealProgress {
    /** The line is visible, so the reveal is done. */
    Shown;
    /** The line was laid out at these window bounds without being visible. */
    Hidden(line:Bounds);
    /** The line was not laid out. */
    NotLaidOut;
}

/**
 * A range `TextViewState.revealRange` is scrolling into view.
 *
 * The `Inline` that lays out the start of the range asks the enclosing list
 * to scroll its line into view during prepaint, and reports where the line
 * ended up. The view reads the report once painted, after any list has
 * scrolled, and is done once the line is visible.
 *
 * Instants are seconds of the app's clock.
 */
class PendingReveal {

    /**
     * How long a reveal keeps trying, in seconds. One that has not been
     * carried out by then is dropped.
     */
    static inline final REVEAL_TIMEOUT:Float = 1.0;

    /**
     * How many frames a reveal whose line was laid out but not visible keeps
     * trying, e.g. while an enclosing container scrolls to it.
     */
    static inline final REVEAL_ATTEMPTS:Int = 8;

    var target:RevealTarget;
    final requestedAt:Float;
    /** What the target's `Inline` reported this frame; `null` when it was not laid out. */
    final report:RevealReportCell;
    var attempts:Int;

    function new(target:RevealTarget, requestedAt:Float) {
        this.target = target;
        this.requestedAt = requestedAt;
        this.report = new RevealReportCell();
        this.attempts = 0;
    }

    /**
     * The start of `range` in `text`, asked for at `now`, or `null` when
     * the range is not a range of it.
     */
    @:allow(gpui.base.text)
    static function create(text:RenderedText, range:Range, now:Float):Null<PendingReveal> {
        final target = text.index().locate(range);
        return target != null ? new PendingReveal(target, now) : null;
    }

    public function isExpired(now:Float):Bool {
        final elapsed = now - requestedAt;
        return (elapsed > 0 ? elapsed : 0) > REVEAL_TIMEOUT || attempts >= REVEAL_ATTEMPTS;
    }

    /** Whether the reveal is of a whole block rather than a line. */
    public function isBlock():Bool {
        return target.match(Block(_));
    }

    /** The index of the top-level block of `document` the reveal starts in. */
    public function blockIx(document:ParsedDocument):Null<Int> {
        return switch target {
            case Line(key, _):
                var i = document.blocks.length - 1;
                while (i >= 0) {
                    final span = document.blocks[i].span();
                    if (span != null && span.start <= key.blockStart()) break;
                    i--;
                }
                i >= 0 ? i : null;
            case Block(ix):
                ix < document.blocks.length ? ix : null;
        }
    }

    /** Whether the line was laid out in the previous frame. */
    public function wasLaidOut():Bool {
        return report.value != null;
    }

    /** Starts a frame: forgets the previous report and hands the line to rendering. A block has no line. */
    public function request():Null<RevealRequest> {
        report.value = null;
        return switch target {
            case Line(key, offset): new RevealRequest(key, offset, report);
            case Block(_): null;
        }
    }

    /**
     * Ends a frame with what the line reported, counting a frame in which it
     * was laid out but hidden as an attempt.
     */
    public function progress():RevealProgress {
        final report = this.report.value;
        if (report == null) {
            return NotLaidOut;
        }
        if (report.visible) {
            return Shown;
        }
        attempts += 1;
        return Hidden(report.line);
    }

    /** The reveal in the document `remap` maps the old one to, as long as the text it starts at is unchanged. */
    public function remap(remap:LeafRemap):Null<PendingReveal> {
        switch target {
            case Line(key, offset):
                final found = remap.leaf(key);
                if (found == null) return null;
                if (!(offset < found.unchanged)) return null;
                target = Line(found.key, offset);
                return this;
            case Block(_):
                return null;
        }
    }

}
