// Ported from gpui-kit 0.8.1: crates/base/src/input/base/tab_stops.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Font;
import glaze.LineLayout;
import glaze.Pixels;
import glaze.Point;
import glaze.ShapedGlyph;
import glaze.ShapedLine;
import glaze.ShapedRun;
import glaze.WindowTextSystem;

/**
 * Tab stops for shaped lines.
 *
 * The platform shapers do not agree on what a `\t` is: DirectWrite gives it
 * no width at all, CoreText uses its own default stops. Neither knows the
 * editor's tab size. So a line is shaped as is and its tabs are then widened
 * to the next tab stop, by moving every glyph after a tab to the right. The
 * caret, hit testing and selection all read glyph positions, so they follow.
 */
class TabStops {

    /** The distance between two tab stops: `tabSize` spaces of `font`. */
    public static function tabStopWidth(textSystem:WindowTextSystem, font:Font, fontSize:Pixels, tabSize:Int):Pixels {
        final fontId = textSystem.resolveFont(font);
        return textSystem.layoutWidth(fontId, fontSize, ' '.code) * tabSize;
    }

    /**
     * Widens each tab of `line` to end on the next multiple of `stop`.
     *
     * Stops are counted from the start of `line`, so a soft-wrapped row starts
     * its own stops, the same way the wrapper measures it.
     */
    public static function expandTabs(line:ShapedLine, stop:Pixels):Void {
        final layout = expandedLayout(line.layout, line.text, stop);
        if (layout != null) {
            line.layout = layout;
        }
    }

    /** The width of `layout` (shaped from `text`) once its tabs are expanded. */
    public static function expandedWidth(layout:LineLayout, text:String, stop:Pixels):Pixels {
        if (stop <= 0.) {
            return layout.width;
        }

        final shifts = tabShifts(layout, text, stop);
        return f32(layout.width + (shifts.length > 0 ? shifts[shifts.length - 1].shift : 0.));
    }

    /** Cumulative shifts after each tab, in text order. */
    static function tabShifts(layout:LineLayout, text:String, stop:Pixels):Array<TabShift> {
        final glyphs:Array<ShapedGlyph> = [];
        for (run in layout.runs) for (glyph in run.glyphs) glyphs.push(glyph);
        var cursor = 0;
        // Tab boundaries increase monotonically. Keep the cursor between
        // lookups instead of restarting the scan for every tab.
        inline function xForIndex(index:Int):Float {
            while (cursor < glyphs.length && glyphs[cursor].index < index) {
                cursor++;
            }
            return cursor < glyphs.length ? (glyphs[cursor].position.x:Float) : (layout.width:Float);
        }

        // Keep the cumulative shift in double precision. Rounding it to Pixels
        // after every tab can put a stop just below its boundary, making the
        // next tab land on that same stop instead of advancing.
        // Rust reads the f32 Pixels as f64 (`f64::from(f32::from(..))`) and
        // stores the shifts as f32 Pixels: `f32` reproduces both roundings.
        final stop:Float = f32(stop);
        final result:Array<TabShift> = [];
        var shift = 0.;
        // `text.match_indices('\t')`, with UTF-8 byte indices.
        var ix = 0;
        for (c in new haxe.iterators.StringIteratorUnicode(text)) {
            if (c == '\t'.code) {
                final start = f32(xForIndex(ix)) + shift;
                final end = f32(xForIndex(ix + 1));
                final nextStop = stop * (Math.floor(start / stop) + 1.);
                shift = nextStop - end;
                result.push(new TabShift(ix, f32(shift)));
            }
            ix += c < 0x80 ? 1 : (c < 0x800 ? 2 : (c < 0x10000 ? 3 : 4));
        }
        return result;
    }

    /** `layout` with its tabs widened, or null when it has none to widen. */
    @:allow(tests)
    static function expandedLayout(layout:LineLayout, text:String, stop:Pixels):Null<LineLayout> {
        if (stop <= 0. || text.indexOf('\t') == -1) {
            return null;
        }

        final shifts = tabShifts(layout, text, stop);
        final shift:Float = shifts.length > 0 ? shifts[shifts.length - 1].shift : 0.;

        inline function shiftAfter(index:Int):Float {
            // `partition_point(|&(tab, _)| tab < index)`
            var lo = 0;
            var hi = shifts.length;
            while (lo < hi) {
                final mid = (lo + hi) >> 1;
                if (shifts[mid].index < index) lo = mid + 1; else hi = mid;
            }
            return lo > 0 ? shifts[lo - 1].shift : 0.;
        }

        final runs = [for (run in layout.runs) new ShapedRun(run.fontId, [for (glyph in run.glyphs)
            new ShapedGlyph(glyph.id, new Point(f32(glyph.position.x + shiftAfter(glyph.index)), glyph.position.y), glyph.index, glyph.isEmoji)
        ])];

        return new LineLayout(layout.fontSize, f32(layout.width + shift), layout.ascent, layout.descent, runs, layout.len);
    }

    /** Rust `f32` arithmetic on Pixels. */
    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

}

/**
 * A tab and the cumulative shift after it (Rust `(usize, Pixels)`).
 */
private class TabShift {

    public final index:Int;

    public final shift:Float;

    public inline function new(index:Int, shift:Float) {
        this.index = index;
        this.shift = shift;
    }

}
