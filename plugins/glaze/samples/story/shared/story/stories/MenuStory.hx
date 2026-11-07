// Ported from gpui-kit 0.8.1: crates/story/src/stories/menu_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.Window;
import gpui.Action;
import gpui.Anchor;
import gpui.Div;
import gpui.KeyBinding;
import gpui.base.Geometry.Side;
import gpui.component.IconName;
import gpui.component.button.Button;
import gpui.component.menu.PopupMenu;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;
using gpui.component.menu.ContextMenu.ContextMenuExt;
using gpui.component.menu.DropdownMenu;

/** Rust `Info(usize)` (renamed: `Info` clashes with `ButtonVariant.Info`). */
@:action(namespace = menu_story, name = Info, noJson) private class InfoAction implements Action {
    public final value:Int;

    public function new(value:Int) {
        this.value = value;
    }
}

@:action(namespace = menu_story) private class Copy implements Action {}

@:action(namespace = menu_story) private class Paste implements Action {}

@:action(namespace = menu_story) private class Cut implements Action {}

@:action(namespace = menu_story) private class SearchAll implements Action {}

@:action(namespace = menu_story) private class ToggleCheck implements Action {}

class MenuStory extends Model implements Story {

    static inline final CONTEXT = 'menu_story';

    public static function title():String {
        return 'Menu';
    }

    public static function description():String {
        return 'Popup menu and context menu';
    }

    public static function init(cx:App):Void {
        final mac = isMacos();
        cx.bindKeys([
            new KeyBinding(mac ? 'cmd-c' : 'ctrl-c', new Copy(), CONTEXT),
            new KeyBinding(mac ? 'cmd-v' : 'ctrl-v', new Paste(), CONTEXT),
            new KeyBinding(mac ? 'cmd-x' : 'ctrl-x', new Cut(), CONTEXT),
            new KeyBinding(mac ? 'cmd-shift-f' : 'ctrl-shift-f', new SearchAll(), CONTEXT),
            new KeyBinding('ctrl-shift-alt-t', new ToggleCheck(), CONTEXT),
        ]);
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<MenuStory> {
        return cx.newEntity((c:Context<MenuStory>) -> new MenuStory(window, c));
    }

    @observe var checkSide:Null<Side> = null;

    @observe var message:String = '';

    function new(_:Window, _:Context<MenuStory>) {
        super();
    }

    function onCopy(_:Copy, _:Window, _:App):Void {
        message = 'You have clicked copy';
    }

    function onCut(_:Cut, _:Window, _:App):Void {
        message = 'You have clicked cut';
    }

    function onPaste(_:Paste, _:Window, _:App):Void {
        message = 'You have clicked paste';
    }

    function onSearchAll(_:SearchAll, _:Window, _:App):Void {
        message = 'You have clicked search all';
    }

    function onActionInfo(info:InfoAction, _:Window, _:App):Void {
        message = 'You have clicked info: ${info.value}';
    }

    function onActionToggleCheck(_:ToggleCheck, _:Window, _:App):Void {
        checkSide = if (checkSide == Side.Left) {
            Side.Right;
        } else if (checkSide == Side.Right) {
            null;
        } else {
            Side.Left;
        }
        message = 'You have used check at side: ${debugSide(checkSide)}';
    }

    /** Rust `{:?}` of an `Option<Side>`. */
    static function debugSide(side:Null<Side>):String {
        return side == null ? 'None' : side == Side.Left ? 'Some(Left)' : 'Some(Right)';
    }

    function contextArea(theme:Theme):Div {
        return div()
            .flex()
            .wFull()
            .p4()
            .itemsCenter()
            .justifyCenter()
            .minH20()
            .rounded(theme.radiusLg)
            .border2()
            .borderDashed()
            .borderColor(theme.border);
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final checkSide = this.checkSide;
        final view:Entity<MenuStory> = cast cx.entity();
        return vFlex()
            .keyContext(CONTEXT)
            .onAction(Copy, onCopy)
            .onAction(Cut, onCut)
            .onAction(Paste, onPaste)
            .onAction(SearchAll, onSearchAll)
            .onAction(InfoAction, onActionInfo)
            .onAction(ToggleCheck, onActionToggleCheck)
            .sizeFull()
            .minH(px(400.))
            .itemsCenter()
            .gap6()
            .child(section('Popup Menu')
                .description('Supports actions, links, checks, icons, custom rows, and nested menus.')
                .w(px(640.))
                .child(new Button('popup-menu-1')
                    .outline()
                    .label('Edit')
                    .dropdownMenu((this_, window, cx) -> this_.minW(250.)
                        .link('About', 'https://github.com/longbridge/gpui-kit')
                        .checkSide(checkSide != null ? checkSide : Side.Left)
                        .separator()
                        .item(PopupMenuItem.create('Handle Click').onClick((_, _, cx) -> view.update(cx, (this_, _) -> {
                            this_.message = 'You have clicked Handle Click';
                        })))
                        .separator()
                        .menu('Copy', new Copy())
                        .menu('Cut', new Cut())
                        .menu('Paste', new Paste())
                        .separator()
                        .menuWithCheck('Check Side ${debugSide(checkSide)}', checkSide != null, new ToggleCheck())
                        .separator()
                        .menuWithIcon('Search', IconName.Search, new SearchAll())
                        .separator()
                        .item(PopupMenuItem.element((_, cx) -> vFlex().child('Custom Element').child(div()
                            .textXs()
                            .textColor(Theme.global(cx).mutedForeground)
                            .child('This is sub-title')))
                            .onClick((_, _, cx) -> view.update(cx, (this_, _) -> {
                                this_.message = 'You have clicked on custom element';
                            })))
                        .menuElementWithCheck(checkSide != null, new ToggleCheck(), (_, cx) -> hFlex().gap1().child('Custom Element').child(div()
                            .textXs()
                            .textColor(Theme.global(cx).mutedForeground)
                            .child('checked')))
                        .menuElementWithIcon(IconName.Info, new InfoAction(0), (_, cx) -> hFlex().gap1().child('Custom').child(div()
                            .textSm()
                            .textColor(Theme.global(cx).mutedForeground)
                            .child('element')))
                        .separator()
                        .menuWithDisabled('Disabled Item', new InfoAction(0), true)
                        .separator()
                        .submenu('Links', window, cx, (menu, _, _) -> menu
                            .linkWithIcon('GPUI Component', IconName.Github, 'https://github.com/longbridge/gpui-kit')
                            .separator()
                            .link('GPUI Kit', 'https://gpui-kit.com')
                            .link('Zed', 'https://zed.dev'))
                        .separator()
                        .submenu('Other Links', window, cx, (menu, window, cx) -> menu
                            .link('Crates', 'https://crates.io')
                            .link('Rust Docs', 'https://docs.rs')
                            .separator()
                            .submenu('Nested', window, cx, (menu, window, cx) -> menu
                                .link('Docs.rs', 'https://docs.rs')
                                .separator()
                                .submenu('Deeper', window, cx, (menu, _, _) -> menu.link('GPUI Kit', 'https://gpui-kit.com'))))))
                .child(message))
            .child(section('Context Menu')
                .description('Different regions can provide their own right-click actions.')
                .w(px(640.))
                .vFlex()
                .gap4()
                .child(vFlex()
                    .wFull()
                    .p4()
                    .itemsCenter()
                    .justifyCenter()
                    .minH20()
                    .rounded(theme.radiusLg)
                    .border2()
                    .borderDashed()
                    .borderColor(theme.border)
                    .child('Right click to open ContextMenu')
                    .contextMenu((this_, window, cx) -> this_.checkSide(checkSide != null ? checkSide : Side.Left)
                        .externalLinkIcon(false)
                        .link('About', 'https://github.com/longbridge/gpui-kit')
                        .separator()
                        .menu('Cut', new Cut())
                        .menu('Copy', new Copy())
                        .menu('Paste', new Paste())
                        .separator()
                        .label('This is a label')
                        .menuWithCheck('Check Side ${debugSide(checkSide)}', checkSide != null, new ToggleCheck())
                        .separator()
                        // Deeply nested submenus to verify each
                        // level paints above the shallower ones and
                        // the background content behind them.
                        .submenu('Settings', window, cx, (menu, window, cx) -> menu
                            .menu('Info 0', new InfoAction(0))
                            .separator()
                            .menu('Item 1', new InfoAction(1))
                            .menu('Item 2', new InfoAction(2))
                            .separator()
                            .submenu('More', window, cx, (menu, window, cx) -> menu
                                .menu('More Item 1', new InfoAction(1))
                                .menu('More Item 2', new InfoAction(2))
                                .separator()
                                .submenu('Even More', window, cx, (menu, window, cx) -> menu
                                    .menu('Deep Item 1', new InfoAction(1))
                                    .menu('Deep Item 2', new InfoAction(2))
                                    .separator()
                                    .submenu('Deepest', window, cx, (menu, _, _) -> menu
                                        .menu('Leaf 1', new InfoAction(1))
                                        .menu('Leaf 2', new InfoAction(2))))))
                        .separator()
                        .menu('Search All', new SearchAll())
                        .separator())
                    .child(div()
                        .textSm()
                        .textColor(theme.mutedForeground)
                        .child('You can right click anywhere in this area to open the context menu.')))
                .child(contextArea(theme)
                    .id('other')
                    .child('Here is another area with context menu.')
                    .contextMenu((this_, _, _) -> this_
                        .link('About', 'https://github.com/longbridge/gpui-kit')
                        .separator()
                        .menu('Item 1', new InfoAction(1))))
                .child(contextArea(theme)
                    .id('other1')
                    .child('ContextMenu area 1')
                    .contextMenu((this_, _, _) -> this_
                        .link('About', 'https://github.com/longbridge/gpui-kit')
                        .separator()
                        .menu('Item 1', new InfoAction(1)))))
            .child(section('Scrollable')
                .description('Long menus constrain their height while short menus stay compact.')
                .w(px(640.))
                .child(new Button('dropdown-menu-scrollable-1')
                    .outline()
                    .label('Scrollable Menu (100 items)')
                    .dropdownMenuWithAnchor(Anchor.TopRight, (this_, window, cx) -> {
                        this_ = this_.scrollable(true).maxH(px(300.)).label('Total ${100} items');
                        for (i in 0...100) {
                            if (i % 5 == 0) {
                                this_ = this_.separator();
                            }
                            // Every tenth item is a submenu, so the
                            // scrolled list exercises submenus at
                            // every scroll position.
                            this_ = if (i % 10 == 9) {
                                this_.submenu('More $i', window, cx, (menu, _, _) -> menu
                                    .menu('Item $i copy', new InfoAction(i))
                                    .menu('Item $i duplicate', new InfoAction(i)));
                            } else {
                                this_.menu('Item $i', new InfoAction(i));
                            }
                        }
                        return this_.minW(px(100.));
                    }))
                .child(new Button('dropdown-menu-scrollable-2')
                    .outline()
                    .label('Scrollable Menu (5 items)')
                    .dropdownMenuWithAnchor(Anchor.TopRight, (this_, _, _) -> {
                        this_ = this_.scrollable(true).maxH(px(300.)).label('Total ${100} items');
                        for (i in 0...5) {
                            this_ = this_.menu('Item $i', new InfoAction(i));
                        }
                        return this_.minW(px(100.));
                    })));
    }

}
