// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/inline_line.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.App;
import glaze.Point;
import glaze.Range;
import glaze.ShapedLine;
import glaze.TextAlign;
import glaze.Window;
import glaze.util.Utf8;

/**
 * A piece of an inline row: shaped text, or an inline element (`text` null)
 * occupying `width` over its byte range.
 */
class InlineFragment {

    public final range:Range;

    public final x:Float;

    public final width:Float;

    public final text:Null<ShapedLine>;

    public inline function new(range:Range, x:Float, width:Float, text:Null<ShapedLine>) {
        this.range = range;
        this.x = x;
        this.width = width;
        this.text = text;
    }

}

/**
 * A visual row whose offsets remain in source UTF-8 bytes.
 *
 * Rust's `Content` enum is the pair `shaped` (`Content::Text`) and
 * `fragments` (`Content::Inline`): exactly one of them is set.
 */
class InputLine {

    public final len:Int;

    public final width:Float;

    public final text:String;

    /** `Content::Text`: the ordinary shaped row */
    final shaped:Null<ShapedLine>;

    /** `Content::Inline`: token rows */
    final fragments:Null<Array<InlineFragment>>;

    function new(len:Int, width:Float, text:String, shaped:Null<ShapedLine>, fragments:Null<Array<InlineFragment>>) {
        this.len = len;
        this.width = width;
        this.text = text;
        this.shaped = shaped;
        this.fragments = fragments;
    }

    /** Rust `From<ShapedLine>` */
    public static function fromShapedLine(line:ShapedLine):InputLine {
        return new InputLine(line.len(), line.width(), line.text, line, null);
    }

    /** Rust `InputLine::inline` (renamed: `inline` is a Haxe keyword) */
    public static function inlineLine(text:String, fragments:Array<InlineFragment>):InputLine {
        final width = fragments.length == 0 ? 0.0 : fragments[fragments.length - 1].x + fragments[fragments.length - 1].width;
        return new InputLine(Utf8.byteLength(text), width, text, null, fragments);
    }

    public function xForIndex(ix:Int):Float {
        if (shaped != null)
            return shaped.xForIndex(ix);
        for (f in fragments) {
            if (ix < f.range.end) {
                return f.x + (f.text == null ? (ix <= f.range.start ? 0.0 : f.width) : f.text.xForIndex(ix > f.range.start ? ix - f.range.start : 0));
            }
        }
        return width;
    }

    public function closestIndexForX(x:Float):Int {
        if (shaped != null)
            return shaped.closestIndexForX(x);
        for (f in fragments) {
            if (x <= f.x + f.width) {
                if (f.text == null)
                    return x - f.x < f.width / 2.0 ? f.range.start : f.range.end;
                return f.range.start + f.text.closestIndexForX(x - f.x);
            }
        }
        return len;
    }

    public function indexForX(x:Float):Null<Int> {
        if (shaped != null)
            return shaped.indexForX(x);
        return (x >= 0.0 && x <= width) ? closestIndexForX(x) : null;
    }

    public function paint(pos:Point, height:Float, align:TextAlign, width:Null<Float>, window:Window, cx:App):Void {
        paintPass(pos, height, align, width, false, window, cx);
    }

    public function paintBackground(pos:Point, height:Float, align:TextAlign, width:Null<Float>, window:Window, cx:App):Void {
        paintPass(pos, height, align, width, true, window, cx);
    }

    /** `paint` with a width that is known (a `Null<Float>` argument is boxed on hxcpp) */
    public function paintAligned(pos:Point, height:Float, align:TextAlign, width:Float, window:Window, cx:App):Void {
        paintPassAligned(pos, height, align, width, false, window, cx);
    }

    /** `paintBackground` with a width that is known */
    public function paintBackgroundAligned(pos:Point, height:Float, align:TextAlign, width:Float, window:Window, cx:App):Void {
        paintPassAligned(pos, height, align, width, true, window, cx);
    }

    /** `paintPass` with a width that is known: the same painting */
    function paintPassAligned(pos:Point, height:Float, align:TextAlign, width:Float, background:Bool, window:Window, cx:App):Void {
        final painter = window.textPainter();
        if (shaped != null) {
            if (background)
                shaped.paintBackgroundAligned(pos, height, align, width, painter);
            else
                shaped.paintAligned(pos, height, align, width, painter);
            return;
        }
        final full = width;
        final remaining = full - this.width > 0.0 ? full - this.width : 0.0;
        final offset = switch align {
            case Right: remaining;
            case Center: remaining / 2.0;
            case _: 0.0;
        }
        for (f in fragments) {
            if (f.text != null) {
                if (background)
                    f.text.paintBackground(new Point(pos.x + offset + f.x, pos.y), height, TextAlign.Left, null, painter);
                else
                    f.text.paint(new Point(pos.x + offset + f.x, pos.y), height, TextAlign.Left, null, painter);
            }
        }
    }

    function paintPass(pos:Point, height:Float, align:TextAlign, width:Null<Float>, background:Bool, window:Window, cx:App):Void {
        final painter = window.textPainter();
        inline function paint(line:ShapedLine, pos:Point, align:TextAlign, width:Null<Float>) {
            if (background)
                line.paintBackground(pos, height, align, width, painter);
            else
                line.paint(pos, height, align, width, painter);
        }
        if (shaped != null) {
            paint(shaped, pos, align, width);
            return;
        }
        final full = width != null ? width : this.width;
        final remaining = full - this.width > 0.0 ? full - this.width : 0.0;
        final offset = switch align {
            case Right: remaining;
            case Center: remaining / 2.0;
            case _: 0.0;
        }
        for (f in fragments) {
            if (f.text != null)
                paint(f.text, new Point(pos.x + offset + f.x, pos.y), TextAlign.Left, null);
        }
    }

}
