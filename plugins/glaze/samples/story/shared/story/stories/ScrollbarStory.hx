// Ported from gpui-kit 0.8.1: crates/story/src/stories/scrollbar_story.rs
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
import glaze.Pixels;
import glaze.UniformListScrollHandle;
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

@:action(namespace = scrollbar_story, noJson) private class ChangeDataset implements Action {
    public final value:Int;

    public function new(value:Int) {
        this.value = value;
    }
}

class ScrollbarStory extends Model implements Story {

    public static function title():String {
        return 'Scrollbar';
    }

    public static function description():String {
        return 'Add scrollbar to a scrollable element.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<ScrollbarStory> {
        return cx.newEntity((c:Context<ScrollbarStory>) -> new ScrollbarStory(window, c));
    }

    static final ITEM_HEIGHT:Pixels = 50.;

    static final DATASETS = ['Standard', 'Wide', 'Stress', 'Short'];

    final focusHandle_:FocusHandle;

    @observe var items:Array<String>;

    var itemSizes:Array<glaze.Size>;

    var testWidth:Pixels;

    @observe var sizeMode:Int = 0;

    final scrollHandle = new UniformListScrollHandle();

    function new(_:Window, cx:Context<ScrollbarStory>) {
        super();
        focusHandle_ = cx.focusHandle();
        items = [for (i in 0...5000) 'Item $i'];
        testWidth = 3000.;
        itemSizes = [for (_ in items) size(testWidth, ITEM_HEIGHT)];
    }

    public function changeTestCases(n:Int):Void {
        sizeMode = n;
        if (n == 0) {
            items = [for (i in 0...5000) 'Item $i'];
            testWidth = 3000.;
        } else if (n == 1) {
            items = [for (i in 0...100) 'Item $i'];
            testWidth = 10000.;
        } else if (n == 2) {
            items = [for (i in 0...500000) 'Item $i'];
            testWidth = 10000.;
        } else {
            items = [for (i in 0...5) 'Item $i'];
            testWidth = 10000.;
        }
        itemSizes = [for (_ in items) size(testWidth, ITEM_HEIGHT)];
        // Rust notifies here: `items` and `sizeMode` are observed.
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final selected = sizeMode;
        final items = this.items;
        return vFlex()
            .sizeFull()
            .gap4()
            .onAction(ChangeDataset, (action, _, _) -> changeTestCases(action.value))
            .child(storyToolbarGroup().dropdownChild(new Button('scrollbar-dataset').label('Dataset: ${DATASETS[sizeMode]}'),
                (menu:PopupMenu, _, _) -> {
                    for (index => label in DATASETS) {
                        menu = menu.menuWithCheck(label, selected == index, new ChangeDataset(index));
                    }
                    return menu;
                }))
            .child(div()
                .relative()
                .border1()
                .borderColor(theme.border)
                .flex1()
                .child(uniformList('list', items.length, (start, end, _, cx) -> {
                    final theme = Theme.global(cx);
                    return [for (ix in start...end) (div()
                        .h(ITEM_HEIGHT)
                        .pt1()
                        .itemsCenter()
                        .justifyCenter()
                        .textSm()
                        .child(div().p2().bg(theme.secondary).child(items[ix])) : IntoElement)];
                })
                    .py1()
                    .px3()
                    .sizeFull()
                    .trackScroll(scrollHandle))
                .verticalScrollbar(scrollHandle));
    }

}
