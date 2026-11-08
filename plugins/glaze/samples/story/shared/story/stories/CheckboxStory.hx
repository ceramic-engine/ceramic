// Ported from gpui-kit 0.8.1: crates/story/src/stories/checkbox_story.rs
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
import glaze.Window;
import glaze.kit.Size;
import glaze.kit.checkbox.Checkbox;
import glaze.kit.text.TextView;
import glaze.kit.theme.Theme;
import story.Story;
import story.StoryActions.ChangeStorySize;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.base.StyledExt;

class CheckboxStory extends Model implements Story {

    final focusHandle:FocusHandle;

    var check1:Bool = false;

    var check2:Bool = true;

    var check3:Bool = false;

    var check4:Bool = false;

    var check5:Bool = false;

    var check6:Bool = false;

    var size:Size = Medium;

    public static function title():String {
        return 'Checkbox';
    }

    public static function description():String {
        return 'Select one or more independent options.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<CheckboxStory> {
        return cx.newEntity((cx:Context<CheckboxStory>) -> new CheckboxStory(window, cx));
    }

    function new(_:Window, cx:AppContext) {
        super();
        focusHandle = cx.focusHandle();
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<CheckboxStory> = cast cx;
        final theme = Theme.global(cx);
        return vFlex()
            .sizeFull()
            .justifyStart()
            .gap3()
            .onAction(ChangeStorySize, self.listener((this_:CheckboxStory, action:ChangeStorySize, _, cx) -> {
                this_.size = action.value;
                cx.notify();
            }))
            .child(storyToolbar(size))
            .child(section('Default')
                .description('Checked and unchecked options can be mixed freely.')
                .child(Checkbox.component('updates')
                    .withSize(size)
                    .checked(check1)
                    .label('Product updates')
                    .onClick(self.listener((this_:CheckboxStory, checked:Bool, _, cx) -> {
                        this_.check1 = checked;
                        cx.notify();
                    })))
                .child(Checkbox.component('remember')
                    .withSize(size)
                    .checked(check2)
                    .label('Remember this device')
                    .onClick(self.listener((this_:CheckboxStory, checked:Bool, _, cx) -> {
                        this_.check2 = checked;
                        cx.notify();
                    }))))
            .child(section('Without label')
                .description('The label can be supplied by surrounding content.')
                .child(Checkbox.component('unlabelled')
                    .withSize(size)
                    .checked(check3)
                    .onClick(self.listener((this_:CheckboxStory, checked:Bool, _, cx) -> {
                        this_.check3 = checked;
                        cx.notify();
                    }))))
            .child(section('Disabled')
                .description('Both checked and unchecked values remain visible.')
                .w128()
                .child(hFlex()
                    .itemsCenter()
                    .gap6()
                    .child(Checkbox.component('disabled-checked')
                        .withSize(size)
                        .label('Checked')
                        .checked(true)
                        .disabled(true))
                    .child(Checkbox.component('disabled-unchecked')
                        .withSize(size)
                        .label('Unchecked')
                        .checked(false)
                        .disabled(true))))
            .child(section('Labels')
                .description('Labels can wrap and include supporting content.')
                .w128()
                .vFlex()
                .itemsCenter()
                .gap5()
                .child(Checkbox.component('description')
                    .withSize(size)
                    .w(px(320.))
                    .checked(check4)
                    .label('Automatic updates')
                    .child(div()
                        .textXs()
                        .textColor(theme.mutedForeground)
                        .child('Download updates when the application is idle.'))
                    .onClick(self.listener((this_:CheckboxStory, checked:Bool, _, cx) -> {
                        this_.check4 = checked;
                        cx.notify();
                    })))
                .child(Checkbox.component('wrapping')
                    .withSize(size)
                    .w(px(320.))
                    .checked(check6)
                    .label('Notify me when a new device signs in to my account')
                    .onClick(self.listener((this_:CheckboxStory, checked:Bool, _, cx) -> {
                        this_.check6 = checked;
                        cx.notify();
                    })))
                .child(Checkbox.component('markdown')
                    .withSize(size)
                    .w(px(320.))
                    .checked(check5)
                    .label('Accept the terms')
                    .child(div()
                        .textXs()
                        .textColor(theme.mutedForeground)
                        .child(TextView.markdownAt('Read the [terms of service](https://github.com) before continuing.')))
                    .onClick(self.listener((this_:CheckboxStory, checked:Bool, _, cx) -> {
                        this_.check5 = checked;
                        cx.notify();
                    }))));
    }

}
