// Ported from gpui-kit 0.8.1: crates/base/src/pagination.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.Component;
import glaze.Div;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.Range;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A visible destination in a pagination control.
 */
enum PaginationItem {
    Page(page:Int);
    Ellipsis(range:Range);
}

class PaginationItemTools {

    /** Structural equality (Rust `PartialEq`). */
    public static function equals(self:PaginationItem, other:PaginationItem):Bool {
        return switch [self, other] {
            case [Page(a), Page(b)]: a == b;
            case [Ellipsis(a), Ellipsis(b)]: a.equals(b);
            case _: false;
        }
    }

    /** Rust's `Debug`: `Page(3)`, `Ellipsis(2..3)`. */
    public static function toString(self:PaginationItem):String {
        return switch self {
            case Page(page): 'Page($page)';
            case Ellipsis(range): 'Ellipsis($range)';
        }
    }

}

/**
 * The controlled behavior shared by every part of a pagination control.
 *
 * Immutable like a Rust value: the builders return a copy (Rust takes `self`
 * by value, and callers clone the state before deriving a variant of it).
 */
class PaginationState {

    var currentPageValue:Int;

    var totalPagesValue:Int;

    var visiblePagesValue:Int = 5;

    var disabledValue:Bool = false;

    var onChangeHandler:Null<(Int, Window, App) -> Void> = null;

    public function new(currentPage:Int, totalPages:Int) {
        final totalPages = totalPages < 1 ? 1 : totalPages;
        currentPageValue = currentPage < 1 ? 1 : (currentPage > totalPages ? totalPages : currentPage);
        totalPagesValue = totalPages;
    }

    /** Rust `Clone`. */
    public function clone():PaginationState {
        final state = new PaginationState(currentPageValue, totalPagesValue);
        state.visiblePagesValue = visiblePagesValue;
        state.disabledValue = disabledValue;
        state.onChangeHandler = onChangeHandler;
        return state;
    }

    public function visiblePages(visiblePages:Int):PaginationState {
        final state = clone();
        state.visiblePagesValue = visiblePages < 5 ? 5 : visiblePages;
        return state;
    }

    public function disabled(disabled:Bool):PaginationState {
        final state = clone();
        state.disabledValue = disabled;
        return state;
    }

    /**
     * Handles a requested page change.
     *
     * Unlike the element-level controls, this is a model-level request that
     * may also come from the keyboard or from application code, so it does not
     * carry a pointer event.
     */
    public function onChange(handler:(Int, Window, App) -> Void):PaginationState {
        final state = clone();
        state.onChangeHandler = handler;
        return state;
    }

    public function currentPage():Int {
        return currentPageValue;
    }

    public function totalPages():Int {
        return totalPagesValue;
    }

    public function isDisabled():Bool {
        return disabledValue;
    }

    public function hasOnChange():Bool {
        return onChangeHandler != null;
    }

    public function previousPage():Null<Int> {
        return (!disabledValue && currentPageValue > 1) ? currentPageValue - 1 : null;
    }

    public function nextPage():Null<Int> {
        return (!disabledValue && currentPageValue < totalPagesValue) ? currentPageValue + 1 : null;
    }

    /**
     * Requests a controlled page change after applying the shared disabled,
     * bounds, and current-page guards.
     */
    public function requestPage(page:Int, window:Window, cx:App):Void {
        if (disabledValue || page == currentPageValue || !(page >= 1 && page <= totalPagesValue)) {
            return;
        }

        if (onChangeHandler != null) {
            onChangeHandler(page, window, cx);
        }
    }

    public function items():Array<PaginationItem> {
        return calculateItems(currentPageValue, totalPagesValue, visiblePagesValue);
    }

    @:allow(tests)
    static function calculateItems(current:Int, total:Int, maxVisible:Int):Array<PaginationItem> {
        if (total <= 1) {
            return [];
        }

        final maxVisible = maxVisible < 5 ? 5 : maxVisible;
        if (total <= maxVisible) {
            return [for (page in 1...total + 1) Page(page)];
        }

        final pages = [Page(1)];
        final sidePages = Std.int((maxVisible - 3) / 2);
        final start = if (current <= sidePages + 1) {
            2;
        } else if (current > total - sidePages - 1) {
            total - sidePages - 1;
        } else {
            current - sidePages;
        }

        if (start > 2) {
            pages.push(Ellipsis(new Range(2, start)));
        }

        final end = if (current >= total - sidePages) {
            total - 1;
        } else if (current <= sidePages + 1) {
            sidePages + 2;
        } else {
            current + sidePages;
        }

        for (page in start...end + 1) pages.push(Page(page));
        if (end < total - 1) {
            pages.push(Ellipsis(new Range(end + 1, total)));
        }
        pages.push(Page(total));
        return pages;
    }

}

/**
 * An unstyled pagination navigation landmark.
 *
 * Interactive styles and listeners go to `base`.
 */
class Pagination extends Component implements Styled implements ParentElement {

    /** The stateful element the pagination renders. */
    public final base:Div;

    final paginationState:PaginationState;

    final paginationStyle:StyleRefinement = new StyleRefinement();

    @prop var accessibilityLabel:String = 'Pagination';

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the pagination exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.Navigation);

    public function new(id:ElementIdArg, state:PaginationState) {
        super();
        base = div().id(id);
        paginationState = state;
    }

    public function state():PaginationState {
        return paginationState;
    }

    public inline function style():StyleRefinement {
        return paginationStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Pagination {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Pagination {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    /** A click listener on the root (on `base`). */
    public function onClick(listener:(ClickEvent, Window, App) -> Void):Pagination {
        base.onClick(listener);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        a11y.label = accessibilityLabel;
        base.extend(childElements);
        return base.refineStyle(paginationStyle);
    }

}
