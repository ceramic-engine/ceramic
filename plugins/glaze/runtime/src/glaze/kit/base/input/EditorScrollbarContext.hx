// Ported from gpui-kit 0.8.1: crates/base/src/input/scrollbar_presentation.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.Point;
import gpui.ScrollHandle;
import gpui.Size;
import gpui.Window;
import gpui.base.Scrollbar.ScrollbarAxis;
import gpui.base.Scrollbar.ScrollbarHandleImpl;

/**
 * Presentation hook for an editor's existing viewport, without a second
 * scroll system: current-frame editor geometry and its retained scroll
 * offset. The editor applies caret scrolling before invoking the
 * presentation callback.
 *
 * Like other scrollbar handles, the content size includes the viewport's
 * padding, so subtracting the track size gives the scroll range.
 */
class EditorScrollbarContext implements ScrollbarHandleImpl {

    @:allow(gpui.base.input)
    final handle:ScrollHandle;

    @:allow(gpui.base.input)
    final viewport:Bounds;

    @:allow(gpui.base.input)
    final scrollViewport:Size;

    @:allow(gpui.base.input)
    final content:Size;

    @:allow(gpui.base.input)
    final _axis:ScrollbarAxis;

    @:allow(gpui.base.input)
    function new(handle:ScrollHandle, viewport:Bounds, scrollViewport:Size, content:Size, axis:ScrollbarAxis) {
        this.handle = handle;
        this.viewport = viewport;
        this.scrollViewport = scrollViewport;
        this.content = content;
        this._axis = axis;
    }

    public inline function axis():ScrollbarAxis {
        return _axis;
    }

    /**
     * The editor's viewport without padding, for consumers that need its
     * text layout size. Scrollbars should use `contentSize` and
     * `viewportBounds` to calculate the scroll range; both include the
     * padding around this viewport.
     */
    public inline function scrollViewportSize():Size {
        return scrollViewport;
    }

    public function viewportBounds():Bounds {
        return viewport;
    }

    public function contentSize():Size {
        return content.add(viewport.size.sub(scrollViewport));
    }

    public function offset():Point {
        return handle.offset();
    }

    public function setOffset(offset:Point):Void {
        handle.setOffset(offset);
    }

    public function startDrag():Void {}

    public function endDrag():Void {}

}

/**
 * Supply a scrollbar from the consuming UI library. Null retains Base's
 * default.
 */
typedef EditorScrollbarRenderer = (EditorScrollbarContext, Window, App) -> AnyElement;
