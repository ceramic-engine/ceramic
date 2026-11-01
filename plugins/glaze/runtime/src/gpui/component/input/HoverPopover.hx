// Ported from gpui-kit 0.8.1: crates/component/src/input/popovers/hover_popover.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.input;

import gpui.AnyElement;
import gpui.App;
import gpui.AvailableSpace;
import gpui.Bounds;
import gpui.Context;
import gpui.Element;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Entity;
import gpui.GlobalElementId;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.Model;
import gpui.MouseDownEvent;
import gpui.MouseMoveEvent;
import gpui.Pixels;
import gpui.Point;
import gpui.Range;
import gpui.Render;
import gpui.Size;
import gpui.SizeOf;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.Popup;
import gpui.base.input.EditorState;
import gpui.base.input.LspHover;

import gpui.Prelude.*;

using gpui.base.input.InputLspExt;
using gpui.component.ThemeStyled;
using gpui.base.StyledExt;

/**
 * The hover popover of the code editor: the provider's hover content,
 * anchored to the symbol it describes.
 */
class HoverPopover extends Model implements Render {

    final editor:Entity<EditorState>;

    /** The symbol range byte of the hover trigger. */
    @:allow(gpui.component.input, tests)
    final symbolRange:Range;

    @:allow(gpui.component.input, tests)
    final hover:LspHover;

    public static function create(editor:Entity<EditorState>, symbolRange:Range, hover:LspHover, cx:App):Entity<HoverPopover> {
        return cx.newEntity((_:Context<HoverPopover>) -> new HoverPopover(editor, symbolRange, hover));
    }

    function new(editor:Entity<EditorState>, symbolRange:Range, hover:LspHover) {
        super();
        this.editor = editor;
        this.symbolRange = symbolRange;
        this.hover = hover;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        // Rust flattens `lsp_types::HoverContents` here (scalar, array joined
        // with blank lines, markup): `LspHover.contents` holds that text.
        final contents = hover.contents;

        return new Popover("hover-popover", editor, symbolRange, (window, cx) -> Popovers.renderMarkdown("message", contents, window, cx));
    }

}

/**
 * A popover anchored to a byte range of the editor, above it when it fits
 * (Rust `Popover` of `hover_popover.rs`).
 */
class Popover extends Element implements Styled {

    static inline final SNAP_TO_EDGE:Float = 8.;

    final id:ElementId;

    final popoverStyle:StyleRefinement = new StyleRefinement();

    final editor:Entity<EditorState>;

    final range:Range;

    final widthLimit:Range;

    final contentBuilder:(Window, App) -> IntoElement;

    // Rust `PopoverLayoutState`
    var layoutBounds:Bounds = new Bounds(new Point(0, 0), new Size(0, 0));

    var popoverElement:Null<AnyElement> = null;

    public function new(id:ElementIdArg, editor:Entity<EditorState>, range:Range, f:(Window, App) -> IntoElement) {
        this.id = id;
        this.editor = editor;
        this.range = range;
        this.widthLimit = new Range(200, 500);
        this.contentBuilder = f;
    }

    public inline function style():StyleRefinement {
        return popoverStyle;
    }

    /** Get the bounds of the range in the editor, if it is visible. */
    function triggerBounds(cx:App):Null<Bounds> {
        final editor = this.editor.read(cx);
        return editor.rangeToBounds(range);
    }

    override public function elementId():Null<ElementId> {
        return id;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final triggerBounds = this.triggerBounds(cx);
        if (triggerBounds == null) {
            layoutBounds = new Bounds(new Point(0, 0), new Size(0, 0));
            popoverElement = null;
            return gpui.Prelude.div().intoAnyElement().requestLayout(window, cx);
        }

        final maxWidth:Float = Math.max(Math.min((widthLimit.end : Float), window.viewportSize().width - SNAP_TO_EDGE * 2), 200.);
        final maxHeight:Float = Math.min(window.viewportSize().height - SNAP_TO_EDGE * 2, 320.);

        final popover = gpui.Prelude.deferred(gpui.Prelude.div()
            .id("hover-popover-content")
            .flexNone()
            .occlude()
            .p1()
            .textXs()
            .popoverStyle(cx)
            .shadowMd()
            .maxW(gpui.Prelude.px(maxWidth))
            .maxH(gpui.Prelude.px(maxHeight))
            .overflowYScroll()
            .refineStyle(popoverStyle)
            .child(contentBuilder(window, cx)))
            .withPriority(Popup.POPUP_PRIORITY)
            .intoAnyElement();

        final popoverSize = popover.layoutAsRoot(new SizeOf<AvailableSpace>(MinContent, MinContent), window, cx);
        final topSpace:Float = triggerBounds.top() - SNAP_TO_EDGE;
        final rightSpace:Float = window.viewportSize().width - triggerBounds.left() - SNAP_TO_EDGE;

        var posX:Float = triggerBounds.left();
        var posY:Float = triggerBounds.top() - popoverSize.height;
        if (popoverSize.height > topSpace) {
            posY = triggerBounds.bottom();
        }
        if (popoverSize.width > rightSpace) {
            posX = triggerBounds.right() - popoverSize.width;
        }

        final empty = gpui.Prelude.div().intoAnyElement();
        final layoutId = empty.requestLayout(window, cx);
        layoutBounds = new Bounds(new Point(posX, posY), popoverSize);
        popoverElement = popover;
        return layoutId;
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final bounds = layoutBounds;
        final popover = popoverElement;
        if (popover == null)
            return;

        window.withAbsoluteElementOffset(bounds.origin, window -> {
            popover.prepaint(window, cx);
            return null;
        });
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final bounds = layoutBounds;
        final popover = popoverElement;
        if (popover == null)
            return;

        popover.paint(window, cx);

        final editor = this.editor;
        // Mouse down out to hide.
        window.onMouseEvent(MouseDown, (event, _, _, cx) -> {
            final event:MouseDownEvent = cast event;
            if (!bounds.contains(event.position)) {
                editor.update(cx, (editor, cx) -> InputLspExt.clearHoverState(editor, cast cx));
            }
        });

        // Mouse out of trigger + popover bounds
        final triggerBounds = this.triggerBounds(cx);
        final keepOpenRegion = (triggerBounds != null ? triggerBounds : bounds).union(bounds);
        window.onMouseEvent(MouseMove, (event, _, _, cx) -> {
            final event:MouseMoveEvent = cast event;
            if (!keepOpenRegion.contains(event.position)) {
                editor.update(cx, (editor, cx) -> InputLspExt.clearHoverState(editor, cast cx));
            }
        });
    }

}
