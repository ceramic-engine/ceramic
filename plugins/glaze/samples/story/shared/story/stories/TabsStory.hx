// Ported from gpui-kit 0.8.1: crates/story/src/stories/tabs_story.rs
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
import glaze.ScrollHandle;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.button.ButtonGroup;
import glaze.kit.menu.PopupMenu;
import glaze.kit.tab.Tab;
import glaze.kit.tab.TabBar;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

@:action(namespace = tabs_story, noJson) private class ToggleMoreMenu implements Action {}

@:action(namespace = tabs_story, noJson) private class SetMaxTabWidth implements Action {
    public final value:Int;

    public function new(value:Int) {
        this.value = value;
    }
}

class TabsStory extends Model implements Story {

    /** The max tab widths to choose from in the story, `null` leaves tabs uncapped. */
    static final MAX_WIDTHS:Array<Null<Float>> = [null, 60., 90., 120., 160.];

    public static function title():String {
        return 'Tabs';
    }

    public static function description():String {
        return 'A set of layered sections of content\u2014known as tab panels\u2014that are displayed one at a time.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<TabsStory> {
        return cx.newEntity((c:Context<TabsStory>) -> new TabsStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var activeTabIx:Int = 0;

    @observe var dynamicActiveTabIx:Int = 0;

    @observe var dynamicTabs:Array<Int> = [0, 1, 2];

    var dynamicNextTabId:Int = 3;

    final dynamicScrollHandle = new ScrollHandle();

    @observe var size:Size = glaze.kit.Size.Medium;

    @observe var menu:Bool = false;

    @observe var maxWidthIx:Int = 0;

    function new(_:Window, cx:Context<TabsStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    function setActiveTab(ix:Int):Void {
        activeTabIx = ix;
    }

    function setDynamicActiveTab(ix:Int):Void {
        dynamicActiveTabIx = ix;
    }

    function addDynamicTab():Void {
        final id = dynamicNextTabId;
        dynamicNextTabId += 1;
        dynamicTabs = dynamicTabs.concat([id]);
        dynamicActiveTabIx = dynamicTabs.length - 1;
        dynamicScrollHandle.scrollToItem(dynamicActiveTabIx);
    }

    function removeLastDynamicTab():Void {
        if (dynamicTabs.length <= 1) {
            return;
        }
        dynamicTabs = dynamicTabs.slice(0, dynamicTabs.length - 1);
        if (dynamicActiveTabIx >= dynamicTabs.length) {
            dynamicActiveTabIx = dynamicTabs.length - 1;
        }
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    static function maxWidthLabel(width:Null<Float>):String {
        return width != null ? '${Math.round(width)}px' : 'Unlimited';
    }

    /** Rust `.when_some(max_width, |this, max_width| this.max_width(max_width))`. */
    static function withMaxWidth(bar:TabBar, maxWidth:Null<Float>):TabBar {
        return maxWidth != null ? bar.maxWidth(px(maxWidth)) : bar;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final maxWidth = MAX_WIDTHS[maxWidthIx];
        final maxWidthIx = this.maxWidthIx;
        final menu = this.menu;
        return vFlex()
            .wFull()
            .gap3()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .onAction(ToggleMoreMenu, (_, _, _) -> this.menu = !this.menu)
            .onAction(SetMaxTabWidth, (action, _, _) -> this.maxWidthIx = action.value)
            .child(storyToolbar(size)
                .dropdownChild(new Button('tabs-max-width').label('Max width: ${maxWidthLabel(MAX_WIDTHS[maxWidthIx])}'), (popup:PopupMenu, _, _) -> {
                    for (ix => width in MAX_WIDTHS) {
                        popup = popup.menuWithCheck(maxWidthLabel(width), ix == maxWidthIx, new SetMaxTabWidth(ix));
                    }
                    return popup;
                })
                .dropdownChild(new Button('tabs-options').label('Options'),
                    (popup, _, _) -> popup.menuWithCheck('More menu', menu, new ToggleMoreMenu())))
            .child(section('Tabs').wFull().child(withMaxWidth(new TabBar('tabs')
                .wFull()
                .withSize(size)
                .menu(menu), maxWidth)
                .selectedIndex(activeTabIx)
                .onClick((ix, _, _) -> setActiveTab(ix))
                .borderT1()
                .borderColor(theme.border)
                .prefix(hFlex()
                    .mx1()
                    .child(new Button('back').ghost().xsmall().icon(IconName.ArrowLeft))
                    .child(new Button('forward').ghost().xsmall().icon(IconName.ArrowRight)))
                .child(new Tab().label('Account'))
                .child(new Tab().label('Profile').disabled(true))
                .child(new Tab().label('Documents'))
                .child(new Tab().label('Mail'))
                .child(new Tab().label('Appearance'))
                .child(new Tab().label('Settings'))
                .child(new Tab().label('About'))
                .child(new Tab().label('License'))
                .suffix(hFlex()
                    .mx1()
                    .child(new Button('inbox').ghost().xsmall().icon(IconName.Inbox))
                    .child(new Button('more').ghost().xsmall().icon(IconName.Ellipsis)))))
            .child(section('Underline Tabs').wFull().child(withMaxWidth(new TabBar('underline')
                .wFull()
                .underline()
                .withSize(size)
                .menu(menu), maxWidth)
                .selectedIndex(activeTabIx)
                .onClick((ix, _, _) -> setActiveTab(ix))
                .child(Tab.fromLabel('Account'))
                .child(Tab.fromLabel('Profile'))
                .child(Tab.fromLabel('Documents'))
                .child(Tab.fromLabel('Mail'))
                .child(Tab.fromLabel('Appearance'))
                .child(Tab.fromLabel('Settings'))
                .child(Tab.fromLabel('About'))
                .child(Tab.fromLabel('License'))))
            .child(section('Pill Tabs').wFull().child(withMaxWidth(new TabBar('pill')
                .wFull()
                .pill()
                .withSize(size)
                .menu(menu), maxWidth)
                .selectedIndex(activeTabIx)
                .onClick((ix, _, _) -> setActiveTab(ix))
                .child(new Tab().label('Account'))
                .child(new Tab().label('Profile').disabled(true))
                .child(new Tab().label('Documents & Files'))
                .child(new Tab().label('Mail'))
                .child(new Tab().label('Appearance'))
                .child(new Tab().label('Settings'))
                .child(new Tab().label('About'))
                .child(new Tab().label('License'))))
            .child(section('Outline Tabs').wFull().child(withMaxWidth(new TabBar('outline')
                .wFull()
                .outline()
                .withSize(size)
                .menu(menu), maxWidth)
                .selectedIndex(activeTabIx)
                .onClick((ix, _, _) -> setActiveTab(ix))
                .child(new Tab().label('Account'))
                .child(new Tab().label('Profile').disabled(true))
                .child(new Tab().label('Documents & Files'))
                .child(new Tab().label('Mail'))
                .child(new Tab().label('Appearance'))
                .child(new Tab().label('Settings'))
                .child(new Tab().label('About'))
                .child(new Tab().label('License'))))
            .child(section('Segmented Tabs').wFull().child(withMaxWidth(new TabBar('segmented')
                .wFull()
                .segmented()
                .withSize(size)
                .menu(menu), maxWidth)
                .selectedIndex(activeTabIx)
                .onClick((ix, _, _) -> setActiveTab(ix))
                .child(Tab.fromIcon(new Icon(IconName.Bot)))
                .child(Tab.fromIcon(new Icon(IconName.Calendar)))
                .child(Tab.fromIcon(new Icon(IconName.Map)))
                .children([for (label in ['Appearance', 'Settings', 'About', 'License']) Tab.fromLabel(label)])))
            .child(section('Folder Tabs').wFull().child(vFlex()
                .wFull()
                .border1()
                .borderColor(theme.border)
                .rounded(theme.radiusLg)
                .overflowHidden()
                .child(withMaxWidth(new TabBar('folder')
                    .wFull()
                    .folder()
                    .withSize(size)
                    .menu(menu), maxWidth)
                    .selectedIndex(activeTabIx)
                    .onClick((ix, _, _) -> setActiveTab(ix))
                    .children([for (label in ['Account', 'Profile', 'Documents', 'Mail', 'Appearance', 'Settings', 'About', 'License'])
                        new Tab().label(label).suffix(new Button('folder-tab-close-$label').ghost().xsmall().icon(IconName.Close))])
                    .suffix(new Button('folder-new-tab').ghost().xsmall().mx1().icon(IconName.Plus)))
                .child(div().h20().bg(theme.tabActive))))
            .child(section('Dynamic Tabs')
                .description('Tabs can be added, removed, and composed with prefix and suffix content.')
                .wFull()
                .child(new ButtonGroup('dynamic-tab-actions')
                    .outline()
                    .compact()
                    .child(new Button('add-tab').label('Add Tab').onClick((_, _, _) -> addDynamicTab()))
                    .child(new Button('remove-tab').label('Remove Last').onClick((_, _, _) -> removeLastDynamicTab())))
                .child(withMaxWidth(new TabBar('segmented-dynamic')
                    .trackScroll(dynamicScrollHandle)
                    .wFull()
                    .segmented()
                    .withSize(size), maxWidth)
                    .selectedIndex(dynamicActiveTabIx)
                    .onClick((ix, _, _) -> setDynamicActiveTab(ix))
                    .children([for (ix => id in dynamicTabs) new Tab()
                        .px2()
                        .prefix(new Icon(IconName.BookOpen))
                        .label('Tab $id')
                        .suffix(new Button('dynamic-tab-close-$id').ghost().xsmall().icon(IconName.Close))
                        .selected(dynamicActiveTabIx == ix)])))
            .child(section('Filling Space')
                .description('Segmented tabs can share the available width equally.')
                .wFull()
                .child(withMaxWidth(new TabBar('flex tabs')
                    .wFull()
                    .segmented()
                    .withSize(size), maxWidth)
                    .selectedIndex(activeTabIx)
                    .onClick((ix, _, _) -> setActiveTab(ix))
                    .child(new Tab().flex1().label('About'))
                    .child(new Tab().flex1().label('Profile'))));
    }

}
