// Ported from gpui-kit 0.8.1: crates/component/src/setting/page.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.setting;

import gpui.AnyElement;
import gpui.App;
import gpui.ElementId;
import gpui.Entity;
import gpui.IntoElement;
import gpui.ListAlignment;
import gpui.ListOffset;
import gpui.ListState;
import gpui.StyleRefinement;
import gpui.Window;
import gpui.Window.StateModel;
import gpui.base.ScrollBounce;
import gpui.component.I18n;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.button.Button;
import gpui.component.label.Label;
import gpui.component.setting.Settings.SelectIndex;
import gpui.component.setting.Settings.SettingsState;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.base.StyledExt;
using gpui.component.scroll.Scrollable;

/**
 * A setting page that can contain multiple setting groups.
 */
class SettingPage {

    @:allow(gpui.component.setting, tests)
    var iconValue:Null<Icon> = null;

    var resettableValue:Bool = true;

    @:allow(gpui.component.setting, tests)
    var defaultOpenValue:Bool = false;

    @:allow(gpui.component.setting, tests)
    var titleValue:String;

    @:allow(gpui.component.setting, tests)
    var titleSuffixValue:Null<(Window, App) -> AnyElement> = null;

    @:allow(gpui.component.setting, tests)
    var descriptionValue:Null<String> = null;

    @:allow(gpui.component.setting, tests)
    var groupsValue:Array<SettingGroup> = [];

    @:allow(gpui.component.setting, tests)
    var headerStyleValue:StyleRefinement = new StyleRefinement();

    public function new(title:String) {
        titleValue = title;
    }

    /**
     * Rust `Clone`.
     */
    public function clone():SettingPage {
        final copy = new SettingPage(titleValue);
        copy.iconValue = iconValue != null ? iconValue.clone() : null;
        copy.resettableValue = resettableValue;
        copy.defaultOpenValue = defaultOpenValue;
        copy.titleSuffixValue = titleSuffixValue;
        copy.descriptionValue = descriptionValue;
        copy.groupsValue = [for (group in groupsValue) group.clone()];
        final style = new StyleRefinement();
        style.refine(headerStyleValue);
        copy.headerStyleValue = style;
        return copy;
    }

    /**
     * Set the title of the setting page.
     */
    public function title(title:String):SettingPage {
        titleValue = title;
        return this;
    }

    /**
     * Set a custom element to render after the title in the page header.
     *
     * For example, an info icon button that opens the help documentation.
     */
    public function titleSuffix(suffix:(Window, App) -> IntoElement):SettingPage {
        titleSuffixValue = (window, cx) -> suffix(window, cx).intoAnyElement();
        return this;
    }

    /**
     * Set the icon of the setting page.
     */
    public function icon(icon:IntoIcon):SettingPage {
        iconValue = icon;
        return this;
    }

    /**
     * Set the description of the setting page, default is null.
     */
    public function description(description:String):SettingPage {
        descriptionValue = description;
        return this;
    }

    /**
     * Set the default open state of the setting page, default is false.
     */
    public function defaultOpen(defaultOpen:Bool):SettingPage {
        defaultOpenValue = defaultOpen;
        return this;
    }

    /**
     * Set whether the setting page is resettable, default is true.
     *
     * If true and the items in this page has changed, the reset button will appear.
     */
    public function resettable(resettable:Bool):SettingPage {
        resettableValue = resettable;
        return this;
    }

    /**
     * Add a setting group to the page.
     */
    public function group(group:SettingGroup):SettingPage {
        groupsValue.push(group);
        return this;
    }

    /**
     * Add multiple setting groups to the page.
     */
    public function groups(groups:Iterable<SettingGroup>):SettingPage {
        for (group in groups) groupsValue.push(group);
        return this;
    }

    /**
     * Set the style refinement for the header of the setting page.
     */
    public function headerStyle(style:StyleRefinement):SettingPage {
        final copy = new StyleRefinement();
        copy.refine(style);
        headerStyleValue = copy;
        return this;
    }

    function isResettable(query:String, cx:App):Bool {
        if (!resettableValue) return false;
        for (group in groupsValue) {
            if (group.isResettable(query, cx)) return true;
        }
        return false;
    }

    function resetAll(query:String, window:Window, cx:App):Void {
        for (group in groupsValue) {
            group.reset(query, window, cx);
        }
    }

    /**
     * The group the sidebar marks for the given scroll position: the titled
     * group at or above the top of the viewport. At the end of the list the
     * last groups cannot reach the top, so a group selected below the top
     * stays marked, and the last group is marked otherwise. `null` marks the
     * page itself.
     */
    @:allow(gpui.component.setting, tests)
    function groupAtScrollTop(groupIndices:Array<Int>, selectedGroupIx:Null<Int>, scrollTop:ListOffset, isScrolledToEnd:Bool):Null<Int> {
        final selectedPos:Null<Int> = if (selectedGroupIx != null) {
            final pos = groupIndices.indexOf(selectedGroupIx);
            pos >= 0 ? pos : null;
        } else {
            null;
        };
        if (isScrolledToEnd && selectedPos != null && selectedPos > scrollTop.itemIx) {
            return selectedGroupIx;
        }

        final topPos = if (isScrolledToEnd) {
            groupIndices.length > 0 ? groupIndices.length - 1 : 0;
        } else {
            scrollTop.itemIx;
        };
        final count = topPos + 1 < groupIndices.length ? topPos + 1 : groupIndices.length;
        var i = count - 1;
        while (i >= 0) {
            final ix = groupIndices[i];
            if (groupsValue[ix].titleValue != null) return ix;
            i--;
        }
        return null;
    }

    static function sameIndices(a:Array<Int>, b:Array<Int>):Bool {
        if (a.length != b.length) return false;
        for (i in 0...a.length) {
            if (a[i] != b[i]) return false;
        }
        return true;
    }

    @:allow(gpui.component.setting, tests)
    function render(ix:Int, groupIndices:Array<Int>, state:Entity<StateModel<SettingsState>>, options:RenderOptions, window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final searchInput = state.read(cx).value.searchInput;
        final query = searchInput.read(cx).value();
        final groups = [for (ix in groupIndices) {groupIx: ix, group: groupsValue[ix].clone()}];
        final groupsCount = groups.length;

        final pageState = window.useKeyedState('list-state:$ix', cx, _ -> new PageState(
            new ListState(groupsCount, ListAlignment.Top, 100.),
            query,
            groupIndices.copy(),
            new ListOffset(),
            false
        ));
        final changed = pageState.read(cx).value.query != query || !sameIndices(pageState.read(cx).value.groups, groupIndices);
        final listState = pageState.read(cx).value.list;
        if (changed) {
            pageState.update(cx, (state, _) -> {
                state.value.list.reset(groupsCount);
                state.value.query = query;
                state.value.groups = groupIndices.copy();
            });
        }

        final deferredScrollGroupIx = state.read(cx).value.deferredScrollGroupIx;
        final scrollGroupIx:Null<Int> = deferredScrollGroupIx != null ? deferredScrollGroupIx : (changed ? state.read(cx).value.selectedIndex.groupIx : null);
        if (deferredScrollGroupIx != null) {
            state.update(cx, (state, _) -> state.value.deferredScrollGroupIx = null);
        }
        if (scrollGroupIx != null) {
            final visibleIx = groupIndices.indexOf(scrollGroupIx);
            if (visibleIx >= 0) {
                // Scroll by index: after a page switch the list is rebuilt unmeasured,
                // and `scrollToRevealItem` would resolve to the top.
                listState.scrollTo(new ListOffset(visibleIx, 0.));
            }
        }

        // Follow the scroll position in the sidebar, like a table of contents.
        final scrollTop = listState.logicalScrollTop();
        final programmatic = changed || scrollGroupIx != null;
        final scrolled = !programmatic
            && !pageState.read(cx).value.scrolledProgrammatically
            && !pageState.read(cx).value.scrollTop.equals(scrollTop);
        pageState.update(cx, (state, _) -> {
            state.value.scrollTop = scrollTop;
            state.value.scrolledProgrammatically = programmatic;
        });
        if (scrolled) {
            final selectedGroupIx = state.read(cx).value.selectedIndex.groupIx;
            final groupIx = groupAtScrollTop(groupIndices, selectedGroupIx, scrollTop, listState.isScrolledToEnd() == true);
            if (groupIx != selectedGroupIx) {
                state.update(cx, (state, _) -> state.value.selectedIndex = new SelectIndex(state.value.selectedIndex.pageIx, groupIx));
                // The sidebar has already been rendered in this frame.
                window.refresh();
            }
        }

        final titleRow = hFlex()
            .gap1()
            .child(titleValue);
        if (titleSuffixValue != null) titleRow.child(titleSuffixValue(window, cx));
        final headerRow = hFlex()
            .justifyBetween()
            .child(titleRow);
        if (isResettable(query, cx)) {
            final page = clone();
            headerRow.child(
                new Button('reset')
                    .icon(IconName.Undo2)
                    .ghost()
                    .small()
                    .tooltip(I18n.t('Settings.Reset All'))
                    .onClick((_, window, cx) -> {
                        page.resetAll(query, window, cx);
                    })
            );
        }
        final header = vFlex()
            .p4()
            .gap3()
            .borderB1()
            .borderColor(theme.border)
            .refineStyle(headerStyleValue)
            .child(headerRow);
        if (descriptionValue != null) {
            header.child(
                new Label(descriptionValue)
                    .textSm()
                    .textColor(theme.mutedForeground)
            );
        }

        final pageIx = ix;
        final body = div()
            .relative()
            .flex1()
            .wFull()
            .child(new ScrollBounce('bounce', listState, list(listState, (visibleIx, window, cx) -> {
                final entry = groups[visibleIx];
                final groupIx = entry.groupIx;
                final group = entry.group.clone();
                // Keep horizontal padding inside the list's clip bounds
                // so focus rings can extend beyond the group's edges.
                group.py4();
                return div()
                    .wFull()
                    .px4()
                    .child(group.render(query, options.withPageIx(pageIx).withGroupIx(groupIx), window, cx))
                    .intoAnyElement();
            }).sizeFull()));
        body.verticalScrollbar(listState);

        return vFlex()
            .id(ElementId.Integer(ix))
            .sizeFull()
            .child(header)
            .child(body);
    }

}

/**
 * The keyed state of a page: its list and what it was last rendered with.
 */
@:allow(gpui.component.setting, tests)
class PageState {

    final list:ListState;

    var query:String;

    var groups:Array<Int>;

    /**
     * The scroll position seen by the last render.
     */
    var scrollTop:ListOffset;

    /**
     * Set when the page scrolls itself, so the clamping applied by the next
     * layout is not mistaken for the user moving through the page.
     */
    var scrolledProgrammatically:Bool;

    function new(list:ListState, query:String, groups:Array<Int>, scrollTop:ListOffset, scrolledProgrammatically:Bool) {
        this.list = list;
        this.query = query;
        this.groups = groups;
        this.scrollTop = scrollTop;
        this.scrolledProgrammatically = scrolledProgrammatically;
    }

}
