// Ported from gpui-kit 0.8.1: crates/story/src/stories/virtual_list_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.Action;
import glaze.Div;
import glaze.ScrollStrategy;
import glaze.kit.base.Scrollbar.ScrollbarAxis;
import glaze.kit.VirtualList;
import glaze.kit.VirtualList.VirtualListScrollHandle;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;
using glaze.kit.scroll.Scrollable;

/** Rust `VirtualListAction::Dataset(usize)`. */
@:action(namespace = virtual_list_story, name = Dataset, noJson) private class VirtualListDataset implements Action {
    public final value:Int;

    public function new(value:Int) {
        this.value = value;
    }
}

/** Rust `VirtualListAction::Both`. */
@:action(namespace = virtual_list_story, name = Both, noJson) private class VirtualListBoth implements Action {}

/** Rust `VirtualListAction::Vertical`. */
@:action(namespace = virtual_list_story, name = Vertical, noJson) private class VirtualListVertical implements Action {}

/** Rust `VirtualListAction::Horizontal`. */
@:action(namespace = virtual_list_story, name = Horizontal, noJson) private class VirtualListHorizontal implements Action {}

class VirtualListStory extends Model implements Story {

    static final ITEM_SIZE = new glaze.Size(100., 30.);

    static final DATASETS = ['Standard', 'Wide', 'Stress', 'Short'];

    public static function title():String {
        return 'VirtualList';
    }

    public static function description():String {
        return 'Add vertical or horizontal, or both scrollbars to a container, and use `virtual_list` to render a large number of items.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<VirtualListStory> {
        return cx.newEntity((c:Context<VirtualListStory>) -> new VirtualListStory(window, c));
    }

    final focusHandle_:FocusHandle;

    final scrollHandle = new VirtualListScrollHandle();

    @observe var items:Array<String>;

    @observe var itemSizes:Array<glaze.Size>;

    @observe var columnsCount:Int = 100;

    @observe var axis:ScrollbarAxis = ScrollbarAxis.Both;

    @observe var sizeMode:Int = 0;

    /** Written while the list renders, read on the next render (not observed, like the original). */
    var visibleStart:Int = 0;

    var visibleEnd:Int = 0;

    function new(_:Window, cx:Context<VirtualListStory>) {
        super();
        focusHandle_ = cx.focusHandle();
        items = [for (i in 0...5000) 'Item $i'];
        itemSizes = [for (_ in items) ITEM_SIZE];
    }

    public function changeTestCases(n:Int):Void {
        sizeMode = n;
        if (n == 0) {
            items = [for (i in 0...5000) 'Item $i'];
            columnsCount = 30;
        } else if (n == 1) {
            items = [for (i in 0...100) 'Item $i'];
            columnsCount = 100;
        } else if (n == 2) {
            items = [for (i in 0...500000) 'Item $i'];
            columnsCount = 100;
        } else {
            items = [for (i in 0...5) 'Item $i'];
            columnsCount = 10;
        }
        itemSizes = [for (_ in items) ITEM_SIZE];
    }

    public function changeAxis(axis:ScrollbarAxis):Void {
        this.axis = axis;
    }

    function renderButtons(cx:Context<Dynamic>):IntoElement {
        final selected = sizeMode;
        final axis = this.axis;
        final entity:Entity<VirtualListStory> = cast cx.entity();
        return vFlex()
            .gap2()
            .child(storyToolbarGroup()
                .dropdownChild(Button.component('virtual-list-dataset').label('Dataset: ${DATASETS[sizeMode]}'), (menu:PopupMenu, _, _) -> {
                    for (index => label in DATASETS) {
                        menu = menu.menuWithCheck(label, selected == index, new VirtualListDataset(index));
                    }
                    return menu;
                })
                .dropdownChild(Button.component('virtual-list-axis').label('Axis: ${axis.isBoth() ? 'Both' : axis.isVertical() ? 'Vertical' : 'Horizontal'}'),
                    (menu, _, _) -> menu
                        .menuWithCheck('Both', axis.isBoth(), new VirtualListBoth())
                        .menuWithCheck('Vertical', axis.isVertical(), new VirtualListVertical())
                        .menuWithCheck('Horizontal', axis.isHorizontal(), new VirtualListHorizontal()))
                .child(Button.component('scroll-to0').label('Top').onClick((_, _, cx) -> {
                    scrollHandle.scrollToItem(0, ScrollStrategy.Top);
                    entity.update(cx, (_, cx) -> cx.notify());
                }))
                .child(Button.component('scroll-to1').label('Row 50').onClick((_, _, cx) -> {
                    scrollHandle.scrollToItem(50, ScrollStrategy.Top);
                    entity.update(cx, (_, cx) -> cx.notify());
                }))
                .child(Button.component('scroll-to2').label('Center 25').onClick((_, _, cx) -> {
                    scrollHandle.scrollToItem(25, ScrollStrategy.Center);
                    entity.update(cx, (_, cx) -> cx.notify());
                }))
                .child(Button.component('scroll-to-bottom').label('Bottom').onClick((_, _, cx) -> {
                    scrollHandle.scrollToBottom();
                    entity.update(cx, (_, cx) -> cx.notify());
                })))
            .child('Visible: $visibleStart..$visibleEnd');
    }

    static function renderItem(cx:App):Div {
        return div()
            .flex()
            .hFull()
            .itemsCenter()
            .justifyCenter()
            .textSm()
            .w(px(ITEM_SIZE.width))
            .h(px(ITEM_SIZE.height))
            .bg(Theme.global(cx).secondary);
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final columnsCount = this.columnsCount;
        final entity:Entity<VirtualListStory> = cast cx.entity();
        return vFlex()
            .sizeFull()
            .gap4()
            .onAction(VirtualListDataset, (action, _, _) -> changeTestCases(action.value))
            .onAction(VirtualListBoth, (_, _, _) -> changeAxis(ScrollbarAxis.Both))
            .onAction(VirtualListVertical, (_, _, _) -> changeAxis(ScrollbarAxis.Vertical))
            .onAction(VirtualListHorizontal, (_, _, _) -> changeAxis(ScrollbarAxis.Horizontal))
            .child(renderButtons(cx))
            .child(div().wFull().flex1().minH64().child(div().relative().sizeFull().child(vFlex()
                .id('list')
                .relative()
                .sizeFull()
                .child(VirtualList.vVirtualList(entity, 'items', itemSizes, (story, start, end, _, cx) -> {
                    story.visibleStart = start;
                    story.visibleEnd = end;
                    return [for (ix in start...end) (hFlex().gap1().itemsCenter().children([for (i in 0...columnsCount) (renderItem(cx.app)
                        .child(i == 0 ? 'row: $ix' : '$i') : IntoElement)]) : IntoElement)];
                })
                    .trackScroll(scrollHandle)
                    .p4()
                    .border1()
                    .borderColor(theme.border)
                    .gap1())
                .scrollbar(scrollHandle, axis))));
    }

}
