// Ported from gpui-kit 0.8.1: crates/component/src/list/list.rs (`List`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.list;

import glaze.App;
import glaze.Entity;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.list.ListState.ListOptions;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * The List element.
 */
class List<D:ListDelegate> implements RenderOnce implements Styled implements Sizable {

    final state:Entity<ListState<D>>;

    final listStyle:StyleRefinement = new StyleRefinement();

    final options:ListOptions = new ListOptions();

    /** Create a new List element with the given ListState entity. */
    public function new(state:Entity<ListState<D>>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return listStyle;
    }

    /** Set whether the scrollbar is visible, default is `true`. */
    public function scrollbarVisible(visible:Bool):List<D> {
        options.scrollbarVisible = visible;
        return this;
    }

    /**
     * Bounce at the vertical boundaries. On by default on iOS, Android and
     * macOS, off elsewhere; reduced motion disables displacement.
     */
    public function scrollBounce(enabled:Bool):List<D> {
        options.scrollBounce = enabled;
        return this;
    }

    /** Sets the placeholder text for the search input. */
    public function searchPlaceholder(placeholder:String):List<D> {
        options.searchPlaceholder = placeholder;
        return this;
    }

    public function withSize(size:IntoSize):List<D> {
        options.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        options.size = size;
    }

    public function render(window:Window, cx:App):IntoElement {
        // Take paddings, max_height to options, and clear them from style,
        // because they would be applied to the inner virtual list.
        options.paddingTop = listStyle.paddingTop;
        options.paddingRight = listStyle.paddingRight;
        options.paddingBottom = listStyle.paddingBottom;
        options.paddingLeft = listStyle.paddingLeft;
        options.maxHeight = listStyle.maxSizeHeight;
        listStyle.paddingTop = null;
        listStyle.paddingRight = null;
        listStyle.paddingBottom = null;
        listStyle.paddingLeft = null;
        listStyle.maxSizeHeight = null;

        final options = this.options;
        state.update(cx, (state, _) -> {
            state.options = options;
        });

        return div()
            .id("list")
            .sizeFull()
            .refineStyle(listStyle)
            .child(state);
    }

}
