// Ported from gpui-kit 0.8.1: crates/story/src/stories/welcome_story.rs
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
import glaze.Pixels;
import glaze.kit.dock.PanelControl;
import glaze.kit.text.TextView;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

class WelcomeStory extends Model implements Story {

    public static function title():String {
        return 'Introduction';
    }

    public static function description():String {
        return 'UI components for building fantastic desktop application by using GPUI.';
    }

    public static function zoomable():Null<PanelControl> {
        return null;
    }

    public static function paddings():Pixels {
        return px(0.);
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<WelcomeStory> {
        return cx.newEntity((c:Context<WelcomeStory>) -> new WelcomeStory(window, c));
    }

    final focusHandle_:FocusHandle;

    function new(_:Window, cx:Context<WelcomeStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        // Rust `markdown(include_str!("../../../../README.md"))`: gpui-kit's README.
        return TextView.markdownAt(story.Include.str('README.md'))
            .px4()
            .scrollable(true)
            .selectable(true);
    }

}
