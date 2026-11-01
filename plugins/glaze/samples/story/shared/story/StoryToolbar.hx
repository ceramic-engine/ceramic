// Ported from gpui-kit 0.8.1: crates/story/src/lib.rs (StoryToolbar, StoryToolbarMenu, story_toolbar_group, story_toolbar)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import gpui.AnyElement;
import gpui.Anchor;
import gpui.App;
import gpui.Context;
import gpui.DismissEvent;
import gpui.Div;
import gpui.Entity;
import gpui.IntoElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.component.button.Button;
import gpui.component.menu.PopupMenu;
import gpui.component.popover.Popover;

import gpui.Prelude.*;

/**
 * Rust `StoryMenuBuilder`.
 */
typedef StoryMenuBuilder = (PopupMenu, Window, Context<PopupMenu>) -> PopupMenu;

/**
 * Rust `enum StoryToolbarItem`.
 */
enum StoryToolbarItem {
    Button(button:gpui.component.button.Button);
    Dropdown(button:gpui.component.button.Button, builder:StoryMenuBuilder);
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
                if (ix > 0) button.roundedTl(gpui.Prelude.px(0.)).roundedBl(gpui.Prelude.px(0.)).borderL0();
                if (ix < last) button.roundedTr(gpui.Prelude.px(0.)).roundedBr(gpui.Prelude.px(0.));
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
