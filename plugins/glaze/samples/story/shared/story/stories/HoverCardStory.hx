// Ported from gpui-kit 0.8.1: crates/story/src/stories/hover_card_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.Anchor;
import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Window;
import glaze.kit.avatar.Avatar;
import glaze.kit.button.Button;
import glaze.kit.hovercard.HoverCard;
import glaze.kit.link.Link;
import glaze.kit.theme.Theme;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.base.StyledExt;

class HoverCardStory extends Model implements Story {

    function new(_:Window, _:Context<HoverCardStory>) {
        super();
    }

    public static function view(window:Window, cx:App):Entity<HoverCardStory> {
        return cx.newEntity((cx:Context<HoverCardStory>) -> new HoverCardStory(window, cx));
    }

    public static function title():String {
        return 'HoverCard';
    }

    public static function description():String {
        return 'A hover card displays content when hovering over a trigger element, with configurable delays.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        return vFlex()
            .wFull()
            .itemsCenter()
            .gap6()
            .child(renderBasicExample(cx.app))
            .child(renderUserProfileExample())
            .child(renderCustomTimingExample())
            .child(renderPositioningExamples());
    }

    /** Basic hover card example */
    function renderBasicExample(cx:App):IntoElement {
        final theme = Theme.global(cx);
        return section('Default')
            .description('Shows supporting information without changing the current view.')
            .w(px(520.))
            .child(HoverCard.component('basic')
                .trigger(div()
                    .child('Hover over me')
                    .textColor(theme.primary)
                    .cursorPointer()
                    .textSm())
                .child(vFlex()
                    .gap1()
                    .w(px(450.))
                    .child(div()
                        .child('This is a hover card')
                        .fontSemibold()
                        .textSm())
                    .child(div()
                        .child('You can display rich content when hovering over a trigger element.')
                        .textColor(theme.mutedForeground)
                        .textSm())));
    }

    function renderUserProfileExample():IntoElement {
        return section('Rich Content')
            .description('Cards can contain avatars, typography, and structured details.')
            .w(px(520.))
            .child(hFlex()
                .child('Hover over ')
                .child(HoverCard.component('user-profile')
                    .trigger(glaze.kit.link.Link.component('user-profile-link').child('@huacnlee'))
                    .content((_, _, cx) -> hFlex()
                        .w(px(320.))
                        .gap3()
                        .itemsStart()
                        .child(Avatar.component().src('https://avatars.githubusercontent.com/u/5518?s=64'))
                        .child(vFlex()
                            .gap1()
                            .lineHeight(relative(1.))
                            .child(div().child('Jason Lee').fontSemibold())
                            .child(div()
                                .child('@huacnlee')
                                .textColor(Theme.global(cx).link)
                                .textSm())
                            .child(div().mt1().child('The author of GPUI Component.')))))
                .child(' to see their profile'));
    }

    /** Custom timing configuration example */
    function renderCustomTimingExample():IntoElement {
        return section('Timing')
            .description('Open and close delays can match the interaction context.')
            .w(px(520.))
            .child(hFlex()
                .gap4()
                .child(HoverCard.component('fast-open')
                    .openDelay(0.2)
                    .closeDelay(0.1)
                    .trigger(Button.component('fast').label('Fast Open (200ms)').outline())
                    .child(div().child('This hover card opens after 200ms').textSm()))
                .child(HoverCard.component('slow-open')
                    .openDelay(1.0)
                    .closeDelay(0.5)
                    .trigger(Button.component('slow').label('Slow Open (1000ms)').outline())
                    .child(div().child('This hover card opens after 1000ms').textSm())));
    }

    static function positioned(id:String, anchor:Anchor, buttonId:String, label:String):HoverCard {
        return HoverCard.component(id)
            .anchor(anchor)
            .trigger(Button.component(buttonId).label(label).outline())
            .child(div().child('Positioned at $label').textSm());
    }

    /** All positioning options */
    function renderPositioningExamples():IntoElement {
        return section('Position')
            .description('Content can anchor to each side of its trigger.')
            .w(px(640.))
            .child(vFlex()
                .gap4()
                .itemsCenter()
                .justifyCenter()
                .child(hFlex()
                    .gap4()
                    .child(positioned('anchor-top-left', TopLeft, 'tl', 'Top Left'))
                    .child(positioned('anchor-top-center', TopCenter, 'tc', 'Top Center'))
                    .child(positioned('anchor-top-right', TopRight, 'tr', 'Top Right')))
                // Bottom row
                .child(hFlex()
                    .gap4()
                    .child(positioned('anchor-bottom-left', BottomLeft, 'bl', 'Bottom Left'))
                    .child(positioned('anchor-bottom-center', BottomCenter, 'bc', 'Bottom Center'))
                    .child(positioned('anchor-bottom-right', BottomRight, 'br', 'Bottom Right'))));
    }

}
