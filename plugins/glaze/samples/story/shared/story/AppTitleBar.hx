// Ported from gpui-kit 0.8.1: crates/story/src/title_bar.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import glaze.Anchor;
import glaze.AnyElement;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.FontWeight;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseButton;
import glaze.Render;
import glaze.Window;
import glaze.kit.base.Geometry.Side;
import glaze.kit.base.theme.ScrollbarMode;
import glaze.kit.IconName;
import glaze.kit.TitleBar;
import glaze.kit.badge.Badge;
import glaze.kit.button.Button;
import glaze.kit.menu.AppMenuBar;
import glaze.kit.theme.Theme;
import story.StoryActions;

import glaze.Prelude.*;

using glaze.kit.WindowExt;
using glaze.kit.menu.DropdownMenu;

/**
 * The title bar of the gallery windows: the app menus (or the window
 * title), the settings menu, the GitHub button and the notifications bell.
 */
class AppTitleBar extends Model implements Render {

    final titleValue:String;

    final appMenuBar:Entity<AppMenuBar>;

    final fontSizeSelector:Entity<FontSizeSelector>;

    var childFn:(Window, App) -> AnyElement;

    public function new(title:String, window:Window, cx:Context<AppTitleBar>) {
        super();
        this.titleValue = title;
        this.appMenuBar = AppMenus.init(title, cx);
        this.fontSizeSelector = cx.newEntity((cx:Context<FontSizeSelector>) -> new FontSizeSelector(window, cx));
        this.childFn = (_, _) -> div().intoAnyElement();
    }

    public function child<E:IntoElement>(f:(Window, App) -> E):AppTitleBar {
        childFn = (window, cx) -> (f(window, cx) : IntoElement).intoAnyElement();
        return this;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final notificationsCount = window.notifications(cx.app).length;
        final showAppMenuBar = AppState.global(cx).showAppMenuBar;

        final left = div().flex().itemsCenter();
        if (showAppMenuBar) {
            left.child(appMenuBar);
        } else {
            // The system menu bar owns the menus, so the freed up left
            // side names the window the way a Mac app does.
            left.child(div().textSm().fontWeight(FontWeight.MEDIUM).child(titleValue));
        }

        return TitleBar.component()
            // left side
            .child(left)
            .child(div()
                .flex()
                .itemsCenter()
                .justifyEnd()
                .px2()
                .gap2()
                .onMouseDown(MouseButton.Left, (_, _, cx) -> cx.stopPropagation())
                .child(childFn(window, cx.app))
                .child(fontSizeSelector)
                .child(Button.component('github')
                    .icon(IconName.Github)
                    .small()
                    .ghost()
                    .onClick((_, _, cx) -> cx.openUrl('https://github.com/longbridge/gpui-kit')))
                .child(div().relative().child(Badge.component().count(notificationsCount).max(99).child(Button.component('bell')
                    .small()
                    .ghost()
                    .compact()
                    .icon(IconName.Bell)))));
    }

}

/**
 * The settings menu of the title bar: font size, radius, scrollbar mode,
 * list highlight, FPS monitor and app menu bar.
 */
class FontSizeSelector extends Model implements Render {

    final focusHandle:FocusHandle;

    public function new(_:Window, cx:Context<FontSizeSelector>) {
        super();
        focusHandle = cx.focusHandle();
    }

    function onSelectFont(fontSize:SelectFont, _:Window, cx:Context<FontSizeSelector>):Void {
        Theme.update(cx, theme -> theme.fontSize = fontSize.value);
    }

    function onSelectRadius(radius:SelectRadius, _:Window, cx:Context<FontSizeSelector>):Void {
        final radius:Float = radius.value;
        Theme.update(cx, theme -> {
            theme.radius = radius;
            theme.radiusLg = radius > 0. ? radius + 2. : 0.;
        });
    }

    function onSelectScrollbarMode(show:SelectScrollbarMode, window:Window, cx:Context<FontSizeSelector>):Void {
        Theme.setScrollbarMode(show.value, cx);
        window.refresh();
    }

    function onToggleListActiveHighlight(_:ToggleListActiveHighlight, _:Window, cx:Context<FontSizeSelector>):Void {
        Theme.update(cx, theme -> theme.listSettings.activeHighlight = !theme.listSettings.activeHighlight);
    }

    function onToggleFpsMonitor(_:ToggleFpsMonitor, window:Window, cx:Context<FontSizeSelector>):Void {
        final state = AppState.globalMut(cx);
        state.showFpsMonitor = !state.showFpsMonitor;
        window.refresh();
    }

    function onToggleAppMenuBar(_:ToggleAppMenuBar, window:Window, cx:Context<FontSizeSelector>):Void {
        final state = AppState.globalMut(cx);
        state.showAppMenuBar = !state.showAppMenuBar;
        window.refresh();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<FontSizeSelector> = cast cx;
        final focusHandle = this.focusHandle;
        final theme = Theme.global(cx);
        final fontSize = Std.int(theme.fontSize);
        final radius = Std.int(theme.radius);
        final scrollShow = theme.scrollbarMode;
        final activeHighlight = theme.listSettings.activeHighlight;
        final showFpsMonitor = AppState.global(cx).showFpsMonitor;
        final showAppMenuBar = AppState.global(cx).showAppMenuBar;

        return div()
            .id('font-size-selector')
            .trackFocus(focusHandle)
            .onAction(SelectFont, self.listener((this_:FontSizeSelector, a:SelectFont, w, c) -> this_.onSelectFont(a, w, c)))
            .onAction(SelectRadius, self.listener((this_:FontSizeSelector, a:SelectRadius, w, c) -> this_.onSelectRadius(a, w, c)))
            .onAction(SelectScrollbarMode, self.listener((this_:FontSizeSelector, a:SelectScrollbarMode, w, c) -> this_.onSelectScrollbarMode(a, w, c)))
            .onAction(ToggleListActiveHighlight, self.listener((this_:FontSizeSelector, a:ToggleListActiveHighlight, w, c) -> this_.onToggleListActiveHighlight(a, w, c)))
            .onAction(ToggleFpsMonitor, self.listener((this_:FontSizeSelector, a:ToggleFpsMonitor, w, c) -> this_.onToggleFpsMonitor(a, w, c)))
            .onAction(ToggleAppMenuBar, self.listener((this_:FontSizeSelector, a:ToggleAppMenuBar, w, c) -> this_.onToggleAppMenuBar(a, w, c)))
            .child(Button.component('btn')
                .small()
                .ghost()
                .icon(IconName.Settings2)
                .dropdownMenu((menu, window, cx) -> menu.checkSide(Side.Right)
                    .submenu('Font Size', window, cx, (menu, _, _) -> menu.checkSide(Side.Right)
                        .menuWithCheck('Large', fontSize == 18, new SelectFont(18))
                        .menuWithCheck('Medium (default)', fontSize == 16, new SelectFont(16))
                        .menuWithCheck('Small', fontSize == 14, new SelectFont(14)))
                    .submenu('Border Radius', window, cx, (menu, _, _) -> menu.checkSide(Side.Right)
                        .menuWithCheck('8px', radius == 8, new SelectRadius(8))
                        .menuWithCheck('6px (default)', radius == 6, new SelectRadius(6))
                        .menuWithCheck('4px', radius == 4, new SelectRadius(4))
                        .menuWithCheck('0px', radius == 0, new SelectRadius(0)))
                    .submenu('Scrollbar', window, cx, (menu, _, _) -> menu.checkSide(Side.Right)
                        .menuWithCheck('Scrolling to show', scrollShow == ScrollbarMode.Scrolling, new SelectScrollbarMode(ScrollbarMode.Scrolling))
                        .menuWithCheck('Hover to show', scrollShow == ScrollbarMode.Hover, new SelectScrollbarMode(ScrollbarMode.Hover))
                        .menuWithCheck('Always show', scrollShow == ScrollbarMode.Always, new SelectScrollbarMode(ScrollbarMode.Always)))
                    .separator()
                    .menuWithCheck('List Active Highlight', activeHighlight, new ToggleListActiveHighlight())
                    .menuWithCheck('FPS Monitor', showFpsMonitor, new ToggleFpsMonitor())
                    .menuWithCheck('App Menu Bar', showAppMenuBar, new ToggleAppMenuBar()))
                .anchor(Anchor.TopRight));
    }

}
