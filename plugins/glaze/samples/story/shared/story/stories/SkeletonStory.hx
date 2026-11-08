// Ported from gpui-kit 0.8.1: crates/story/src/stories/skeleton_story.rs
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
import glaze.kit.skeleton.Skeleton;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

using glaze.kit.ThemeStyled;

class SkeletonStory extends Model implements Story {

    public static function title():String {
        return 'Skeleton';
    }

    public static function description():String {
        return 'Use to show a placeholder while content is loading.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<SkeletonStory> {
        return cx.newEntity((c:Context<SkeletonStory>) -> new SkeletonStory(window, c));
    }

    final focusHandle_:FocusHandle;

    var value:Float;

    function new(_:Window, cx:Context<SkeletonStory>) {
        super();
        focusHandle_ = cx.focusHandle();
        value = 50.;
    }

    public function setValue(value:Float):Void {
        this.value = value;
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return vFlex()
            .wFull()
            .itemsCenter()
            .gap6()
            .child(section('Text')
                .description('Represents an avatar and text while profile content loads.')
                .w(px(360.))
                .child(hFlex()
                    .wFull()
                    .gap3()
                    .child(Skeleton.component().size12().roundedFullStyle(cx.app))
                    .child(vFlex()
                        .flex1()
                        .gap2()
                        .child(Skeleton.component().wFull().h4().rounded(theme.radius))
                        .child(Skeleton.component().w2_3().h4().rounded(theme.radius)))))
            .child(section('Card')
                .description('Combines media and text placeholders in a content card.')
                .w(px(360.))
                .child(vFlex()
                    .gap2()
                    .child(Skeleton.component().wFull().h(px(180.)).rounded(theme.radius))
                    .child(vFlex()
                        .gap2()
                        .child(Skeleton.component().wFull().h4().rounded(theme.radius))
                        .child(Skeleton.component().w(px(200.)).h4().rounded(theme.radius)))));
    }

}
