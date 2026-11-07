// Ported from gpui-kit 0.8.1: crates/story/src/stories/group_box_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.AnyView;
import glaze.App;
import glaze.AppContext;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.StyleBuilder;
import glaze.Window;
import glaze.kit.button.Button;
import glaze.kit.checkbox.Checkbox;
import glaze.kit.groupbox.GroupBox;
import glaze.kit.radio.Radio;
import glaze.kit.switch_.Switch;
import glaze.kit.text.TextView;
import glaze.kit.theme.Theme;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.base.StyledExt;

class GroupBoxStory extends Model implements Story {

    final focusHandle:FocusHandle;

    final emailOptions:Array<Bool> = [false, false, false];

    var profilePrivate:Bool = true;

    var privateContributions:Bool = false;

    var compactPrivate:Bool = true;

    var theme:Null<Int> = 2;

    public static function title():String {
        return 'GroupBox';
    }

    public static function description():String {
        return 'A styled container element that with an optional title to groups related content together.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<GroupBoxStory> {
        return cx.newEntity((cx:Context<GroupBoxStory>) -> new GroupBoxStory(window, cx));
    }

    function new(_:Window, cx:AppContext) {
        super();
        focusHandle = cx.focusHandle();
    }

    function emailCheckbox(self:Context<GroupBoxStory>, id:String, label:String, ix:Int):Checkbox {
        return new Checkbox(id)
            .label(label)
            .checked(emailOptions[ix])
            .onClick(self.listener((this_:GroupBoxStory, checked:Bool, _, cx) -> {
                this_.emailOptions[ix] = checked;
                cx.notify();
            }));
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<GroupBoxStory> = cast cx;
        final colors = Theme.global(cx);
        return vFlex()
            .sizeFull()
            .itemsCenter()
            .gap6()
            .child(section('Default').w128().child(new GroupBox()
                .title('Email notifications')
                .child(emailCheckbox(self, 'all', 'All activity', 0))
                .child(emailCheckbox(self, 'news-letter', 'Product updates', 1))
                .child(emailCheckbox(self, 'account-activity', 'Account activity', 2))
                .child(new Button('ok').primary().label('Save preferences'))))
            .child(section('Filled').w128().child(new GroupBox()
                .id('activity')
                .fill()
                .title('Contributions & activity')
                .footer('Private contributions never reveal repository names.')
                .child(hFlex()
                    .justifyBetween()
                    .child('Make profile private and hide activity')
                    .child(new Switch('profile-private')
                        .checked(profilePrivate)
                        .onClick(self.listener((this_:GroupBoxStory, checked:Bool, _, cx) -> {
                            this_.profilePrivate = checked;
                            cx.notify();
                        }))))
                .child(hFlex()
                    .justifyBetween()
                    .child('Include private contributions on my profile')
                    .child(new Switch('private-contributions')
                        .checked(privateContributions)
                        .onClick(self.listener((this_:GroupBoxStory, checked:Bool, _, cx) -> {
                            this_.privateContributions = checked;
                            cx.notify();
                        }))))
                .child(new Button('btn-1').primary().label('Save'))))
            .child(section('Outlined').w128().child(new GroupBox()
                .id('appearance')
                .outline()
                .title('Appearance')
                .child(RadioGroup.vertical('theme')
                    .child(new Radio('light').label('Light'))
                    .child(new Radio('dark').label('Dark'))
                    .child(new Radio('system').label('System'))
                    .selectedIndex(theme)
                    .onClick(self.listener((this_:GroupBoxStory, selected:Int, _, cx) -> {
                        this_.theme = selected;
                        cx.notify();
                    })))))
            .child(section('Without Title').w128().child(new GroupBox().outline().child(hFlex()
                .justifyBetween()
                .child('Make profile private and hide activity')
                .child(new Switch('compact-private')
                    .checked(compactPrivate)
                    .onClick(self.listener((this_:GroupBoxStory, checked:Bool, _, cx) -> {
                        this_.compactPrivate = checked;
                        cx.notify();
                    }))))))
            .child(section('Custom Style').w128().child(new GroupBox()
                .outline()
                .bg(colors.groupBox)
                .roundedXl()
                .p5()
                .title('This is a custom style')
                .titleStyle(StyleBuilder.build(s -> s.fontSemibold().lineHeight(relative(1.0)).px3()))
                .contentStyle(StyleBuilder.build(s -> s.roundedXl().py3().px4().border2()))
                .child(TextView.markdownAt('You can use `title_style` to customize the style of the title. \n '
                    + 'And any style in `GroupBox` will apply to the content container.'))));
    }

}
