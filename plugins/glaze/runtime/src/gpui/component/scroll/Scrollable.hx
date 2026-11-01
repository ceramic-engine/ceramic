// Ported from gpui-kit 0.8.1: crates/component/src/scroll/scrollable.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.scroll;

import gpui.AnyElement;
import gpui.App;
import gpui.Div;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.IntoElement;
import gpui.Overflow;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.ScrollHandle;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.ScrollBounce;
import gpui.base.ScrollableMask;
import gpui.base.Scrollbar;
import gpui.base.Scrollbar.ScrollbarAxis;
import gpui.base.Scrollbar.ScrollbarHandle;

import gpui.Prelude.*;

using gpui.base.InteractiveElementExt;
using gpui.base.StyledExt;

/**
 * Makes elements scrollable with scrollbars (Rust trait `ScrollableElement`,
 * implemented for `Div`): `using gpui.component.scroll.Scrollable;`.
 *
 * The wrapped element is the scroll area itself, rather than being inserted as
 * a child of a new scroll area.
 */
class ScrollableElement {

    /** Adds a scrollbar to the element. */
    public static function scrollbar(self:Div, scrollHandle:ScrollbarHandle, axis:ScrollbarAxis, ?pos:haxe.PosInfos):Div {
        return self.child(new ScrollbarLayer(callerId(pos), axis, scrollHandle));
    }

    /** Adds a vertical scrollbar to the element. */
    public static function verticalScrollbar(self:Div, scrollHandle:ScrollbarHandle, ?pos:haxe.PosInfos):Div {
        return scrollbar(self, scrollHandle, Vertical, pos);
    }

    /** Adds a horizontal scrollbar to the element. */
    public static function horizontalScrollbar(self:Div, scrollHandle:ScrollbarHandle, ?pos:haxe.PosInfos):Div {
        return scrollbar(self, scrollHandle, Horizontal, pos);
    }

    /**
     * Almost equivalent to `overflowScroll`, but adds scrollbars.
     * Preserves the source element as the scrollable container.
     */
    public static function overflowScrollbar(self:Div, ?pos:haxe.PosInfos):Scrollable {
        return new Scrollable(self, Both, pos);
    }

    /**
     * Almost equivalent to `overflowXScroll`, but adds Horizontal scrollbar.
     * Preserves the source element as the scrollable container.
     */
    public static function overflowXScrollbar(self:Div, ?pos:haxe.PosInfos):Scrollable {
        return new Scrollable(self, Horizontal, pos);
    }

    /**
     * Almost equivalent to `overflowYScroll`, but adds Vertical scrollbar.
     * Preserves the source element as the scrollable container.
     */
    public static function overflowYScrollbar(self:Div, ?pos:haxe.PosInfos):Scrollable {
        return new Scrollable(self, Vertical, pos);
    }

    static inline function callerId(pos:haxe.PosInfos):ElementId {
        return ElementId.CodeLocation(pos.fileName, pos.lineNumber);
    }

}

/**
 * A scrollable element wrapper that renders the original element as the
 * scroll area and overlays scrollbars.
 */
class Scrollable implements RenderOnce implements Styled implements ParentElement {

    var _id:ElementId;

    final element:Div;

    final axis:ScrollbarAxis;

    var _scrollBounce:Null<Bool> = null;

    @:allow(gpui.component.scroll)
    function new(element:Div, axis:ScrollbarAxis, ?pos:haxe.PosInfos) {
        _id = ElementId.CodeLocation(pos.fileName, pos.lineNumber);
        this.element = element;
        this.axis = axis;
    }

    /**
     * Set a specific element id, default is the call site.
     *
     * Only needed when one call site creates several scrollables, which would
     * otherwise share a single scroll position.
     */
    public function id(id:ElementIdArg):Scrollable {
        _id = id;
        return this;
    }

    /**
     * Bounce at the vertical boundaries. On by default on iOS, Android and
     * macOS, off elsewhere; horizontal-only areas do not bounce.
     */
    public function scrollBounce(enabled:Bool):Scrollable {
        _scrollBounce = enabled;
        return this;
    }

    public inline function style():StyleRefinement {
        return element.style();
    }

    public function extend(elements:Array<AnyElement>):Void {
        element.extend(elements);
    }

    public function child(child:IntoElement):Scrollable {
        element.child(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Scrollable {
        for (child in children) element.child(child);
        return this;
    }

    /** `InteractiveElement::interactivity`. */
    public inline function interactivity():gpui.Interactivity {
        return element.interactivity;
    }

    public function trackFocus(focus:gpui.FocusHandle):Scrollable {
        element.trackFocus(focus);
        return this;
    }

    static function scrollHandleFor(id:ElementId, window:Window, cx:App):ScrollHandle {
        return window.useKeyedState(id, cx, _ -> new ScrollHandle()).read(cx).value;
    }

    /**
     * Copies the outer layout styles from the element, so the wrapper can
     * participate in the parent's layout the same way the source element would.
     *
     * A flex item only drops its content-based automatic minimum size when its own
     * overflow is not `Overflow.Visible`; otherwise the item refuses to shrink
     * around its content. The scrolled overflow lives on the inner scroll area, so
     * the wrapper has to declare the scrolled axis clipped itself.
     *
     * `Overflow.Hidden` rather than a zero minimum: it is the axis' real
     * behavior, it leaves an explicit `minSize` from the caller in charge, and it
     * keeps the region's content size contributing to an auto-sized ancestor such
     * as a Dialog that grows with its body.
     */
    static function rootStyleFrom(element:Div, axis:ScrollbarAxis):StyleRefinement {
        final style = element.style();
        final result = new StyleRefinement();
        result.sizeWidth = style.sizeWidth;
        result.sizeHeight = style.sizeHeight;
        result.minSizeWidth = style.minSizeWidth;
        result.minSizeHeight = style.minSizeHeight;
        result.maxSizeWidth = style.maxSizeWidth;
        result.maxSizeHeight = style.maxSizeHeight;
        if (style.has(StyleRefinement.FLEX_GROW)) result.flexGrow = style.flexGrow;
        if (style.has(StyleRefinement.FLEX_SHRINK)) result.flexShrink = style.flexShrink;
        result.flexBasis = style.flexBasis;
        if (style.has(StyleRefinement.ALIGN_SELF)) result.alignSelf = style.alignSelf;
        if (axis.hasHorizontal()) result.overflowX = Overflow.Hidden;
        if (axis.hasVertical()) result.overflowY = Overflow.Hidden;
        return result;
    }

    public function render(window:Window, cx:App):IntoElement {
        final scrollHandle = scrollHandleFor(_id, window, cx);

        // Preserve the caller-requested size on the wrapper, while keeping the
        // caller's element as the actual scroll-tracked layout container.
        final rootStyle = rootStyleFrom(element, axis);

        final rootId = _id;
        final areaId = ElementId.NamedChild(_id, 'area');
        final contentId = ElementId.NamedChild(_id, 'content');
        final scrollbarId = ElementId.NamedChild(_id, 'scrollbar');

        final content = element.id(contentId).flexNone();
        switch axis {
            case Vertical: content.hAuto().minHFull();
            case Horizontal: content.wAuto().minWFull();
            case Both: content.sizeAuto().minSizeFull();
        }
        // The wrapper holds the caller's maximum size. Left on the content
        // too, it would cap the content at the area's size on the scrolled
        // axis, so nothing would overflow and the area would not scroll.
        final contentStyle = content.style();
        switch axis {
            case Vertical: contentStyle.maxSizeHeight = null;
            case Horizontal: contentStyle.maxSizeWidth = null;
            case Both:
                contentStyle.maxSizeWidth = null;
                contentStyle.maxSizeHeight = null;
        }

        // Keep the scroll area in the normal flow: its content size must
        // propagate to auto-sized ancestors (e.g. a Dialog that grows with
        // its content). An absolutely positioned scroll area would collapse
        // such ancestors to zero height.
        final scrollArea = div()
            .id(areaId)
            .sizeFull()
            .flex()
            .trackScroll(scrollHandle);
        switch axis {
            case Vertical: scrollArea.flexCol().overflowYScroll();
            case Horizontal: scrollArea.flexRow().overflowXScroll();
            case Both: scrollArea.overflowScroll();
        }
        // On a single-axis area gpui otherwise remaps the other axis' delta
        // onto ours, so a purely horizontal swipe scrolls this vertically.
        scrollArea.lockScrollAxis().child(content);

        // The wrapper lays the area out as a flex item along the scrolled
        // axis, so the area shrinks to the wrapper's size.
        final root = div()
            .id(rootId)
            .sizeFull()
            .refineStyle(rootStyle)
            .relative()
            .flex();
        switch axis {
            case Horizontal: root.flexRow();
            case Vertical | Both: root.flexCol();
        }
        final bounce = new ScrollBounce(ElementId.NamedChild(_id, 'bounce'), scrollHandle, scrollArea);
        if (_scrollBounce != null) {
            bounce.enabled(_scrollBounce);
        }
        root.child(bounce);
        // A plain mouse wheel has only a vertical axis, which the locked
        // horizontal area above would ignore.
        if (axis == Horizontal) {
            root.child(ScrollableMask.verticalWheel(scrollHandle));
        }
        return root.child(renderScrollbar(scrollbarId, scrollHandle, axis, window, cx));
    }

    @:allow(gpui.component.scroll)
    static function renderScrollbar(id:ElementIdArg, scrollHandle:ScrollbarHandle, axis:ScrollbarAxis, window:Window, cx:App):Div {
        // Do not render scrollbar when inspector is picking elements, to
        // allow us to pick the background elements (the port has no
        // inspector).
        #if gpui_inspector
        final isInspectorPicking = window.isInspectorPicking(cx);
        if (isInspectorPicking) {
            return div();
        }
        #end
        return div()
            .absolute()
            .inset0()
            .child(
                new Scrollbar(scrollHandle)
                    .id(id)
                    .axis(axis)
                    .viewportFromLayout()
            );
    }

}

/**
 * A scrollbar overlay added as a child (Rust `ScrollbarLayer`).
 */
private class ScrollbarLayer implements RenderOnce {

    final id:ElementId;

    final axis:ScrollbarAxis;

    final scrollHandle:ScrollbarHandle;

    public function new(id:ElementId, axis:ScrollbarAxis, scrollHandle:ScrollbarHandle) {
        this.id = id;
        this.axis = axis;
        this.scrollHandle = scrollHandle;
    }

    public function render(window:Window, cx:App):IntoElement {
        return Scrollable.renderScrollbar(id, scrollHandle, axis, window, cx);
    }

}
