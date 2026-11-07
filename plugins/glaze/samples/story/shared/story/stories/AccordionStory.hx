// Ported from gpui-kit 0.8.1: crates/story/src/stories/accordion_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.Action;
import glaze.AnyView;
import glaze.App;
import glaze.AppContext;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.Pixels;
import glaze.StyleBuilder;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.accordion.Accordion;
import glaze.kit.button.Button;
import glaze.kit.checkbox.Checkbox;
import glaze.kit.switch_.Switch;
import glaze.kit.tag.Tag;
import glaze.kit.theme.Theme;
import story.Story;
import story.StoryActions.ChangeStorySize;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.base.StyledExt;

enum ToggleOptionKind {
    Multiple;
    Icon;
    Disabled;
    Bordered;
}

/** Rust `enum ToggleOption` (an action). */
@:action(namespace = accordion_story, noJson)
class ToggleOption implements Action {
    public final value:ToggleOptionKind;
}

/**
 * The theme-derived values a settings row draws with, read once so the row
 * builder itself needs no app context.
 */
@:structInit
class SettingsItemStyle {
    public final iconBg:Hsla;
    public final muted:Hsla;
    public final iconRadius:Pixels;
}

class AccordionStory extends Model implements Story {

    var openIxs:Array<Int>;

    var styledOpenIxs:Array<Int>;

    var size:Size;

    var bordered:Bool;

    var disabled:Bool;

    var multiple:Bool;

    var showIcon:Bool;

    final focusHandle:FocusHandle;

    public static function title():String {
        return 'Accordion';
    }

    public static function description():String {
        return 'The accordion uses collapse internally to make it collapsible.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<AccordionStory> {
        return cx.newEntity((cx:Context<AccordionStory>) -> new AccordionStory(window, cx));
    }

    function new(_:Window, cx:AppContext) {
        super();
        bordered = false;
        openIxs = [0];
        styledOpenIxs = [0];
        size = Medium;
        disabled = false;
        multiple = false;
        showIcon = false;
        focusHandle = cx.focusHandle();
    }

    function toggleAccordion(openIxs:Array<Int>, _:Window, cx:Context<AccordionStory>):Void {
        this.openIxs = openIxs;
        cx.notify();
    }

    /**
     * A settings row: the icon sits in a rounded square, and the content lines up
     * with the title rather than with the icon.
     */
    static function settingsItem(item:AccordionItem, icon:IconName, title:String, tag:Null<Tag>, body:String, style:SettingsItemStyle):AccordionItem {
        final heading = hFlex()
            .gap2()
            .itemsCenter()
            .child(hFlex()
                .flexNone()
                .size(px(32.))
                .itemsCenter()
                .justifyCenter()
                .rounded(style.iconRadius)
                .bg(style.iconBg)
                .child(new Icon(icon).small().textColor(style.muted)))
            .child(div().fontSemibold().child(title));
        if (tag != null) heading.child(tag.small());

        return item.title(heading)
            .titleStyle(StyleBuilder.build(s -> s.pt(px(8.)).pb(px(8.))))
            .contentStyle(StyleBuilder.build(s -> s.textColor(style.muted)
                // Past the icon square, so the text starts under the title.
                .pl(px(52.))
                .pt(px(0.))
                .pb(px(12.))))
            .child(body);
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<AccordionStory> = cast cx;
        final theme = Theme.global(cx);
        final settingsItemStyle:SettingsItemStyle = {
            iconBg: theme.secondary.opacity(0.5),
            muted: theme.mutedForeground,
            iconRadius: theme.radius,
        };

        final multiple = this.multiple;
        final showIcon = this.showIcon;
        final disabled = this.disabled;
        final bordered = this.bordered;

        return vFlex()
            .wFull()
            .itemsCenter()
            .gap6()
            .onAction(ChangeStorySize, self.listener((this_:AccordionStory, action:ChangeStorySize, _, cx) -> {
                this_.size = action.value;
                cx.notify();
            }))
            .onAction(ToggleOption, self.listener((this_:AccordionStory, action:ToggleOption, _, cx) -> {
                switch action.value {
                    case Multiple: this_.multiple = !this_.multiple;
                    case Icon: this_.showIcon = !this_.showIcon;
                    case Disabled: this_.disabled = !this_.disabled;
                    case Bordered: this_.bordered = !this_.bordered;
                }
                cx.notify();
            }))
            .child(storyToolbar(size)
                .itemsCenter()
                .flexWrap()
                .dropdownChild(new Button('accordion-options').label('Options'), (menu, _, _) -> menu
                    .menuWithCheck('Multiple', multiple, new ToggleOption(Multiple))
                    .menuWithCheck('Icons', showIcon, new ToggleOption(Icon))
                    .menuWithCheck('Disabled', disabled, new ToggleOption(Disabled))
                    .menuWithCheck('Bordered', bordered, new ToggleOption(Bordered))))
            .child(section('Default')
                .description('Expand one item at a time by default.')
                .child(div().w(px(480.)).child(new Accordion('test')
                    .bordered(bordered)
                    .withSize(size)
                    .disabled(disabled)
                    .multiple(multiple)
                    .item(item -> {
                        item.open(openIxs.indexOf(0) >= 0);
                        if (showIcon) item.icon(IconName.Info);
                        item.title('Is it accessible?')
                            .child('Yes. Each item is a button with an aria-expanded state, '
                                + 'so screen readers announce whether the section is open, '
                                + 'and the whole group can be reached with the keyboard.');
                    })
                    .item(item -> {
                        item.open(openIxs.indexOf(1) >= 0);
                        if (showIcon) item.icon(IconName.Inbox);
                        item.title('Can it hold any content?')
                            .child(vFlex()
                                .gap3()
                                .child('An item takes any element as its content, '
                                    + 'not just text. The height animation measures '
                                    + 'whatever you put in it.')
                                .child(hFlex()
                                    .gap4()
                                    .child(new Switch('switch1').label('Switch'))
                                    .child(new Checkbox('checkbox1').label('Or a Checkbox'))));
                    })
                    .item(item -> {
                        item.open(openIxs.indexOf(2) >= 0);
                        if (showIcon) item.icon(IconName.Moon);
                        item.title('Is it animated?')
                            .child('Yes. Expanding and collapsing animates the height of '
                                + 'the content, and the chevron rotates to follow. '
                                + 'Items below move along with it.');
                    })
                    .item(item -> item.title('Disabled item')
                        .disabled(true)
                        .child('This item cannot be expanded.'))
                    .onToggleClick(self.listener((this_:AccordionStory, openIxs:Array<Int>, window, cx) -> {
                        this_.toggleAccordion(openIxs.copy(), window, cx);
                    })))))
            .child(section('Custom style').child(
                // A tinted frame around the card.
                div()
                    .w(px(480.))
                    .p(px(4.))
                    .rounded(theme.radiusLg * 2.)
                    .bg(theme.secondary.opacity(0.5))
                    .border1()
                    .borderColor(theme.border.opacity(0.5))
                    .child(new Accordion('custom-style')
                        .multiple(multiple)
                        .disabled(disabled)
                        .item(item -> settingsItem(item, IconName.Settings, 'Account Settings', Tag.success().outline().child('New'),
                            'Manage your account preferences, security settings, '
                            + 'and personal information. You can also configure '
                            + 'two-factor authentication here.', settingsItemStyle)
                            .open(styledOpenIxs.indexOf(0) >= 0))
                        .item(item -> settingsItem(item, IconName.Eye, 'Privacy & Security', null,
                            'Control who can see your profile and how your data '
                            + 'is used.', settingsItemStyle)
                            .open(styledOpenIxs.indexOf(1) >= 0))
                        .item(item -> settingsItem(item, IconName.Info, 'Help & Support', null,
                            'Browse the documentation, or get in touch with the '
                            + 'support team.', settingsItemStyle)
                            .open(styledOpenIxs.indexOf(2) >= 0))
                        .onToggleClick(self.listener((this_:AccordionStory, openIxs:Array<Int>, _, cx) -> {
                            this_.styledOpenIxs = openIxs.copy();
                            cx.notify();
                        })))));
    }

}
