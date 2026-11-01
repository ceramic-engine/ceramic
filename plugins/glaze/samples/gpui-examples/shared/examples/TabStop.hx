// Ported from gpui-pre 0.3.10: examples/tab_stop.rs (Example, actions Tab / TabPrev, run_example)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package examples;

import gpui.Action;
import gpui.App;
import gpui.Context;
import gpui.Div;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.Model;
import gpui.Render;
import gpui.StyleBuilder;
import gpui.Window;

import gpui.Prelude.*;

// actions!(example, [Tab, TabPrev]);
@:action(namespace = example) class Tab implements Action {}
@:action(namespace = example) class TabPrev implements Action {}

/**
 * The view of `tab_stop.rs` (named `Example` there).
 */
class TabStop extends Model implements Render {

    public static inline var WIDTH:Float = 800.0;

    public static inline var HEIGHT:Float = 600.0;

    public final focusHandle:FocusHandle;

    public final items:Array<FocusHandle>;

    @observe public var message:String;

    public function new(window:Window, cx:Context<TabStop>) {
        super();
        final items = [
            cx.focusHandle().tabIndex(1).tabStop(true),
            cx.focusHandle().tabIndex(2).tabStop(true),
            cx.focusHandle().tabIndex(3).tabStop(true),
            cx.focusHandle(),
            cx.focusHandle().tabIndex(2).tabStop(true),
        ];

        final focusHandle = cx.focusHandle();
        window.focus(focusHandle, cx.app);

        this.focusHandle = focusHandle;
        this.items = items;
        this.message = 'Press `Tab`, `Shift-Tab` to switch focus.';
    }

    function onTab(_:Tab, window:Window, cx:Context<TabStop>):Void {
        window.focusNext(cx.app);
        message = 'You have pressed `Tab`.';
    }

    function onTabPrev(_:TabPrev, window:Window, cx:Context<TabStop>):Void {
        window.focusPrev(cx.app);
        message = 'You have pressed `Shift-Tab`.';
    }

    // `fn tab_stop_style<T: Styled>(this: T) -> T`: the builder methods of
    // `Styled` return the concrete type in the port, so there is one function
    // per type (`Div` for `when`, `StyleBuilder` for `focus`).
    static function tabStopStyle(this_:Div):Div {
        return this_.border3().borderColor(blue());
    }

    static function tabStopStyleRefinement(this_:StyleBuilder):StyleBuilder {
        return this_.border3().borderColor(blue());
    }

    static function button(id:ElementIdArg):Div {
        return div()
            .id(id)
            .h10()
            .flex1()
            .flex()
            .justifyCenter()
            .itemsCenter()
            .border1()
            .borderColor(black())
            .bg(black())
            .textColor(white())
            .focus(tabStopStyleRefinement)
            .shadowSm();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<TabStop> = cast cx;
        return div()
            .id('app')
            .trackFocus(focusHandle)
            .onAction(Tab, cx.listener((this_:TabStop, action:Tab, window, cx) -> this_.onTab(action, window, cx)))
            .onAction(TabPrev, cx.listener((this_:TabStop, action:TabPrev, window, cx) -> this_.onTabPrev(action, window, cx)))
            .sizeFull()
            .flex()
            .flexCol()
            .p4()
            .gap3()
            .bg(white())
            .textColor(black())
            .child(message)
            .children(
                [for (ix => itemHandle in items.copy()) {
                    div()
                        .id(ElementId.NamedInteger('item', ix))
                        .trackFocus(itemHandle)
                        .h10()
                        .wFull()
                        .flex()
                        .justifyCenter()
                        .itemsCenter()
                        .border1()
                        .borderColor(black())
                        .when(
                            itemHandle.isTabStop && itemHandle.isFocused(window),
                            tabStopStyle
                        )
                        .map(this_ -> switch itemHandle.isTabStop {
                            case true: this_
                                .hover(this_ -> this_.bg(black().opacity(0.1)))
                                .child('tab_index: ${itemHandle.tabIndexValue}');
                            case false: this_.opacity(0.4).child('tab_stop: false');
                        });
                }]
            )
            .child(
                div()
                    .flex()
                    .flexRow()
                    .gap3()
                    .itemsCenter()
                    .child(
                        button('el1')
                            .tabIndex(4)
                            .child('Button 1')
                            .onClick(cx.listener((this_:TabStop, _, _, cx) -> {
                                this_.message = 'You have clicked Button 1.';
                                cx.notify();
                            }))
                    )
                    .child(
                        button('el2')
                            .tabIndex(5)
                            .child('Button 2')
                            .onClick(cx.listener((this_:TabStop, _, _, cx) -> {
                                this_.message = 'You have clicked Button 2.';
                                cx.notify();
                            }))
                    )
            )
            .child(
                div()
                    .id('group-1')
                    .tabIndex(6)
                    .tabGroup()
                    .tabStop(false)
                    .child(
                        button('group-1-button-1')
                            .tabIndex(1)
                            .child('Tab index [6, 1]')
                    )
                    .child(
                        button('group-1-button-2')
                            .tabIndex(2)
                            .child('Tab index [6, 2]')
                    )
                    .child(
                        button('group-1-button-3')
                            .tabIndex(3)
                            .child('Tab index [6, 3]')
                    )
            )
            .child(
                div()
                    .id('group-2')
                    .tabIndex(7)
                    .tabGroup()
                    .tabStop(false)
                    .child(
                        button('group-2-button-1')
                            .tabIndex(1)
                            .child('Tab index [7, 1]')
                    )
                    .child(
                        button('group-2-button-2')
                            .tabIndex(2)
                            .child('Tab index [7, 2]')
                    )
                    .child(
                        button('group-2-button-3')
                            .tabIndex(3)
                            .child('Tab index [7, 3]')
                    )
            );
    }

    /**
     * The key bindings of `run_example`.
     */
    public static function setup(cx:App):Void {
        cx.bindKeys([
            new KeyBinding('tab', new Tab(), null),
            new KeyBinding('shift-tab', new TabPrev(), null),
        ]);
    }

    /**
     * The root view of `run_example`'s window.
     */
    public static function open(window:Window, cx:App):Entity<TabStop> {
        return cx.newEntity((cx:Context<TabStop>) -> new TabStop(window, cx));
    }

}
