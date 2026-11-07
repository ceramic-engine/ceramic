// Ported from gpui-kit 0.8.1: crates/base/src/input/base/element.rs (`EditorScrollbar`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.AnyElement;
import glaze.App;
import glaze.AvailableSpace;
import glaze.Bounds;
import glaze.Element;
import glaze.ElementId;
import glaze.Entity;
import glaze.GlobalElementId;
import glaze.LayoutId;
import glaze.Length;
import glaze.SizeOf;
import glaze.Style;
import glaze.Window;
import glaze.kit.base.Scrollbar;

import glaze.Prelude.*;

/**
 * The scrollbar of a multi-line input, laid over the whole input and placed
 * from the snapshot the text element left at its last prepaint.
 */
@:access(glaze.kit.base.Scrollbar)
@:access(glaze.kit.base.input.InputBaseState)
@:access(glaze.kit.base.input.EditorScrollbarContext)
class EditorScrollbar extends Element {

    final state:Entity<InputBaseState>;

    /** Rust `PrepaintState` (`Option<AnyElement>`). */
    var scrollbar:Null<AnyElement> = null;

    public function new(state:Entity<InputBaseState>) {
        this.state = state;
    }

    override public function elementId():Null<ElementId> {
        return ElementId.Name('editor-scrollbar');
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final style = new Style();
        style.position = Absolute;
        style.sizeWidth = Length.Definite(relative(1.));
        style.sizeHeight = Length.Definite(relative(1.));

        return window.requestLayout(style, [], cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        scrollbar = null;
        final state = this.state.read(cx);
        final snapshot = state.editorScrollbarSnapshot;
        if (snapshot == null) {
            return;
        }
        final scrollHandle = state.scrollHandle;

        if (!scrollHandle.offset().equals(snapshot.cursorScrollOffset)) {
            scrollHandle.setOffset(snapshot.cursorScrollOffset);
        }

        final renderer = state.scrollbarRenderer;
        final scrollbar:AnyElement = if (renderer != null) {
            final presentation = new EditorScrollbarContext(scrollHandle, snapshot.layout.bounds, snapshot.layout.scrollViewportSize, snapshot.layout.scrollSize,
                snapshot.softWrap ? Vertical : Both);
            renderer(presentation, window, cx);
        }
        else {
            (!snapshot.softWrap ? new Scrollbar(scrollHandle) : Scrollbar.vertical(scrollHandle))
                .viewportBounds(snapshot.layout.bounds)
                .scrollViewportSize(snapshot.layout.scrollViewportSize)
                .scrollSize(snapshot.layout.scrollSize)
                .intoAnyElement();
        };

        scrollbar.prepaintAsRoot(snapshot.layout.bounds.origin,
            new SizeOf<AvailableSpace>(Definite(snapshot.layout.bounds.size.width), Definite(snapshot.layout.bounds.size.height)), window, cx);
        this.scrollbar = scrollbar;
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        if (scrollbar != null) {
            scrollbar.paint(window, cx);
        }
    }

}
