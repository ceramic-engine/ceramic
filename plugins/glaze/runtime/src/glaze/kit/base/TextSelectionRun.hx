// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.Bounds;
import gpui.TextLayout;

/**
 * Laid-out text reported by a plain selection participant during paint.
 */
class TextSelectionRun {

    /** Logical order within the containing participant. */
    @:allow(gpui.base) var _documentOrder:Int = 0;

    /** The exact text used to produce `layout`. */
    @:allow(gpui.base) final _text:String;

    /** Laid-out glyph geometry in window coordinates. */
    @:allow(gpui.base) final _layout:TextLayout;

    /** The run's window-coordinate paint bounds. */
    @:allow(gpui.base) final _bounds:Bounds;

    /** The boundary a triple-click drag snaps to in this run. */
    @:allow(gpui.base) var tripleClick:TripleClickSelection = LogicalLine;

    /** Creates a laid-out text run. */
    public function new(text:String, layout:TextLayout, bounds:Bounds) {
        _text = text;
        _layout = layout;
        _bounds = bounds;
    }

    function copy():TextSelectionRun {
        final run = new TextSelectionRun(_text, _layout, _bounds);
        run._documentOrder = _documentOrder;
        run.tripleClick = tripleClick;
        return run;
    }

    /** Sets the run's logical order within the participant. */
    public function withDocumentOrder(documentOrder:Int):TextSelectionRun {
        final run = copy();
        run._documentOrder = documentOrder;
        return run;
    }

    /**
     * Uses TextView's triple-click boundary: the whole paragraph, or the
     * laid-out row when this run is one piece of an inline flow.
     */
    @:allow(gpui.base)
    function withParagraph(row:Null<Bounds>):TextSelectionRun {
        final run = copy();
        run.tripleClick = row != null ? Row(row) : Paragraph;
        return run;
    }

    /** Returns the run's logical order within its participant. */
    public inline function documentOrder():Int {
        return _documentOrder;
    }

    /** Returns the exact text used to produce the layout. */
    public inline function text():String {
        return _text;
    }

    /** Returns the laid-out glyph geometry. */
    public inline function layout():TextLayout {
        return _layout;
    }

    /** Returns the run's window-coordinate paint bounds. */
    public inline function bounds():Bounds {
        return _bounds;
    }

}

enum TripleClickSelection {
    LogicalLine;
    Paragraph;
    Row(row:Bounds);
}
