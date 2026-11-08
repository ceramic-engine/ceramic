// Ported from gpui-kit 0.8.1: crates/story/src/stories/spinner_story.rs
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
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.spinner.Spinner;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import glaze.Easing.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

class SpinnerStory extends Model implements Story {

    public static function title():String {
        return 'Spinner';
    }

    public static function description():String {
        return 'Displays an spinner showing the completion progress of a task.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<SpinnerStory> {
        return cx.newEntity((c:Context<SpinnerStory>) -> new SpinnerStory(window, c));
    }

    final focusHandle_:FocusHandle;

    var value:Float = 50.;

    @observe var size:Size = glaze.kit.Size.Medium;

    function new(_:Window, cx:Context<SpinnerStory>) {
        super();
        focusHandle_ = cx.focusHandle();
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
            .gap3()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .child(storyToolbar(size))
            .child(section('Default')
                .description('An indeterminate loading indicator.')
                .gapX2()
                .child(Spinner.component().withSize(size)))
            .child(section('Color')
                .description('Use a color that suits the surrounding status.')
                .gapX2()
                .child(Spinner.component().withSize(size).color(theme.blue))
                .child(Spinner.component().withSize(size).color(theme.green)))
            .child(section('Custom size')
                .description('A fixed pixel size is also supported.')
                .gapX2()
                .child(Spinner.component().withSize(px(64.))))
            .child(section('Icon')
                .description('Replace the default spinner glyph.')
                .gapX2()
                .child(Spinner.component().withSize(size).icon(IconName.LoaderCircle))
                .child(Spinner.component().withSize(size).icon(IconName.LoaderCircle).color(theme.cyan)))
            .child(section('Easing')
                .description('Customize the rotation timing curve.')
                .gapX2()
                .child(Spinner.component().withSize(size).icon(IconName.Loader).ease(linear))
                .child(Spinner.component().withSize(size).icon(IconName.Loader).ease(bounce(easeInOut)))
                .child(Spinner.component().withSize(size).icon(IconName.Loader).ease(easeOutQuint())));
    }

}
