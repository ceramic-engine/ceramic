// Ported from gpui-kit 0.8.1: crates/component/src/setting/settings.rs, crates/component/src/setting/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.setting;

import gpui.AnyElement;
import gpui.App;
import gpui.Axis;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Entity;
import gpui.IntoElement;
import gpui.Pixels;
import gpui.RenderOnce;
import gpui.Window.StateModel;
import gpui.StyleRefinement;
import gpui.Window;
import gpui.base.input.InputState;
import gpui.base.resizable.PixelsRange;
import gpui.component.I18n;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.Size.IntoSize;
import gpui.component.empty.Empty;
import gpui.component.groupbox.GroupBox.GroupBoxVariant;
import gpui.component.input.Input;
import gpui.component.resizable.Resizable;
import gpui.component.sidebar.Sidebar;
import gpui.component.sidebar.SidebarMenu;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * The settings structure containing multiple pages for app settings.
 *
 * The hierarchy of settings is as follows:
 *
 * ```
 * Settings
 *   SettingPage     <- The single active page displayed
 *     SettingGroup
 *       SettingItem
 *         Label
 *         SettingField (e.g., Switch, Dropdown, Input)
 * ```
 */
class Settings implements RenderOnce implements Sizable {

    static inline final STACKED_LAYOUT_MAX_WIDTH:Pixels = 480.;

    final id:ElementId;

    final pagesValue:Array<SettingPage> = [];

    var groupVariant:GroupBoxVariant = Normal;

    var sizeValue:Size = Medium;

    var sidebarWidthValue:Pixels = 250.0;

    var sidebarSizeRangeValue:PixelsRange = new PixelsRange(160.0, 360.0);

    var sidebarStyleValue:StyleRefinement = new StyleRefinement();

    var defaultSelectedIndexValue:SelectIndex = new SelectIndex();

    var headerStyleValue:StyleRefinement = new StyleRefinement();

    /**
     * Create a new settings with the given ID.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    /**
     * The state the settings with this id keep in `window` (what Rust's
     * tests read with `use_keyed_state`), to call from the same element
     * context as the render of the settings.
     */
    @:allow(gpui.component.setting, tests)
    static function keyedState(window:Window, id:ElementIdArg, cx:App):Entity<StateModel<SettingsState>> {
        return window.useKeyedState(id, cx, _ -> throw 'unreachable');
    }

    /**
     * Set the width of the sidebar, default is `250px`.
     */
    public function sidebarWidth(width:Pixels):Settings {
        sidebarWidthValue = width;
        return this;
    }

    /**
     * Set the resize range of the sidebar, default is `160px..360px`.
     */
    public function sidebarSizeRange(range:PixelsRange):Settings {
        sidebarSizeRangeValue = range;
        return this;
    }

    /**
     * Add a page to the settings.
     */
    public function page(page:SettingPage):Settings {
        pagesValue.push(page);
        return this;
    }

    /**
     * Add pages to the settings.
     */
    public function pages(pages:Iterable<SettingPage>):Settings {
        for (page in pages) pagesValue.push(page);
        return this;
    }

    /**
     * Set the default variant for all setting groups.
     *
     * All setting groups will use this variant unless overridden individually.
     */
    public function withGroupVariant(variant:GroupBoxVariant):Settings {
        groupVariant = variant;
        return this;
    }

    /**
     * Set the style refinement for the sidebar.
     */
    public function sidebarStyle(style:StyleRefinement):Settings {
        final copy = new StyleRefinement();
        copy.refine(style);
        sidebarStyleValue = copy;
        return this;
    }

    /**
     * Set the default index of the page to be selected.
     */
    public function defaultSelectedIndex(index:SelectIndex):Settings {
        defaultSelectedIndexValue = index;
        return this;
    }

    /**
     * Set the style refinement for the header.
     */
    public function headerStyle(style:StyleRefinement):Settings {
        final copy = new StyleRefinement();
        copy.refine(style);
        headerStyleValue = copy;
        return this;
    }

    public function withSize(size:IntoSize):Settings {
        sizeValue = size;
        return this;
    }

    public function setSize(size:Size):Void {
        sizeValue = size;
    }

    function renderActivePage(state:Entity<StateModel<SettingsState>>, filter:SettingsFilter, options:RenderOptions, window:Window, cx:App):AnyElement {
        final pageIx = state.read(cx).value.selectedIndex.pageIx;
        if (pageIx < pagesValue.length && filter.groups[pageIx].length > 0) {
            final page = pagesValue[pageIx];
            return page.render(pageIx, filter.groups[pageIx], state, options, window, cx).intoAnyElement();
        }

        if (filter.visiblePages().length == 0) {
            return div()
                .sizeFull()
                .debugSelector(() -> 'settings-no-results')
                .child(renderNoResults())
                .intoAnyElement();
        }

        return div().intoAnyElement();
    }

    static function renderNoResults():IntoElement {
        return new Empty().sizeFull().header(
            new EmptyHeader()
                .media(
                    new EmptyMedia()
                        .withVariant(EmptyMediaVariant.Icon)
                        .child(new Icon(IconName.Search))
                )
                .title(new EmptyTitle().child(I18n.t('Settings.no_results')))
                .description(new EmptyDescription().child(I18n.t('Settings.no_results_description')))
        );
    }

    function renderSidebar(state:Entity<StateModel<SettingsState>>, filter:SettingsFilter, window:Window, cx:App):IntoElement {
        final selectedIndex = state.read(cx).value.selectedIndex;
        final searchInput = state.read(cx).value.searchInput;

        final menu = new SidebarMenu();
        final menuItems:Array<SidebarMenuItem> = [];
        for (pageIx in filter.visiblePages()) {
            final page = pagesValue[pageIx];
            final groups = filter.groups[pageIx];
            final isPageActive = selectedIndex.pageIx == pageIx
                && (selectedIndex.groupIx == null || groups.length == 1);
            final item = new SidebarMenuItem(page.titleValue)
                .clickToOpen(true);
            if (page.iconValue != null) item.icon(page.iconValue.clone());
            item
                .defaultOpen(page.defaultOpenValue)
                .active(isPageActive)
                .onClick((_, _, cx) -> {
                    state.update(cx, (state, cx) -> {
                        state.value.selectedIndex = new SelectIndex(pageIx, null);
                        state.value.deferredScrollGroupIx = null;
                        cx.notify();
                    });
                });
            if (groups.length > 1) {
                final children:Array<SidebarMenuItem> = [];
                for (groupIx in groups) {
                    if (page.groupsValue[groupIx].titleValue == null) continue;
                    final group = page.groupsValue[groupIx];
                    final isActive = selectedIndex.pageIx == pageIx && selectedIndex.groupIx == groupIx;
                    final title = group.titleValue != null ? group.titleValue : '';

                    children.push(new SidebarMenuItem(title).active(isActive).onClick((_, _, cx) -> {
                        state.update(cx, (state, cx) -> {
                            state.value.selectedIndex = new SelectIndex(pageIx, groupIx);
                            state.value.deferredScrollGroupIx = groupIx;
                            cx.notify();
                        });
                    }));
                }
                item.children(children);
            }
            menuItems.push(item);
        }
        menu.children(menuItems);

        final header = div()
            .wFull()
            .refineStyle(headerStyleValue)
            .child(new Input(searchInput).prefix(new Icon(IconName.Search)));

        final sidebar = new Sidebar<SidebarMenu>('settings-sidebar')
            .w(relative(1.))
            .border0()
            .refineStyle(sidebarStyleValue)
            .collapsible(false)
            .collapsed(false)
            .header(header)
            .child(menu);
        return sidebar;
    }

    public function render(window:Window, cx:App):IntoElement {
        final defaultSelectedIndex = defaultSelectedIndexValue;
        final state = window.useKeyedState(id, cx, window -> {
            final searchInput:Entity<InputState> = cx.newEntity(c -> new InputState(window, c)
                .withPlaceholder(I18n.t('Settings.search_placeholder'))
                .defaultValue(''));

            new SettingsState(searchInput, defaultSelectedIndex);
        });

        final query = state.read(cx).value.searchInput.read(cx).value();
        final filter = new SettingsFilter(pagesValue, query, cx);
        final previous = state.read(cx).value.selectedIndex;
        final selected = filter.selectedIndex(previous);
        if (selected.pageIx != previous.pageIx || selected.groupIx != previous.groupIx) {
            state.update(cx, (state, _) -> {
                state.value.selectedIndex = selected;
                state.value.deferredScrollGroupIx = null;
            });
        }
        final options = new RenderOptions()
            .withSize(sizeValue)
            .withGroupVariant(groupVariant);
        final sidebarSizeRange = sidebarSizeRangeValue;
        final sidebar = renderSidebar(state, filter, window, cx).intoAnyElement();

        return Resizable.hResizable(id)
            .child(
                Resizable.resizablePanel()
                    .size(sidebarWidthValue)
                    .sizeRange(sidebarSizeRange)
                    .child(sidebar)
            )
            .child(
                Resizable.resizablePanel().child(containerQuery((size, window, cx) -> {
                    final options = options.withLayout(size.width <= STACKED_LAYOUT_MAX_WIDTH ? Axis.Vertical : Axis.Horizontal);
                    return renderActivePage(state, filter, options, window, cx);
                }))
            );
    }

}

/**
 * Which page and group of the settings is selected.
 */
class SelectIndex {

    public final pageIx:Int;

    public final groupIx:Null<Int>;

    public function new(pageIx:Int = 0, ?groupIx:Int) {
        this.pageIx = pageIx;
        this.groupIx = groupIx;
    }

    public function toString():String {
        return 'SelectIndex($pageIx, $groupIx)';
    }

}

/**
 * Visible groups in each original page. Filtering never renumbers source data.
 */
@:allow(gpui.component.setting, tests)
class SettingsFilter {

    final groups:Array<Array<Int>>;

    function new(pages:Array<SettingPage>, query:String, cx:App) {
        groups = [for (page in pages) [for (ix in 0...page.groupsValue.length) if (page.groupsValue[ix].isMatch(query, cx)) ix]];
    }

    function visiblePages():Array<Int> {
        return [for (ix in 0...groups.length) if (groups[ix].length > 0) ix];
    }

    function selectedIndex(selected:SelectIndex):SelectIndex {
        final visible = visiblePages();
        var pageIx:Null<Int> = null;
        for (ix in visible) {
            if (ix == selected.pageIx) {
                pageIx = ix;
                break;
            }
        }
        if (pageIx == null && visible.length > 0) pageIx = visible[0];
        if (pageIx == null) {
            // Keep the selection while there are no results so clearing the query
            // can restore it. The empty filter prevents rendering a stale page.
            return selected;
        }

        final groupIx:Null<Int> = (selected.groupIx != null && pageIx == selected.pageIx && groups[pageIx].indexOf(selected.groupIx) >= 0) ? selected.groupIx : null;
        return new SelectIndex(pageIx, groupIx);
    }

}

/**
 * The keyed state of a `Settings`.
 */
@:allow(gpui.component.setting, tests)
class SettingsState {

    var selectedIndex:SelectIndex;

    /**
     * If set, defer scrolling to this group index after rendering.
     */
    var deferredScrollGroupIx:Null<Int> = null;

    final searchInput:Entity<InputState>;

    function new(searchInput:Entity<InputState>, selectedIndex:SelectIndex) {
        this.searchInput = searchInput;
        this.selectedIndex = selectedIndex;
    }

}
