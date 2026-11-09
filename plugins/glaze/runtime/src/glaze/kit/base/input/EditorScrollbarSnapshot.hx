// Ported from gpui-kit 0.8.1: crates/base/src/input/base/element.rs (`EditorScrollbarSnapshot`, `EditorScrollbarLayout`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Bounds;
import glaze.Edges;
import glaze.Pixels;
import glaze.Point;
import glaze.Size;

/**
 * What the editor scrollbar needs from the last prepaint of the text: its
 * layout, the scroll offset painted with the carets, and the wrap mode.
 */
class EditorScrollbarSnapshot {

    public final layout:EditorScrollbarLayout;

    public final cursorScrollOffset:Point;

    public final softWrap:Bool;

    public function new(layout:EditorScrollbarLayout, cursorScrollOffset:Point, softWrap:Bool) {
        this.layout = layout;
        this.cursorScrollOffset = cursorScrollOffset;
        this.softWrap = softWrap;
    }

    /** Rust `EditorScrollbarSnapshot::new` */
    public static function create(inputBounds:Bounds, lastLayout:LastLayout, scrollSize:Size, cursorScrollOffset:Point, state:InputBaseState):EditorScrollbarSnapshot {
        return new EditorScrollbarSnapshot(EditorScrollbarLayout.create(inputBounds, scrollSize, state.editorPaddings), cursorScrollOffset,
            state.softWrap);
    }

    public function equals(other:Null<EditorScrollbarSnapshot>):Bool {
        return other != null && other.layout.equals(layout) && other.cursorScrollOffset.equals(cursorScrollOffset) && other.softWrap == softWrap;
    }

}

/**
 * Where the editor scrollbar sits and what it scrolls.
 */
class EditorScrollbarLayout {

    public final bounds:Bounds;

    public final scrollSize:Size;

    /** Excludes editor padding from scroll range while the track still includes it. */
    public final scrollViewportSize:Size;

    public function new(bounds:Bounds, scrollSize:Size, scrollViewportSize:Size) {
        this.bounds = bounds;
        this.scrollSize = scrollSize;
        this.scrollViewportSize = scrollViewportSize;
    }

    /**
     * Rust `EditorScrollbarLayout::new` (without gpui-kit's code editor
     * gutter, which shifts the track right of the line numbers).
     */
    public static function create(inputBounds:Bounds, scrollSize:Size, paddings:Edges):EditorScrollbarLayout {
        final bounds = new Bounds(new Point(inputBounds.origin.x, inputBounds.origin.y - paddings.top),
            new Size(inputBounds.size.width + paddings.right, inputBounds.size.height + paddings.top + paddings.bottom));

        return new EditorScrollbarLayout(bounds, new Size(scrollSize.width + paddings.right + TextElement.RIGHT_MARGIN, scrollSize.height),
            new Size(bounds.size.width, inputBounds.size.height));
    }

    public function equals(other:Null<EditorScrollbarLayout>):Bool {
        return other != null && other.bounds.equals(bounds) && other.scrollSize.equals(scrollSize) && other.scrollViewportSize.equals(scrollViewportSize);
    }

}
