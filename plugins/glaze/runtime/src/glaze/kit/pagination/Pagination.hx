// Ported from gpui-kit 0.8.1: crates/component/src/pagination.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.pagination;

import glaze.AnyElement;
import glaze.App;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.Range;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.Pagination.PaginationItem as PageItem;
import glaze.kit.base.Pagination.PaginationState;
import glaze.kit.I18n;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu.PopupMenuItem;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.menu.DropdownMenu;

/**
 * Pagination with page navigation, next and previous links.
 */
class Pagination implements RenderOnce implements Styled implements Sizable {

    /**
     * The most pages an ellipsis menu lists.
     *
     * The menu renders every item on each frame it is open, so listing every
     * hidden page of a large set makes each hover repaint thousands of rows.
     */
    static inline final MAX_ELLIPSIS_MENU_PAGES:Int = 100;

    /**
     * The pages an ellipsis menu lists: the hidden pages closest to the
     * current page, at most `MAX_ELLIPSIS_MENU_PAGES` of them.
     */
    @:allow(tests)
    static function ellipsisMenuPages(hidden:Range, currentPage:Int):Range {
        return if (hidden.len() <= MAX_ELLIPSIS_MENU_PAGES) {
            hidden;
        } else if (hidden.start > currentPage) {
            new Range(hidden.start, hidden.start + MAX_ELLIPSIS_MENU_PAGES);
        } else {
            new Range(hidden.end - MAX_ELLIPSIS_MENU_PAGES, hidden.end);
        }
    }

    final id:ElementId;

    final paginationStyle:StyleRefinement = new StyleRefinement();

    var size:Size = Medium;

    var currentPageValue:Int = 1;

    var totalPagesValue:Int = 1;

    var disabledValue:Bool = false;

    var compactValue:Bool = false;

    var visiblePagesValue:Int = 5;

    var onClickHandler:Null<(Int, Window, App) -> Void> = null;

    /**
     * Create a new Pagination component with the given ID.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    /**
     * Set the current page number (1-based).
     *
     * The value will be clamped between 1 and total_pages when total_pages is set.
     */
    public function currentPage(page:Int):Pagination {
        currentPageValue = page < 1 ? 1 : page;
        return this;
    }

    /**
     * Set the total number of pages.
     */
    public function totalPages(pages:Int):Pagination {
        totalPagesValue = pages < 1 ? 1 : pages;
        if (currentPageValue > totalPagesValue) {
            currentPageValue = totalPagesValue;
        }
        return this;
    }

    /**
     * Set the handler for page change (when clicking on page numbers, prev, or next).
     *
     * This handler receives the new page number to navigate to.
     */
    public function onClick(handler:(Int, Window, App) -> Void):Pagination {
        onClickHandler = handler;
        return this;
    }

    /**
     * Set to display as compact style.
     *
     * If true, only the prev, next buttons with only icon.
     */
    public function compact():Pagination {
        compactValue = true;
        return this;
    }

    /**
     * Set viewable maximum number of page buttons, default
     */
    public function visiblePages(max:Int):Pagination {
        visiblePagesValue = max;
        return this;
    }

    public function disabled(disabled:Bool):Pagination {
        disabledValue = disabled;
        return this;
    }

    public function withSize(size:IntoSize):Pagination {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    public inline function style():StyleRefinement {
        return paginationStyle;
    }

    function renderNavButton(state:PaginationState, isPrev:Bool):Button {
        final id = isPrev ? 'prev' : 'next';
        final label = isPrev ? I18n.t('Pagination.previous') : I18n.t('Pagination.next');
        final icon = isPrev ? IconName.ChevronLeft : IconName.ChevronRight;

        final targetPage = isPrev ? state.previousPage() : state.nextPage();

        final button = new Button(id)
            .ghost()
            .compact()
            .withSize(size)
            .disabled(targetPage == null)
            .tooltip(label);
        if (compactValue) button.icon(icon);
        if (!compactValue) {
            final content = hFlex()
                .wFull()
                .gap2()
                .flexNowrap();
            if (isPrev) content.flexRowReverse();
            button.child(content
                .child(label)
                .child(new Icon(icon)));
        }
        if (targetPage != null && state.hasOnChange()) {
            final state = state.clone();
            final page:Int = targetPage;
            button.onClick((_, window, cx) -> {
                state.requestPage(page, window, cx);
            });
        }
        return button;
    }

    public function render(window:Window, cx:App):IntoElement {
        var state = new PaginationState(currentPageValue, totalPagesValue)
            .visiblePages(visiblePagesValue)
            .disabled(disabledValue);
        final onClick = onClickHandler;
        if (onClick != null) {
            state = state.onChange((page, window, cx) -> onClick(page, window, cx));
        }
        final pageNumbers = !compactValue ? state.items() : [];

        final currentPage = state.currentPage();
        final isDisabled = disabledValue;
        final itemState = state.clone();

        final root = new glaze.kit.base.Pagination(id, state.clone())
            .hFlex()
            .px2()
            .py2()
            .gap1()
            .itemsCenter()
            .refineStyle(paginationStyle)
            .child(renderNavButton(state, true));
        for (item in pageNumbers) {
            switch item {
                case Page(page):
                    final isSelected = page == currentPage;

                    final button = new Button(page).withSize(size);
                    if (isSelected) button.outline() else button.ghost();
                    button.label(Std.string(page))
                        .compact()
                        .disabled(isDisabled);
                    if (!isSelected && itemState.hasOnChange()) {
                        final state = itemState.clone();
                        button.onClick((_, window, cx) -> {
                            state.requestPage(page, window, cx);
                        });
                    }
                    root.child(button);
                case Ellipsis(range):
                    final state = itemState.clone();
                    root.child(new Button('ellipsis-${range.start}-${range.end}')
                        .ghost()
                        .withSize(size)
                        .compact()
                        .disabled(disabledValue)
                        .icon(IconName.Ellipsis)
                        .dropdownMenu((menu, _, _) -> {
                            final pages = ellipsisMenuPages(range, currentPage);
                            for (page in pages.start...pages.end) {
                                menu = menu.item(PopupMenuItem.create('$page')
                                    .checked(page == currentPage)
                                    .onClick((_, window, cx) -> {
                                        state.requestPage(page, window, cx);
                                    }));
                            }

                            return menu.minW(glaze.Prelude.px(55.)).maxH(glaze.Prelude.px(240.)).scrollable(true);
                        }));
            }
        }
        root.child(renderNavButton(state, false));
        return root;
    }

}
