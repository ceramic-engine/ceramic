// Ported from gpui-kit 0.8.1: crates/component/src/input/popovers/caret_anchored.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.input;

import gpui.AnyElement;
import gpui.App;
import gpui.AvailableSpace;
import gpui.Bounds;
import gpui.Element;
import gpui.GlobalElementId;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.Point;
import gpui.SizeOf;
import gpui.Style;
import gpui.WeakEntity;
import gpui.Window;
import gpui.base.input.EditorState;
import gpui.base.input.PrepaintCaretGeometry;

/**
 * A popup positioned at the caret from the input's current-frame prepaint.
 *
 * The input stashes fresh caret geometry in its prepaint
 * (`PrepaintCaretGeometry`). Popups live inside `deferred()`, so their
 * prepaint runs after the input's prepaint but before its paint; resolving
 * the anchor there puts the popup at the current frame's caret instead of
 * the previous frame's.
 *
 * The content is built in prepaint (not render) from the resolved anchor,
 * so position, hitboxes, accessibility bounds, and width/layout decisions
 * are all consistent with the current frame's caret. Always use inside
 * `deferred()` so the prepaint runs after the input's prepaint.
 */
class CaretAnchoredPopup extends Element {

    final editor:WeakEntity<EditorState>;

    final build:(Point, Window, App) -> AnyElement;

    var content:Null<AnyElement> = null;

    public function new(editor:WeakEntity<EditorState>, build:(Point, Window, App) -> AnyElement) {
        this.editor = editor;
        this.build = build;
    }

    /**
     * Computes the caret-anchored popup origin from fresh prepaint geometry.
     *
     * Shared by the completion and code-action menus so both anchor to the
     * same point: just below the caret, nudged left. The result is in window
     * coordinates, matching where the caret itself is painted.
     */
    public static function caretPopupAnchor(geometry:PrepaintCaretGeometry):Point {
        return new Point(geometry.cursorBounds().origin.x - 4., geometry.cursorBounds().origin.y + geometry.scrollOffset().y + geometry.lineHeight() + 4.);
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        // The real layout happens in prepaint, once the anchor is resolved.
        return window.requestLayout(@:privateAccess gpui.Style.sharedDefaultStyle(), [], cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final editor = this.editor.upgrade();
        if (editor == null)
            return;
        final geometry = editor.read(cx).prepaintCaretGeometry;
        if (geometry == null)
            return;
        final anchor = caretPopupAnchor(geometry);
        final content = build(anchor, window, cx);
        final viewport = window.viewportSize();
        content.layoutAsRoot(new SizeOf<AvailableSpace>(Definite(viewport.width), Definite(viewport.height)), window, cx);
        content.prepaintAt(anchor, window, cx);
        this.content = content;
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        if (content != null) {
            content.paint(window, cx);
        }
    }

}
