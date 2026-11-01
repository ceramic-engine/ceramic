// Ported from gpui-pre 0.3.10: src/elements/list.rs (`List`, `list`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.ListState.LayoutItemsResponse;

/**
 * A list element that can be used to render a large number of differently sized elements
 * efficiently (Rust `List`, renamed: `List` is a Haxe standard type). Create one with
 * `Prelude.list(state, renderItem)`. Its state is a `ListState` stored on your view, so
 * that your code can coordinate directly with the list element's cached state.
 *
 * If all of your elements are the same height, see `UniformList` for a simpler API.
 */
class ListElement extends Element implements Styled {

    final state:ListState;

    final renderItem:(Int, Window, App) -> IntoElement;

    final listStyle:StyleRefinement = new StyleRefinement();

    var sizingBehavior:ListSizingBehavior = ListSizingBehavior.Auto;

    var hitbox:Null<Hitbox> = null;

    var layout:Null<LayoutItemsResponse> = null;

    public function new(state:ListState, renderItem:(Int, Window, App) -> IntoElement) {
        this.state = state;
        this.renderItem = renderItem;
    }

    public inline function style():StyleRefinement {
        return listStyle;
    }

    /**
     * Set the sizing behavior for the list.
     */
    public function withSizingBehavior(behavior:ListSizingBehavior):ListElement {
        sizingBehavior = behavior;
        return this;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return switch sizingBehavior {
            case ListSizingBehavior.Infer:
                final style = new Style();
                style.overflowY = Overflow.Scroll;
                style.refine(listStyle);
                window.withTextStyle(style.textStyle(), window -> {
                    final lastBounds = state.getLastLayoutBounds();
                    final availableHeight:Float = if (lastBounds != null) {
                        lastBounds.size.height;
                    }
                    else {
                        // If we don't have the last layout bounds (first render),
                        // we might just use the overdraw value as the available height to layout enough items.
                        state.getOverdraw();
                    }
                    final padding = paddingToPixels(style, lastBounds != null ? lastBounds.size : new Size(), window.remSize());

                    final layoutResponse = state.layoutItems(null, availableHeight, padding, renderItem, window, cx);
                    final maxElementWidth = layoutResponse.maxItemWidth;

                    final totalHeight = state.items.height;

                    return window.requestMeasuredLayout(style, (knownDimensions, availableSpace, _, _) -> {
                        final width:Float = knownDimensions.width != null ? knownDimensions.width : switch availableSpace.width {
                            case Definite(x): x;
                            case MinContent | MaxContent: maxElementWidth;
                        }
                        final height:Float = switch availableSpace.height {
                            case Definite(height): Math.min(totalHeight, height);
                            case MinContent | MaxContent: totalHeight;
                        }
                        return new Size(width, height);
                    });
                });
            case ListSizingBehavior.Auto:
                final style = new Style();
                style.refine(listStyle);
                window.withTextStyle(style.textStyle(), window -> {
                    return window.requestLayout(style, null, cx);
                });
        }
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final state = this.state;
        state.clearReset();

        final style = new Style();
        style.refine(listStyle);

        hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);

        // If the width of the list has changed, invalidate all cached item heights
        state.invalidateIfWidthChanged(bounds.size.width);

        final padding = paddingToPixels(style, bounds.size, window.remSize());
        var autoscroll = true;
        var layout:Null<LayoutItemsResponse> = null;
        while (layout == null) {
            switch state.prepaintItems(bounds, padding, autoscroll, renderItem, window, cx) {
                case Ok(response):
                    layout = response;
                case Err(autoscrollRequest):
                    state.applyAutoscrollRequest(autoscrollRequest);
                    autoscroll = false;
            }
        }

        state.setLastLayout(bounds, padding);
        this.layout = layout;
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final currentView = window.currentView();
        // Port: a list scrolled from another view draws again (default view caching)
        state.recordView(window);

        // Register the scroll listener before painting children so that, in
        // the bubble phase (which runs in reverse registration order),
        // children's scroll-wheel handlers run first and can stop propagation
        // to prevent the list from scrolling. This matches the ordering of
        // div-based scroll containers.
        final listState = state;
        final height = bounds.size.height;
        final layout = this.layout;
        this.layout = null;
        final scrollTop = layout.scrollTop;
        final hitbox = this.hitbox;
        this.hitbox = null;
        var accumulatedScrollDelta = ScrollDelta.Lines(new Point(0, 0));
        window.onMouseEvent(PlatformInputKind.Scroll, (event, phase, window, cx) -> {
            if (phase == DispatchPhase.Bubble && hitbox.shouldHandleScroll(window)) {
                final event:ScrollEvent = cast event;
                accumulatedScrollDelta = accumulatedScrollDelta.coalesce(event.delta);
                final pixelDelta = accumulatedScrollDelta.pixelDelta(20);
                listState.scroll(scrollTop, height, pixelDelta, currentView, window, cx);
            }
        });

        window.withContentMask(new ContentMask(bounds), window -> {
            for (item in layout.itemLayouts) {
                item.element.paint(window, cx);
            }
            return null;
        });
    }

    /**
     * Rust `style.padding.to_pixels(size.into(), rem_size)`.
     */
    @:allow(gpui)
    static function paddingToPixels(style:Style, parentSize:Size, remSize:Pixels):Edges {
        return new Edges(
            style.paddingTop.toPixels(AbsoluteLength.Pixels(parentSize.height), remSize),
            style.paddingRight.toPixels(AbsoluteLength.Pixels(parentSize.width), remSize),
            style.paddingBottom.toPixels(AbsoluteLength.Pixels(parentSize.height), remSize),
            style.paddingLeft.toPixels(AbsoluteLength.Pixels(parentSize.width), remSize)
        );
    }

}
