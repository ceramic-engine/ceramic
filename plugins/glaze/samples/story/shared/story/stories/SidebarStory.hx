// Ported from gpui-kit 0.8.1: crates/story/src/stories/sidebar_story.rs
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
import gpui.Hsla;
import gpui.StyleBuilder;
import gpui.StyleRefinement;
import gpui.base.Geometry.Side;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.badge.Badge;
import gpui.component.breadcrumb.Breadcrumb;
import gpui.component.breadcrumb.Breadcrumb.BreadcrumbItem;
import gpui.component.button.Button;
import gpui.component.separator.Separator;
import gpui.component.sidebar.Sidebar;
import gpui.component.sidebar.Sidebar.SidebarCollapsible;
import gpui.component.sidebar.Sidebar.SidebarToggleButton;
import gpui.component.sidebar.SidebarFooter;
import gpui.component.sidebar.SidebarGroup;
import gpui.component.sidebar.SidebarHeader;
import gpui.component.sidebar.SidebarMenu;
import gpui.component.sidebar.SidebarMenu.SidebarMenuItem;
import gpui.component.switch_.Switch;
import gpui.component.theme.Color;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;
using gpui.component.ThemeStyled;
using gpui.component.sidebar.SidebarDropdownMenu;

@:action(namespace = sidebar_story, noJson) class SelectCompany implements Action {
    public final value:String;

    public function new(value:String) {
        this.value = value;
    }
}

/** Rust `SidebarOption::Icon`. */
@:action(namespace = sidebar_story, name = Icon, noJson) private class SidebarOptionIcon implements Action {}

/** Rust `SidebarOption::Offcanvas`. */
@:action(namespace = sidebar_story, name = Offcanvas, noJson) private class SidebarOptionOffcanvas implements Action {}

/** Rust `SidebarOption::None`. */
@:action(namespace = sidebar_story, name = None, noJson) private class SidebarOptionNone implements Action {}

/** Rust `SidebarOption::Right`. */
@:action(namespace = sidebar_story, name = Right, noJson) private class SidebarOptionRight implements Action {}

/** Rust `SidebarOption::ClickToOpen`. */
@:action(namespace = sidebar_story, name = ClickToOpen, noJson) private class SidebarOptionClickToOpen implements Action {}

/** Rust `SidebarOption::DynamicChildren`. */
@:action(namespace = sidebar_story, name = DynamicChildren, noJson) private class SidebarOptionDynamicChildren implements Action {}

private enum abstract Item(Int) to Int {
    var Playground;
    var Models;
    var Documentation;
    var Settings;
    var DesignEngineering;
    var SalesAndMarketing;
    var Travel;

    public function label():String {
        return switch (cast this:Item) {
            case Playground: 'Playground';
            case Models: 'Models';
            case Documentation: 'Documentation';
            case Settings: 'Settings';
            case DesignEngineering: 'Design Engineering';
            case SalesAndMarketing: 'Sales and Marketing';
            case Travel: 'Travel';
        }
    }

    public function isDisabled():Bool {
        return (cast this:Item) == Travel;
    }

    public function icon():IconName {
        return switch (cast this:Item) {
            case Playground: IconName.SquareTerminal;
            case Models: IconName.Bot;
            case Documentation: IconName.BookOpen;
            case Settings: IconName.Settings2;
            case DesignEngineering: IconName.Frame;
            case SalesAndMarketing: IconName.ChartPie;
            case Travel: IconName.Map;
        }
    }

    public function items():Array<SubItem> {
        return switch (cast this:Item) {
            case Playground: [SubItem.History, SubItem.Starred, SubItem.Settings];
            case Models: [SubItem.Genesis, SubItem.Explorer, SubItem.Quantum];
            case Documentation: [SubItem.Introduction, SubItem.GetStarted, SubItem.Tutorial, SubItem.Changelog];
            case Settings: [SubItem.General, SubItem.Team, SubItem.Billing, SubItem.Limits];
            case _: [];
        }
    }
}

private enum abstract SubItem(Int) to Int {
    var History;
    var Starred;
    var General;
    var Team;
    var Billing;
    var Limits;
    var Settings;
    var Genesis;
    var Explorer;
    var Quantum;
    var Introduction;
    var GetStarted;
    var Tutorial;
    var Changelog;

    public function label():String {
        return switch (cast this:SubItem) {
            case History: 'History';
            case Starred: 'Starred';
            case Settings: 'Settings';
            case Genesis: 'Genesis';
            case Explorer: 'Explorer';
            case Quantum: 'Quantum';
            case Introduction: 'Introduction';
            case GetStarted: 'Get Started';
            case Tutorial: 'Tutorial';
            case Changelog: 'Changelog';
            case Team: 'Team';
            case Billing: 'Billing';
            case Limits: 'Limits';
            case General: 'General';
        }
    }

    public function isDisabled():Bool {
        return (cast this:SubItem) == Quantum;
    }
}

class SidebarStory extends Model implements Story {

    public static function title():String {
        return 'Sidebar';
    }

    public static function description():String {
        return 'A composable, themeable and customizable sidebar component.';
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<SidebarStory> {
        return cx.newEntity((c:Context<SidebarStory>) -> new SidebarStory(window, c));
    }

    @observe var activeItems:Map<Int, Bool> = [(Item.Playground : Int) => true];

    @observe var lastActiveItem:Item = Item.Playground;

    @observe var activeSubitem:Null<SubItem> = null;

    @observe var collapsed:Bool = false;

    @observe var collapsible:SidebarCollapsible = SidebarCollapsible.Icon;

    @observe var side:Side = Side.Left;

    @observe var clickToOpenSubmenu:Bool = false;

    @observe var showDynamicChildren:Bool = false;

    final focusHandle_:FocusHandle;

    var checked:Bool = false;

    function new(_:Window, cx:Context<SidebarStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    /** Rust `Item::handler`. */
    function itemHandler(item:Item):Void {
        final next = activeItems.copy();
        if (next.exists(item)) {
            next.remove(item);
        } else {
            next.set(item, true);
        }
        activeItems = next;
        lastActiveItem = item;
        activeSubitem = null;
    }

    /** Rust `SubItem::handler`. */
    function subItemHandler(item:Item, subitem:SubItem):Void {
        trace('Clicked on item: ${item.label()}, child: ${subitem.label()}');
        final next = activeItems.copy();
        next.set(item, true);
        activeItems = next;
        lastActiveItem = item;
        activeSubitem = subitem;
    }

    function switchCheckedHandler(checked:Bool):Void {
        this.checked = checked;
    }

    function renderContent(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final collapsible = this.collapsible;
        final right = side == Side.Right;
        final clickToOpen = clickToOpenSubmenu;
        final dynamicChildren = showDynamicChildren;
        return vFlex()
            .wFull()
            .minH0()
            .flex1()
            .gap4()
            .child(hFlex()
                .wFull()
                .itemsStart()
                .justifyBetween()
                .gap4()
                .child(vFlex()
                    .minW0()
                    .gap1()
                    .child(div().text2xl().fontSemibold().child(lastActiveItem.label()))
                    .child(div().textSm().textColor(theme.mutedForeground).child('A quick view of your workspace activity.')))
                .child(storyToolbarGroup()
                    .wAuto()
                    .flexShrink0()
                    .dropdownChild(new Button('sidebar-options').label('Options'), (menu, _, _) -> menu
                        .menuWithCheck('Icon mode', collapsible == SidebarCollapsible.Icon, new SidebarOptionIcon())
                        .menuWithCheck('Offcanvas mode', collapsible == SidebarCollapsible.Offcanvas, new SidebarOptionOffcanvas())
                        .menuWithCheck('Fixed mode', collapsible == SidebarCollapsible.None, new SidebarOptionNone())
                        .separator()
                        .menuWithCheck('Right Side', right, new SidebarOptionRight())
                        .menuWithCheck('Click to Open', clickToOpen, new SidebarOptionClickToOpen())
                        .menuWithCheck('Dynamic Children', dynamicChildren, new SidebarOptionDynamicChildren()))))
            .child(hFlex().wFull().gap3().children([for (card in [
                ['Active projects', '12', '+2 this week'],
                ['Team members', '28', '4 online'],
                ['Tasks completed', '84%', '+6% this month'],
            ]) (vFlex()
                .minW0()
                .flex1()
                .gap2()
                .p4()
                .rounded(theme.radiusLg)
                .border1()
                .borderColor(theme.border)
                .child(div().textSm().textColor(theme.mutedForeground).child(card[0]))
                .child(div().text2xl().fontSemibold().child(card[1]))
                .child(div().textXs().textColor(theme.mutedForeground).child(card[2])) : IntoElement)]))
            .child(vFlex()
                .wFull()
                .minH0()
                .flex1()
                .mt2()
                .rounded(theme.radiusLg)
                .border1()
                .borderColor(theme.border)
                .child(hFlex()
                    .itemsCenter()
                    .justifyBetween()
                    .px4()
                    .py2()
                    .child(div().fontMedium().child('Recent activity'))
                    .child(div().textXs().textColor(theme.mutedForeground).child('Today')))
                .child(Separator.horizontal())
                .children([for (row in [
                    {icon: IconName.CircleCheck, title: 'Design review completed', time: '12 minutes ago'},
                    {icon: IconName.File, title: 'Project brief updated', time: '1 hour ago'},
                    {icon: IconName.CircleUser, title: 'Maya joined the workspace', time: '3 hours ago'},
                ]) (hFlex()
                    .itemsCenter()
                    .gap3()
                    .px4()
                    .py3()
                    .child(div()
                        .size8()
                        .flex()
                        .itemsCenter()
                        .justifyCenter()
                        .roundedFullStyle(cx.app)
                        .bg(theme.muted)
                        .child(new Icon(row.icon).small()))
                    .child(vFlex()
                        .minW0()
                        .flex1()
                        .gap0p5()
                        .child(div().textSm().child(row.title))
                        .child(div().textXs().textColor(theme.mutedForeground).child(row.time))) : IntoElement)]));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final groups:Array<Array<Item>> = [
            [Item.Playground, Item.Models, Item.Documentation, Item.Settings],
            [Item.DesignEngineering, Item.SalesAndMarketing, Item.Travel],
        ];
        final collapsible = this.collapsible;
        final iconCollapsed = collapsed && collapsible == SidebarCollapsible.Icon;
        final toggleCollapsed = collapsed && collapsible != SidebarCollapsible.None;
        final isRight = side == Side.Right;

        final logo = div()
            .flex()
            .itemsCenter()
            .justifyCenter()
            .rounded(theme.radius)
            .bg(theme.success)
            .textColor(theme.successForeground)
            .size8()
            .flexShrink0()
            .when(!iconCollapsed, this_ -> this_.child(new Icon(IconName.GalleryVerticalEnd)))
            .when(iconCollapsed, this_ -> this_.size4()
                .bg(theme.transparent)
                .textColor(theme.foreground)
                .child(new Icon(IconName.GalleryVerticalEnd)));
        final header = new SidebarHeader().child(logo);
        if (!iconCollapsed) {
            header.child(vFlex()
                .gap0()
                .textSm()
                .flex1()
                .lineHeight(relative(1.25))
                .overflowHidden()
                .textEllipsis()
                .child('Company Name')
                .child(div().child('Enterprise').textXs()));
            header.child(new Icon(IconName.ChevronsUpDown).size4().flexShrink0());
        }

        final platform = new SidebarMenu().children([for (ix => item in groups[0]) {
            final isActive = lastActiveItem == item && activeSubitem == null;
            final menuItem = new SidebarMenuItem(item.label())
                .icon(item.icon())
                .active(isActive)
                .defaultOpen(ix == 0)
                .clickToOpen(clickToOpenSubmenu);
            if (isActive) menuItem.border1().borderColor(Hsla.white());
            if (ix == 0) menuItem.contextMenu((this_, _, _) -> this_.link('About', 'https://github.com/longbridge/gpui-kit'));
            menuItem
                .children([for (subIx => subItem in item.items()) {
                    final sub = new SidebarMenuItem(subItem.label())
                        .active(activeSubitem == subItem)
                        .disable(subItem.isDisabled());
                    if (subIx == 0) {
                        final checked = this.checked;
                        sub.suffix((_, _) -> new Switch('switch')
                            .xsmall()
                            .checked(checked)
                            .onClick((checked, _, _) -> switchCheckedHandler(checked)))
                            .labelStyle(new StyleBuilder(new StyleRefinement()).textColor(Color.red500()).style())
                            .contextMenu((this_, _, _) -> this_.label('This is a label'));
                    }
                    sub.onClick((_, _, _) -> subItemHandler(item, subItem));
                }])
                .onClick((_, _, _) -> itemHandler(item));
        }]);

        final projects = new SidebarMenu().children([for (ix => item in groups[1]) {
            final isActive = lastActiveItem == item && activeSubitem == null;
            final menuItem = new SidebarMenuItem(item.label())
                .icon(item.icon())
                .active(isActive)
                .disable(item.isDisabled())
                .clickToOpen(clickToOpenSubmenu);
            if (ix == 0 && showDynamicChildren) {
                menuItem.defaultOpen(true).children([
                    new SidebarMenuItem('Child A').onClick((_, _, _) -> {}),
                    new SidebarMenuItem('Child B').onClick((_, _, _) -> {}),
                ]);
            }
            if (ix == 0) {
                menuItem.suffix((_, _) -> new Badge().dot().count(1).child(div().p0p5().child(new Icon(IconName.Bell))));
            }
            if (ix == 1) {
                menuItem.suffix((_, _) -> new Icon(IconName.Settings2));
            }
            menuItem.onClick((_, _, _) -> itemHandler(item));
        }]);

        final footer = new SidebarFooter()
            .justifyBetween()
            .child(hFlex()
                .gap2()
                .child(new Icon(IconName.CircleUser))
                .when(!iconCollapsed, this_ -> this_.child('Jason Lee')));
        if (!iconCollapsed) footer.child(new Icon(IconName.ChevronsUpDown).size4());

        final breadcrumb = new Breadcrumb()
            .child('Breadcrumb')
            .child(new BreadcrumbItem('Home').onClick((_, _, _) -> lastActiveItem = Item.Playground))
            .child(new BreadcrumbItem(lastActiveItem.label()).onClick((_, _, _) -> activeSubitem = null));
        if (activeSubitem != null) breadcrumb.child(new BreadcrumbItem(activeSubitem.label()));

        return hFlex()
            .onAction(SidebarOptionIcon, (_, _, _) -> this.collapsible = SidebarCollapsible.Icon)
            .onAction(SidebarOptionOffcanvas, (_, _, _) -> this.collapsible = SidebarCollapsible.Offcanvas)
            .onAction(SidebarOptionNone, (_, _, _) -> this.collapsible = SidebarCollapsible.None)
            .onAction(SidebarOptionRight, (_, _, _) -> side = side == Side.Right ? Side.Left : Side.Right)
            .onAction(SidebarOptionClickToOpen, (_, _, _) -> clickToOpenSubmenu = !clickToOpenSubmenu)
            .onAction(SidebarOptionDynamicChildren, (_, _, _) -> showDynamicChildren = !showDynamicChildren)
            .rounded(theme.radius)
            .border1()
            .borderColor(theme.border)
            .hFull()
            .when(isRight, this_ -> this_.flexRowReverse())
            .child(new Sidebar<SidebarGroup<SidebarMenu>>('sidebar-story')
                .side(side)
                .collapsible(collapsible)
                .collapsed(collapsed)
                .w(px(220.))
                .gap0()
                .header(header.dropdownMenu((menu, _, _) -> menu
                    .menu('Twitter Inc.', new SelectCompany('twitter'))
                    .menu('Meta Platforms', new SelectCompany('meta'))
                    .menu('Google Inc.', new SelectCompany('google'))))
                .child(new SidebarGroup<SidebarMenu>('Platform').child(platform))
                .child(new SidebarGroup<SidebarMenu>('Projects').child(projects))
                .footer(footer))
            .child(vFlex()
                .hFull()
                .flex1()
                .minW0()
                .overflowHidden()
                .gap4()
                .p4()
                .child(hFlex()
                    .itemsCenter()
                    .gap3()
                    .when(isRight && collapsible != SidebarCollapsible.None, this_ -> this_.flexRowReverse().justifyBetween())
                    .when(collapsible != SidebarCollapsible.None, this_ -> this_
                        .child(new SidebarToggleButton()
                            .side(side)
                            .collapsed(toggleCollapsed)
                            .onClick((_, _, _) -> collapsed = !collapsed))
                        .child(Separator.vertical().h4()))
                    .child(breadcrumb))
                .child(renderContent(window, cx)));
    }

}
