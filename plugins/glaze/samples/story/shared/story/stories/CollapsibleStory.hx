// Ported from gpui-kit 0.8.1: crates/story/src/stories/collapsible_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.AnyView;
import glaze.App;
import glaze.AppContext;
import glaze.Context;
import glaze.Div;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.avatar.Avatar;
import glaze.kit.button.Button;
import glaze.kit.checkbox.Checkbox;
import glaze.kit.collapsible.Collapsible;
import glaze.kit.groupbox.GroupBox;
import glaze.kit.progress.Progress;
import glaze.kit.tag.Tag;
import glaze.kit.theme.Theme;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.base.StyledExt;

class CollapsibleStory extends Model implements Story {

    // Keys of the panels, each one tracks its own open state.
    static inline final ORDER = 'order';
    static inline final FAQ = 'faq';
    static inline final USAGE = 'usage';
    static inline final SETTINGS = 'settings';
    static inline final API_KEYS = 'api-keys';
    static inline final COMPONENTS_DIR = 'components-dir';
    static inline final UI_DIR = 'ui-dir';
    static inline final PROFILE = 'profile';

    /** Order details, as (title, value) pairs. */
    static final ORDER_DETAILS:Array<Array<String>> = [
        ['Shipping address', '100 Market St, San Francisco'],
        ['Items', '2x Studio Headphones'],
    ];

    /** The usage breakdown of the billing example, as (label, value) pairs. */
    static final USAGE_ITEMS:Array<Array<String>> = [
        ['Requests', '$210.84'],
        ['Active CPU', '$21.95'],
        ['Events', '$21.20'],
        ['Storage', '$20.45'],
    ];

    /** The settings rows, as (key, label) pairs. */
    static final NOTIFICATIONS:Array<Array<String>> = [
        ['push', 'Push notifications'],
        ['email', 'Email notifications'],
        ['sms', 'SMS notifications'],
    ];

    /** The keys listed by the row actions example, as (name, key) pairs. */
    static final API_KEY_ROWS:Array<Array<String>> = [
        ['Production', 'PRDK230454*242SDIFPPL'],
        ['Development', 'DUILO30454*242SDIFUIP'],
        ['Staging', 'IPPODAS230454*242SDI'],
    ];

    /** The profile fields, as (icon, label, value) triples. */
    static final PROFILE_FIELDS:Array<{icon:IconName, label:String, value:String}> = [
        {icon: IconName.Inbox, label: 'Last activity', value: '2 hours ago'},
        {icon: IconName.Calendar, label: 'Online since', value: 'Today, 9:00 AM'},
        {icon: IconName.Globe, label: 'Location', value: 'Hong Kong'},
    ];

    /** A bordered row that frames a piece of summary content. */
    static function panelRow(cx:App):Div {
        final theme = Theme.global(cx);
        return hFlex()
            .px3()
            .py2()
            .gap2()
            .itemsCenter()
            .rounded(theme.radiusLg)
            .border1()
            .borderColor(theme.border)
            .textSm();
    }

    /** The chevron of a row trigger: pointing right when collapsed, down when open. */
    static function chevron(open:Bool, cx:App):Icon {
        return Icon.component(open ? IconName.ChevronDown : IconName.ChevronRight)
            .xsmall()
            .textColor(Theme.global(cx).mutedForeground);
    }

    /** A leaf row of the tree example: a file icon and its name. */
    static function fileRow(name:String, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final accent = theme.accent;

        return hFlex()
            .h7()
            .px2()
            .gap2()
            .itemsCenter()
            .rounded(theme.radius)
            .hover(s -> s.bg(accent))
            .textSm()
            // Aligns the name with the folder names, which are preceded by a chevron.
            .child(div().w3())
            .child(Icon.component(IconName.File)
                .xsmall()
                .textColor(theme.mutedForeground))
            .child(name);
    }

    final focusHandle:FocusHandle;

    /** Keys of the panels that are expanded. */
    final openKeys:Map<String, Bool>;

    /** Keys of the settings rows that are checked. */
    final checked:Map<String, Bool>;

    public static function title():String {
        return 'Collapsible';
    }

    public static function description():String {
        return 'An interactive element that expands/collapses.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    function new(_:Window, cx:AppContext) {
        super();
        focusHandle = cx.focusHandle();
        openKeys = [SETTINGS => true, API_KEYS => true, COMPONENTS_DIR => true, PROFILE => true];
        checked = ['push' => true];
    }

    public static function view(window:Window, cx:App):Entity<CollapsibleStory> {
        return cx.newEntity((cx:Context<CollapsibleStory>) -> new CollapsibleStory(window, cx));
    }

    function isOpen(key:String):Bool {
        return openKeys.exists(key);
    }

    function toggle(key:String, cx:Context<CollapsibleStory>):Void {
        if (!openKeys.remove(key)) {
            openKeys.set(key, true);
        }
        cx.notify();
    }

    /** A row that toggles `key` when clicked anywhere along it. */
    function triggerRow(key:String, cx:Context<CollapsibleStory>):Div {
        return hFlex()
            .id(key)
            .wFull()
            .itemsCenter()
            .onClick(cx.listener((this_:CollapsibleStory, _, _, cx) -> this_.toggle(key, cx)));
    }

    /** A folder row of the tree example, the whole row toggles the folder. */
    function folderRow(key:String, name:String, cx:Context<CollapsibleStory>):IntoElement {
        final open = isOpen(key);
        final theme = Theme.global(cx);
        final accent = theme.accent;
        final mutedForeground = theme.mutedForeground;
        final radius = theme.radius;

        return triggerRow(key, cx)
            .h7()
            .px2()
            .gap2()
            .rounded(radius)
            .hover(s -> s.bg(accent))
            .textSm()
            .child(chevron(open, cx.app))
            .child(Icon.component(open ? IconName.FolderOpen : IconName.Folder)
                .xsmall()
                .textColor(mutedForeground))
            .child(name);
    }

    /** A trigger beside the title, with a summary row that stays visible. */
    function renderBasic(cx:Context<CollapsibleStory>):IntoElement {
        final theme = Theme.global(cx);
        final mutedForeground = theme.mutedForeground;

        return section('Basic')
            .description('A trigger beside the title, with a summary that stays visible.')
            .w(px(360.))
            .vFlex()
            .child(Collapsible.component()
                .wFull()
                .gap2()
                .open(isOpen(ORDER))
                .child(hFlex()
                    .px1()
                    .justifyBetween()
                    .itemsCenter()
                    .gap4()
                    .child(div().textSm().fontSemibold().child('Order #4189'))
                    .child(Button.component(ORDER)
                        .ghost()
                        .xsmall()
                        .icon(IconName.ChevronsUpDown)
                        .tooltip('Toggle details')
                        .onClick(cx.listener((this_:CollapsibleStory, _, _, cx) -> this_.toggle(ORDER, cx)))))
                .child(panelRow(cx.app)
                    .justifyBetween()
                    .bg(theme.muted.opacity(0.3))
                    .child(div().textColor(mutedForeground).child('Status'))
                    .child(Tag.success().small().child('Shipped')))
                .content(vFlex()
                    .gap2()
                    .children([for (detail in ORDER_DETAILS) (panelRow(cx.app)
                        .vFlex()
                        .itemsStart()
                        .gap0()
                        .child(div().fontMedium().child(detail[0]))
                        .child(div().textColor(mutedForeground).child(detail[1])) : IntoElement)])));
    }

    /** The whole row acts as the trigger. */
    function renderRowTrigger(cx:Context<CollapsibleStory>):IntoElement {
        final mutedForeground = Theme.global(cx).mutedForeground;

        return section('Row trigger')
            .description('The whole row is the trigger, as used by FAQ entries.')
            .w(px(360.))
            .vFlex()
            .child(GroupBox.component().outline().wFull().child(Collapsible.component()
                .wFull()
                .open(isOpen(FAQ))
                .child(triggerRow(FAQ, cx)
                    .justifyBetween()
                    .gap2()
                    .child(div().textSm().child('How do I reset my password?'))
                    .child(chevron(isOpen(FAQ), cx.app)))
                .content(div().pt3().textSm().textColor(mutedForeground).child('Click the Forgot Password link on the sign in page, '
                    + 'and we will send you an email with instructions to '
                    + 'create a new one.'))));
    }

    /** A round trigger sitting on the bottom edge of a card. */
    function renderBottomTrigger(cx:Context<CollapsibleStory>):IntoElement {
        final open = isOpen(USAGE);
        final theme = Theme.global(cx);
        final mutedForeground = theme.mutedForeground;

        return section('Bottom trigger')
            .description('The trigger sits on the bottom edge of the card it opens.')
            .w(px(360.))
            .vFlex()
            .child(div()
                .relative()
                .wFull()
                .child(GroupBox.component()
                    .outline()
                    .wFull()
                    .title(hFlex()
                        .wFull()
                        .justifyBetween()
                        .itemsCenter()
                        .child(div().textSm().child('3 days remaining in cycle'))
                        .child(Button.component('billing').outline().xsmall().label('Billing')))
                    .child(Collapsible.component()
                        .wFull()
                        .gap3()
                        .open(open)
                        .child(panelRow(cx.app)
                            .vFlex()
                            .itemsStretch()
                            .gap2()
                            .bg(theme.muted.opacity(0.6))
                            .child(hFlex()
                                .justifyBetween()
                                .fontMedium()
                                .child('$18.08 / $20')
                                .child('$200'))
                            .child(Progress.component(USAGE).value(90.)))
                        .content(vFlex().gap2().children([for (item in USAGE_ITEMS) (hFlex()
                            .justifyBetween()
                            .textXs()
                            .fontMedium()
                            .child(div().textColor(mutedForeground).child(item[0]))
                            .child(item[1]) : IntoElement)]))))
                .child(hFlex()
                    .absolute()
                    .bottom(px(-12.))
                    .left0()
                    .right0()
                    .justifyCenter()
                    .child(Button.component('toggle-usage')
                        .outline()
                        .xsmall()
                        .rounded(theme.radiusFull())
                        .bg(theme.background)
                        .icon(open ? IconName.ChevronUp : IconName.ChevronDown)
                        .tooltip('Toggle details')
                        .onClick(cx.listener((this_:CollapsibleStory, _, _, cx) -> this_.toggle(USAGE, cx))))));
    }

    /** Optional settings held behind a full width trigger. */
    function renderSettings(cx:Context<CollapsibleStory>):IntoElement {
        final theme = Theme.global(cx);
        final border = theme.border;

        final rows:Array<IntoElement> = [];
        for (ix in 0...NOTIFICATIONS.length) {
            final key = NOTIFICATIONS[ix][0];
            final label = NOTIFICATIONS[ix][1];
            final row = hFlex().px3().py2();
            if (ix > 0) row.borderT1().borderColor(border);
            row.child(Checkbox.component(key)
                .label(label)
                .checked(checked.exists(key))
                .onClick(cx.listener((this_:CollapsibleStory, checked:Bool, _, cx) -> {
                    if (checked) {
                        this_.checked.set(key, true);
                    } else {
                        this_.checked.remove(key);
                    }
                    cx.notify();
                })));
            rows.push(row);
        }

        return section('Settings')
            .description('Holds optional controls, keeping the default view short.')
            .w(px(360.))
            .vFlex()
            .child(Collapsible.component()
                .wFull()
                .gap2()
                .open(isOpen(SETTINGS))
                .child(Button.component(SETTINGS)
                    .outline()
                    .wFull()
                    .justifyStart()
                    .icon(chevron(isOpen(SETTINGS), cx.app))
                    .label('Notification settings')
                    .onClick(cx.listener((this_:CollapsibleStory, _, _, cx) -> this_.toggle(SETTINGS, cx))))
                .content(vFlex()
                    .wFull()
                    .rounded(theme.radiusLg)
                    .border1()
                    .borderColor(border)
                    .children(rows)));
    }

    /** A list where the header and every row carry their own action. */
    function renderRowActions(cx:Context<CollapsibleStory>):IntoElement {
        final theme = Theme.global(cx);
        final muted = theme.muted;
        final radius = theme.radius;

        return section('Row actions')
            .description('Actions live beside the trigger, in the header and in every row.')
            .w(px(360.))
            .vFlex()
            .child(GroupBox.component().outline().wFull().child(Collapsible.component()
                .wFull()
                .gap3()
                .open(isOpen(API_KEYS))
                .child(hFlex()
                    .wFull()
                    .gap2()
                    .child(triggerRow(API_KEYS, cx)
                        .flex1()
                        .gap2()
                        .child(chevron(isOpen(API_KEYS), cx.app))
                        .child(div().textSm().fontMedium().child('API Keys')))
                    .child(Button.component('add-key')
                        .ghost()
                        .xsmall()
                        .icon(IconName.Plus)
                        .tooltip('Add key')))
                .content(vFlex().gap2().children([for (row in API_KEY_ROWS) (hFlex()
                    .gap2()
                    .itemsCenter()
                    .child(hFlex()
                        .flexNone()
                        .size(px(20.))
                        .itemsCenter()
                        .justifyCenter()
                        .rounded(radius)
                        .bg(muted)
                        .child(Icon.component(IconName.Asterisk)
                            .xsmall()
                            .textColor(theme.green)))
                    .child(div().w20().flexNone().textXs().child(row[0]))
                    .child(div()
                        .flex1()
                        .overflowHidden()
                        .px2()
                        .py(px(2.))
                        .rounded(radius)
                        .bg(muted)
                        .textXs()
                        .child(row[1]))
                    .child(Button.component(row[0])
                        .ghost()
                        .xsmall()
                        .icon(IconName.Ellipsis)
                        .tooltip('More')) : IntoElement)]))));
    }

    /** Panels nested inside panels. */
    function renderTree(cx:Context<CollapsibleStory>):IntoElement {
        return section('Nested')
            .description('Panels nest to any depth, here as a file tree.')
            .w(px(360.))
            .vFlex()
            .child(GroupBox.component().outline().wFull().child(vFlex()
                .wFull()
                .child(Collapsible.component()
                    .wFull()
                    .open(isOpen(COMPONENTS_DIR))
                    .child(folderRow(COMPONENTS_DIR, 'components', cx))
                    .content(vFlex()
                        .pl3()
                        .child(Collapsible.component()
                            .wFull()
                            .open(isOpen(UI_DIR))
                            .child(folderRow(UI_DIR, 'ui', cx))
                            .content(vFlex().pl3().children([for (name in ['button.rs', 'card.rs', 'dialog.rs']) fileRow(name, cx.app)])))
                        .child(fileRow('login_form.rs', cx.app))))
                .child(fileRow('main.rs', cx.app))));
    }

    /** An identity row that stays visible, with the details folded behind it. */
    function renderProfile(cx:Context<CollapsibleStory>):IntoElement {
        final mutedForeground = Theme.global(cx).mutedForeground;

        return section('Profile')
            .description('Shows who someone is, and their details only on request.')
            .w(px(360.))
            .vFlex()
            .child(GroupBox.component().outline().wFull().child(Collapsible.component()
                .wFull()
                .gap3()
                .open(isOpen(PROFILE))
                .child(triggerRow(PROFILE, cx)
                    .justifyBetween()
                    .gap2()
                    .child(hFlex()
                        .gap2()
                        .itemsCenter()
                        .child(Avatar.component().name('Jason Lee').xsmall())
                        .child(div().textSm().fontMedium().child('@huacnlee')))
                    .child(chevron(isOpen(PROFILE), cx.app)))
                .content(vFlex().gap2().children([for (field in PROFILE_FIELDS) (hFlex()
                    .gap2()
                    .itemsCenter()
                    .textXs()
                    .child(Icon.component(field.icon).xsmall().textColor(mutedForeground))
                    .child(div().textColor(mutedForeground).child(field.label))
                    .child(div().fontMedium().child(field.value)) : IntoElement)]))));
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<CollapsibleStory> = cast cx;
        return vFlex()
            .wFull()
            .itemsCenter()
            .gap6()
            .child(renderBasic(self))
            .child(renderRowTrigger(self))
            .child(renderBottomTrigger(self))
            .child(renderSettings(self))
            .child(renderRowActions(self))
            .child(renderTree(self))
            .child(renderProfile(self));
    }

}
