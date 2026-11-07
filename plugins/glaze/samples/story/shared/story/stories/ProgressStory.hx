// Ported from gpui-kit 0.8.1: crates/story/src/stories/progress_story.rs
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
import glaze.Action;
import glaze.WeakEntity;
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu;
import glaze.kit.progress.Progress;
import glaze.kit.progress.ProgressCircle;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

/** Rust `ProgressAction::SetValue(f32)`. */
@:action(namespace = progress_story) private class ProgressSetValue implements Action {
    public final value:Float;

    public function new(value:Float) {
        this.value = value;
    }
}

/** Rust `ProgressAction::ToggleLoading`. */
@:action(namespace = progress_story) private class ProgressToggleLoading implements Action {}

class ProgressStory extends Model implements Story {

    public static function title():String {
        return 'Progress';
    }

    public static function description():String {
        return 'Show task completion with determinate or loading indicators.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<ProgressStory> {
        return cx.newEntity((c:Context<ProgressStory>) -> new ProgressStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var value:Float = 25.;

    @observe var loading:Bool = false;

    @observe var size:Size = glaze.kit.Size.Medium;

    /**
     * Rust keeps the animation task in `_task` (replacing it drops the
     * previous one): a new run bumps this counter and the old loop stops.
     */
    var task:Int = 0;

    final self:WeakEntity<ProgressStory>;

    function new(_:Window, cx:Context<ProgressStory>) {
        super();
        focusHandle_ = cx.focusHandle();
        self = cx.weakEntity();
    }

    public function setValue(value:Float):Void {
        this.value = value;
    }

    function startAnimation(cx:App):Void {
        value = 0.;
        final run = ++task;
        tick(self, run, cx);
    }

    static function tick(entity:WeakEntity<ProgressStory>, run:Int, app:App):Void {
        app.backgroundExecutor().timer(0.015).then(_ -> {
            if (!entity.isUpgradable()) return;
            final again = entity.update(app, (this_, _) -> {
                if (this_.task != run) return false;
                this_.value = Math.min(this_.value + 2., 100.);
                if (this_.value >= 100.) {
                    this_.task++;
                    return false;
                }
                return true;
            });
            if (again) tick(entity, run, app);
        });
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final value = this.value;
        final loading = this.loading;
        final circle = new ProgressCircle('analysis-progress')
            .withSize(size)
            .value(value)
            .loading(loading)
            .size20();
        if (!loading) {
            circle.child(div()
                .sizeFull()
                .flex()
                .itemsCenter()
                .justifyCenter()
                .fontSemibold()
                .child('${fmt(value)}%'));
        }
        return vFlex()
            .wFull()
            .gap3()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .onAction(ProgressSetValue, (action, _, _) -> setValue(action.value))
            .onAction(ProgressToggleLoading, (_, _, _) -> this.loading = !this.loading)
            .child(storyToolbar(size)
                .dropdownChild(new Button('progress-value').label('Value: ${fmt(value)}%'), (menu:PopupMenu, _, _) -> {
                    for (preset in [0., 25., 75., 100.]) {
                        menu = menu.menuWithCheck('${fmt(preset)}%', value == preset, new ProgressSetValue(preset));
                    }
                    return menu;
                })
                .dropdownChild(new Button('progress-options').label('Options'),
                    (menu, _, _) -> menu.menuWithCheck('Loading', loading, new ProgressToggleLoading()))
                .child(new Button('progress-play')
                    .icon(IconName.Play)
                    .onClick((_, _, cx) -> startAnimation(cx))))
            .child(section('Upload')
                .description('Pair progress with a clear label, value, and status.')
                .w(px(560.))
                .itemsCenter()
                .child(vFlex()
                    .w(px(400.))
                    .gap3()
                    .p4()
                    .rounded(theme.radiusLg)
                    .border1()
                    .borderColor(theme.border)
                    .child(hFlex()
                        .itemsCenter()
                        .justifyBetween()
                        .child(div().fontMedium().child('Uploading design-assets.zip'))
                        .child(div()
                            .textSm()
                            .textColor(theme.mutedForeground)
                            .child('${fmt(value)}%')))
                    .child(new Progress('upload-progress').value(value).loading(loading))
                    .child(hFlex()
                        .itemsCenter()
                        .justifyBetween()
                        .textXs()
                        .textColor(theme.mutedForeground)
                        .child('24.8 MB of 96 MB')
                        .child(loading ? 'Calculating…' : 'About 1 min left'))))
            .child(section('Circular')
                .description('Use a compact radial indicator for focused tasks.')
                .w(px(560.))
                .itemsCenter()
                .child(hFlex()
                    .w(px(400.))
                    .itemsCenter()
                    .gap5()
                    .p4()
                    .rounded(theme.radiusLg)
                    .bg(theme.muted.opacity(0.4))
                    .child(circle)
                    .child(vFlex()
                        .gap1()
                        .child(div().fontMedium().child('Analyzing project'))
                        .child(div()
                            .textSm()
                            .textColor(theme.mutedForeground)
                            .child(loading ? 'Preparing analysis…' : 'Scanning components and dependencies.')))));
    }

    /** Rust `format!("{}", f32)`: no decimals for whole values. */
    static function fmt(value:Float):String {
        return value == Math.ffloor(value) && Math.abs(value) < 1e15 ? Std.string(Std.int(value)) : Std.string(value);
    }

}
