// Ported from gpui-kit 0.8.1: crates/story/src/stories/avatar_story.rs
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
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.avatar.Avatar;
import glaze.kit.avatar.AvatarGroup;
import glaze.kit.dock.PanelControl;
import glaze.kit.theme.Theme;
import story.Story;
import story.StoryActions.ChangeStorySize;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.base.StyledExt;

class AvatarStory extends Model implements Story {

    static final AVATARS:Array<String> = [
        'https://avatars.githubusercontent.com/u/5518?v=4',
        'https://avatars.githubusercontent.com/u/28998859?v=4',
        'https://avatars.githubusercontent.com/u/20092316?v=4',
        'https://avatars.githubusercontent.com/u/22312482?v=4',
        'https://avatars.githubusercontent.com/u/150917089?v=4',
        'https://avatars.githubusercontent.com/u/20337280?v=4',
        'https://avatars.githubusercontent.com/u/629429?v=4',
        'https://avatars.githubusercontent.com/u/583231?v=4',
        'https://avatars.githubusercontent.com/u/1264109?v=4',
        'https://avatars.githubusercontent.com/u/2936367?v=4',
        'https://avatars.githubusercontent.com/u/1253486?v=4',
    ];

    final focusHandle:FocusHandle;

    var size:Size;

    function new(_:Window, cx:AppContext) {
        super();
        focusHandle = cx.focusHandle();
        size = Medium;
    }

    public static function view(window:Window, cx:App):Entity<AvatarStory> {
        return cx.newEntity((cx:Context<AvatarStory>) -> new AvatarStory(window, cx));
    }

    public static function title():String {
        return 'Avatar';
    }

    public static function description():String {
        return 'Represent a person or organization with an image or fallback.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function zoomable():Null<PanelControl> {
        return null;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<AvatarStory> = cast cx;
        final theme = Theme.global(cx);
        return vFlex()
            .gap3()
            .onAction(ChangeStorySize, self.listener((this_:AvatarStory, action:ChangeStorySize, _, cx) -> {
                this_.size = action.value;
                cx.notify();
            }))
            .child(storyToolbar(size))
            .child(section('Image')
                .description('Use an image when one is available.')
                .w128()
                .child(new Avatar()
                    .name('Jason Lee')
                    .src(AVATARS[0])
                    .withSize(size))
                .child(new Avatar().src(AVATARS[1]).withSize(size)))
            .child(section('Fallback')
                .description('Show initials or an icon when no image is available.')
                .w128()
                .child(new Avatar().name('Jason Lee').withSize(size))
                .child(new Avatar().withSize(size))
                .child(new Avatar()
                    .placeholder(IconName.Building2)
                    .withSize(size)))
            .child(section('Group')
                .description('Groups can limit visible avatars and show overflow.')
                .vFlex()
                .w128()
                .itemsCenter()
                .gap5()
                .child(new AvatarGroup()
                    .withSize(size)
                    .children([for (src in AVATARS.slice(0, 6)) new Avatar().src(src)]))
                .child(new AvatarGroup()
                    .withSize(size)
                    .limit(5)
                    .ellipsis()
                    .children([for (src in AVATARS) new Avatar().src(src)])))
            .child(section('Custom shape')
                .description('Set an explicit size and corner radius.')
                .child(new Avatar()
                    .src(AVATARS[0])
                    .withSize(px(100.))
                    .rounded(px(20.))))
            .child(section('Custom style')
                .description('Add borders and shadows to the image.')
                .child(new Avatar()
                    .src(AVATARS[2])
                    .withSize(px(100.))
                    .border3()
                    .borderColor(theme.foreground)
                    .shadowSm()));
    }

}
