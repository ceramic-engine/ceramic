// Ported from gpui-kit 0.8.1: crates/story/src/stories/radio_story.rs
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
import glaze.kit.Size;
import glaze.kit.radio.Radio;
import glaze.kit.radio.Radio.RadioGroup;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

class RadioStory extends Model implements Story {

    public static function title():String {
        return 'Radio';
    }

    public static function description():String {
        return 'Choose one option from a set.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<RadioStory> {
        return cx.newEntity((c:Context<RadioStory>) -> new RadioStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var delivery:Null<Int> = 0;

    @observe var billing:Null<Int> = 1;

    @observe var size:Size = glaze.kit.Size.Medium;

    function new(_:Window, cx:Context<RadioStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return vFlex()
            .wFull()
            .itemsCenter()
            .gap3()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .child(storyToolbar(size))
            .child(section('Delivery')
                .description('Choose one option from a clearly described set.')
                .w(px(320.))
                .itemsCenter()
                .child(RadioGroup.vertical('delivery')
                    .w(px(320.))
                    .gap3()
                    .child(Radio.component('standard')
                        .withSize(size)
                        .wFull()
                        .label('Standard delivery')
                        .child(div().textXs().textColor(theme.mutedForeground).child('Arrives in 3\u20135 business days.')))
                    .child(Radio.component('express')
                        .withSize(size)
                        .wFull()
                        .label('Express delivery')
                        .child(div().textXs().textColor(theme.mutedForeground).child('Arrives the next business day.')))
                    .child(Radio.component('pickup')
                        .withSize(size)
                        .wFull()
                        .label('Store pickup')
                        .child(div().textXs().textColor(theme.mutedForeground).child('Unavailable for this order.'))
                        .disabled(true))
                    .selectedIndex(delivery)
                    .onClick((selected, _, _) -> delivery = selected)))
            .child(section('Billing cycle')
                .description('Horizontal groups work for short, related choices.')
                .w(px(320.))
                .itemsCenter()
                .child(RadioGroup.horizontal('billing')
                    .w(px(320.))
                    .justifyBetween()
                    .child(Radio.component('monthly').withSize(size).label('Monthly'))
                    .child(Radio.component('yearly').withSize(size).label('Yearly'))
                    .child(Radio.component('lifetime').withSize(size).label('Lifetime'))
                    .selectedIndex(billing)
                    .onClick((selected, _, _) -> billing = selected)));
    }

}
