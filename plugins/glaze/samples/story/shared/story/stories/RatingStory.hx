// Ported from gpui-kit 0.8.1: crates/story/src/stories/rating_story.rs
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
import gpui.component.Size;
import gpui.component.rating.Rating;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

class RatingStory extends Model implements Story {

    public static function title():String {
        return 'Rating';
    }

    public static function description():String {
        return 'A simple interactive star rating component.';
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<RatingStory> {
        return cx.newEntity((c:Context<RatingStory>) -> new RatingStory(window, c));
    }

    /** No global init required for RatingStory. */
    public static function init(_:App):Void {}

    final focusHandle_:FocusHandle;

    @observe var size:Size = gpui.component.Size.Medium;

    @observe var value:Int = 3;

    function new(_:Window, cx:Context<RatingStory>) {
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
            .gap3()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .child(storyToolbar(size))
            .child(section('Default')
                .description('Select a value directly from the rating.')
                .w128()
                .child(vFlex()
                    .wFull()
                    .gap3()
                    .justifyCenter()
                    .itemsCenter()
                    .child(new Rating('rating-1')
                        .withSize(size)
                        .value(value)
                        .max(5)
                        .onClick((value, _, _) -> this.value = value))))
            .child(section('Disabled').w(px(480.)).child(new Rating('rating-2')
                .withSize(size)
                .value(2)
                .color(theme.green)
                .max(5)
                .disabled(true)))
            .child(section('Color').w(px(480.)).child(new Rating('rating-3')
                .withSize(size)
                .value(value)
                .color(theme.green)
                .max(5)));
    }

}
