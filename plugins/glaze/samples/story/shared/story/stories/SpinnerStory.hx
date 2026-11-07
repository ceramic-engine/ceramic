// Ported from gpui-kit 0.8.1: crates/story/src/stories/spinner_story.rs
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
import gpui.component.IconName;
import gpui.component.Size;
import gpui.component.spinner.Spinner;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import gpui.Easing.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

class SpinnerStory extends Model implements Story {

    public static function title():String {
        return 'Spinner';
    }

    public static function description():String {
        return 'Displays an spinner showing the completion progress of a task.';
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<SpinnerStory> {
        return cx.newEntity((c:Context<SpinnerStory>) -> new SpinnerStory(window, c));
    }

    final focusHandle_:FocusHandle;

    var value:Float = 50.;

    @observe var size:Size = gpui.component.Size.Medium;

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
                .child(new Spinner().withSize(size)))
            .child(section('Color')
                .description('Use a color that suits the surrounding status.')
                .gapX2()
                .child(new Spinner().withSize(size).color(theme.blue))
                .child(new Spinner().withSize(size).color(theme.green)))
            .child(section('Custom size')
                .description('A fixed pixel size is also supported.')
                .gapX2()
                .child(new Spinner().withSize(px(64.))))
            .child(section('Icon')
                .description('Replace the default spinner glyph.')
                .gapX2()
                .child(new Spinner().withSize(size).icon(IconName.LoaderCircle))
                .child(new Spinner().withSize(size).icon(IconName.LoaderCircle).color(theme.cyan)))
            .child(section('Easing')
                .description('Customize the rotation timing curve.')
                .gapX2()
                .child(new Spinner().withSize(size).icon(IconName.Loader).ease(linear))
                .child(new Spinner().withSize(size).icon(IconName.Loader).ease(bounce(easeInOut)))
                .child(new Spinner().withSize(size).icon(IconName.Loader).ease(easeOutQuint())));
    }

}
