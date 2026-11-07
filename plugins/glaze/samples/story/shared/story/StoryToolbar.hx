// Ported from gpui-kit 0.8.1: crates/story/src/lib.rs (StoryToolbar, StoryToolbarMenu, story_toolbar_group, story_toolbar)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import glaze.AnyElement;
import glaze.Anchor;
import glaze.App;
import glaze.Context;
import glaze.DismissEvent;
import glaze.Div;
import glaze.Entity;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu;
import glaze.kit.popover.Popover;

import glaze.Prelude.*;

/**
 * Rust `StoryMenuBuilder`.
 */
typedef StoryMenuBuilder = (PopupMenu, Window, Context<PopupMenu>) -> PopupMenu;

/**
 * Rust `enum StoryToolbarItem`.
 */
enum StoryToolbarItem {
    Button(button:glaze.kit.button.Button);
    Dropdown(button:glaze.kit.button.Button, builder:StoryMenuBuilder);
}

/**
 * A row of buttons joined into one segmented control, at the top right of a
 * story (`Lib.storyToolbarGroup()`, `Lib.storyToolbar(size)`).
 */
class StoryToolbar implements RenderOnce implements Styled {

    final base:Div;

    final items:Array<StoryToolbarItem> = [];

    public function new(base:Div) {
        this.base = base;
    }

    public function child(button:Button):StoryToolbar {
        items.push(StoryToolbarItem.Button(button));
        return this;
    }

    public function dropdownChild(button:Button, builder:StoryMenuBuilder):StoryToolbar {
        items.push(Dropdown(button, builder));
        return this;
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function render(window:Window, cx:App):IntoElement {
        final last = items.length > 0 ? items.length - 1 : 0;
        final children:Array<IntoElement> = [];
        for (ix in 0...items.length) {
            // Join the buttons into one segmented control: square off the
            // inner corners, and let each button after the first sit on its
            // neighbour's border instead of drawing a second one.
            final joined = (button:Button) -> {
                button.outline().small();
                if (ix > 0) button.roundedTl(glaze.Prelude.px(0.)).roundedBl(glaze.Prelude.px(0.)).borderL0();
                if (ix < last) button.roundedTr(glaze.Prelude.px(0.)).roundedBr(glaze.Prelude.px(0.));
                return button;
            };
            switch items[ix] {
                case Button(button):
                    children.push(joined(button));
                case Dropdown(button, builder):
                    children.push(new StoryToolbarMenu('story-toolbar-menu-$ix', joined(button), builder));
            }
        }
        for (child in children) base.child(child);
        return base;
    }

}

/**
 * Rust `StoryToolbarMenuState`.
 */
class StoryToolbarMenuState {

    public var menu:Null<Entity<PopupMenu>> = null;

    public function new() {}

}

/**
 * A toolbar button opening a menu.
 */
class StoryToolbarMenu implements RenderOnce {

    final id:String;

    final button:Button;

    final builder:StoryMenuBuilder;

    public function new(id:String, button:Button, builder:StoryMenuBuilder) {
        this.id = id;
        this.button = button;
        this.builder = builder;
    }

    public function render(window:Window, cx:App):IntoElement {
        final state = window.useKeyedState(id, cx, _ -> new StoryToolbarMenuState());
        final builder = this.builder;

        final popoverId = 'story-toolbar-popover-$id';

        return new Popover(popoverId)
            .appearance(false)
            .overlayClosable(false)
            .anchor(Anchor.TopRight)
            .trigger(button)
            .content((_, window, cx) -> {
                final current = state.read(cx).value.menu;
                if (current != null) {
                    return current;
                }

                final menu = PopupMenu.build(window, cx, (menu, window, cx) -> builder(menu, window, cx));
                state.read(cx).value.menu = menu;
                menu.read(cx).focusHandle.focus(window, cx.app);

                final popover = cx.weakEntity();
                window.subscribe(menu, DismissEvent, cx.app, (_, _, window, cx) -> {
                    final strong = popover.upgrade();
                    if (strong != null) {
                        strong.update(cx, (popover, cx) -> popover.dismiss(window, cx));
                    }
                    state.read(cx).value.menu = null;
                }).detach();

                return menu;
            });
    }

}
