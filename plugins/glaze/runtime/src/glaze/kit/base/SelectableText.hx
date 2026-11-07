// Ported from gpui-kit 0.8.1: crates/base/src/selectable_text.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.App;
import glaze.Bounds;
import glaze.Corners;
import glaze.Edges;
import glaze.Element;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.GlobalElementId;
import glaze.HitboxBehavior;
import glaze.Hsla;
import glaze.LayoutId;
import glaze.Point;
import glaze.Range;
import glaze.StyledText;
import glaze.TextLayout;
import glaze.TextStyleRefinement;
import glaze.Window;
import glaze.kit.base.theme.Theme;

import glaze.Prelude.*;

/**
 * Retained handle of a `SelectableText` that owns its selection (element
 * state). Rust drops the handle, and its entity, with the element state.
 */
private class RetainedHandle implements glaze.Droppable {
    public final handle:TextSelectionHandle;

    public function new(handle:TextSelectionHandle) {
        this.handle = handle;
    }

    public function drop():Void {
        final state:SelectableTextState = handle.state;
        if (!state.destroyed) state.destroy();
    }
}

/**
 * Plain text that participates in the window-scoped `TextSelection`.
 *
 * Use `SelectableText.create` for an independent run, or `withHandle` when
 * several elements form one selectable document.
 *
 * Applications must render one `TextSelectionLayer` above their content and
 * call `Base.init` during startup.
 */
class SelectableText extends Element {

    final id:ElementId;
    final handle:Null<TextSelectionHandle>;
    final text:String;
    final styledText:StyledText;
    var _documentOrder:Int = 0;
    var _textStyle:Null<TextStyleRefinement> = null;
    var _selectionColor:Null<Hsla> = null;

    var layoutHandle:Null<TextSelectionHandle> = null;

    function new(id:ElementId, handle:Null<TextSelectionHandle>, text:String) {
        this.id = id;
        this.handle = handle;
        this.text = text;
        styledText = new StyledText(text);
    }

    /** Creates a run that owns its own selection (Rust `SelectableText::new`). */
    public static function create(id:ElementIdArg, text:String):SelectableText {
        return new SelectableText(id, null, text);
    }

    /** Creates a run that joins the document `handle` belongs to. */
    public static function withHandle(id:ElementIdArg, handle:TextSelectionHandle, text:String):SelectableText {
        return new SelectableText(id, handle, text);
    }

    /** Places this run in reading order among the others sharing its handle. */
    public function documentOrder(order:Int):SelectableText {
        _documentOrder = order;
        return this;
    }

    /** Sets the text style the run is laid out and painted with. */
    public function textStyle(style:TextStyleRefinement):SelectableText {
        _textStyle = style;
        return this;
    }

    /** Overrides the selection background, which defaults to the theme's `colors.selection` token. */
    public function selectionColor(color:Hsla):SelectableText {
        _selectionColor = color;
        return this;
    }

    static function paintSelection(layout:TextLayout, range:Range, color:Hsla, window:Window):Void {
        final start = layout.positionForIndex(range.start);
        final end = layout.positionForIndex(range.end);
        if (start == null || end == null) {
            return;
        }
        for (bounds in selectionQuadBounds(start, end, layout.bounds(), layout.lineHeight())) {
            window.paintQuad(quad(bounds, new Corners(), color, new Edges(), transparentBlack(), Solid));
        }
    }

    static function selectionQuadBounds(start:Point, end:Point, bounds:Bounds, lineHeight:Float):Array<Bounds> {
        inline function f32(v:Float):Float return glaze.SpringMath.f32(v);
        if (start.y == end.y) {
            return [Bounds.fromCorners(start, new Point(end.x, f32(end.y + lineHeight)))];
        }

        final quads = [Bounds.fromCorners(start, new Point(bounds.right(), f32(start.y + lineHeight)))];
        if (end.y > f32(start.y + lineHeight)) {
            quads.push(Bounds.fromCorners(new Point(bounds.left(), f32(start.y + lineHeight)), new Point(bounds.right(), end.y)));
        }
        quads.push(Bounds.fromCorners(new Point(bounds.left(), end.y), new Point(end.x, f32(end.y + lineHeight))));
        return quads;
    }

    override public function elementId():Null<ElementId> {
        return id;
    }

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        var handle = this.handle;
        if (handle == null) {
            if (globalId == null) throw 'SelectableText must have a stable element id';
            handle = window.withElementState(globalId, RetainedHandle, (retained, _) -> {
                if (retained.value == null) {
                    retained.value = new RetainedHandle(TextSelectionHandle.create(text, cx));
                }
                return retained.value.handle;
            });
        }
        layoutHandle = handle;
        if (_textStyle != null) {
            return window.withTextStyle(_textStyle, window -> styledText.requestLayout(globalId, window, cx));
        }
        return styledText.requestLayout(globalId, window, cx);
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        styledText.prepaint(globalId, bounds, window, cx);
        final hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
        final registration = new TextSelectionRegistration(hitbox, bounds)
            .withDocumentOrder(_documentOrder)
            .withTextBounds([bounds])
            .withRenderedElement(layoutHandle, window, cx);
        layoutHandle.register(registration, window, cx);
    }

    public function paint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final handle = layoutHandle;
        final layout = styledText.layout();
        final copyTextBefore = handle.projectedCopyText(cx);
        final projection = handle.updateRuns([new TextSelectionRun(text, layout, bounds).withDocumentOrder(_documentOrder)], cx);
        if (copyTextBefore != handle.projectedCopyText(cx)) {
            window.refresh();
        }
        final color = _selectionColor != null ? _selectionColor : Theme.global(cx).tokens.colors.selection;
        for (range in projection.ranges()) {
            if (range != null) {
                paintSelection(layout, range, color, window);
            }
        }
        styledText.paint(globalId, bounds, window, cx);
    }

}
