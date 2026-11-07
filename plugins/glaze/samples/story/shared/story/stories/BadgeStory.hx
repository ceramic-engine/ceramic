// Ported from gpui-kit 0.8.1: crates/story/src/stories/badge_story.rs
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
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.avatar.Avatar;
import glaze.kit.badge.Badge;
import glaze.kit.dock.PanelControl;
import glaze.kit.theme.Theme;
import story.Story;
import story.StoryActions.ChangeStorySize;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

class BadgeStory extends Model implements Story {

    final focusHandle:FocusHandle;

    var size:Size;

    function new(_:Window, cx:AppContext) {
        super();
        focusHandle = cx.focusHandle();
        size = Medium;
    }

    public static function view(window:Window, cx:App):Entity<BadgeStory> {
        return cx.newEntity((cx:Context<BadgeStory>) -> new BadgeStory(window, cx));
    }

    public static function title():String {
        return 'Badge';
    }

    public static function description():String {
        return 'A red dot that indicates the number of unread messages.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function zoomable():Null<PanelControl> {
        return null;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<BadgeStory> = cast cx;
        final theme = Theme.global(cx);
        final size = this.size;
        inline function avatar(src:String):Avatar {
            return new Avatar().withSize(size).src(src);
        }
        return vFlex()
            .gap3()
            .onAction(ChangeStorySize, self.listener((this_:BadgeStory, action:ChangeStorySize, _, cx) -> {
                this_.size = action.value;
                cx.notify();
            }))
            .child(storyToolbar(size))
            .child(section('Icon')
                .w128()
                .child(new Badge()
                    .withSize(size)
                    .count(3)
                    .child(new Icon(IconName.Bell).withSize(size)))
                .child(new Badge()
                    .withSize(size)
                    .count(103)
                    .child(new Icon(IconName.Inbox).withSize(size))))
            .child(section('Count')
                .w128()
                .child(new Badge().withSize(size).count(3).child(avatar('https://avatars.githubusercontent.com/u/5518?v=4')))
                .child(new Badge().withSize(size).count(103).child(avatar('https://avatars.githubusercontent.com/u/28998859?v=4'))))
            .child(section('Badge icon')
                .w128()
                .child(new Badge()
                    .withSize(size)
                    .icon(IconName.Check)
                    .color(theme.cyan)
                    .child(avatar('https://avatars.githubusercontent.com/u/5518?v=4')))
                .child(new Badge()
                    .withSize(size)
                    .icon(IconName.Star)
                    .color(theme.yellow)
                    .child(avatar('https://avatars.githubusercontent.com/u/20092316?v=4'))))
            .child(section('Dot').w(px(480.)).child(new Badge().withSize(size).dot().count(1).child(avatar('https://avatars.githubusercontent.com/u/5518?v=4'))))
            .child(section('Color')
                .w128()
                .child(new Badge()
                    .withSize(size)
                    .count(3)
                    .color(theme.blue)
                    .child(avatar('https://avatars.githubusercontent.com/u/5518?v=4')))
                .child(new Badge()
                    .withSize(size)
                    .dot()
                    .color(theme.green)
                    .count(1)
                    .child(avatar('https://avatars.githubusercontent.com/u/5518?v=4'))))
            .child(section('Nested')
                .w128()
                .child(new Badge().withSize(size).count(212).large().child(new Badge()
                    .withSize(size)
                    .icon(IconName.Check)
                    .color(theme.cyan)
                    .child(avatar('https://avatars.githubusercontent.com/u/5518?v=4'))))
                .child(new Badge()
                    .withSize(size)
                    .count(2)
                    .color(theme.green)
                    .large()
                    .child(new Badge()
                        .withSize(size)
                        .icon(IconName.Star)
                        .color(theme.yellow)
                        .child(new Avatar().withSize(size).large().src('https://avatars.githubusercontent.com/u/20092316?v=4'))))
                .child(new Badge()
                    .withSize(size)
                    .count(3)
                    .color(theme.green)
                    .child(new Badge()
                        .withSize(size)
                        .icon(IconName.Asterisk)
                        .color(theme.green)
                        .child(avatar('https://avatars.githubusercontent.com/u/22312482?v=4'))))
                .child(new Badge().withSize(size).dot().child(new Badge()
                    .withSize(size)
                    .icon(IconName.Sun)
                    .color(theme.red)
                    .child(new Avatar().withSize(size).small().src('https://avatars.githubusercontent.com/u/150917089?v=4')))));
    }

}
