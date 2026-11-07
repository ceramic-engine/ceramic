// Ported from gpui-kit 0.8.1: crates/story/src/stories/tooltip_story.rs
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
import gpui.Action;
import gpui.KeyBinding;
import gpui.base.Geometry.Placement;
import gpui.component.IconName;
import gpui.component.button.Button;
import gpui.component.button.Button.ButtonVariant;
import gpui.component.button.Toggle;
import gpui.component.checkbox.Checkbox;
import gpui.component.clipboard.Clipboard;
import gpui.component.dock.PanelControl;
import gpui.component.radio.Radio;
import gpui.component.switch_.Switch;
import gpui.component.tooltip.Tooltip;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

/** Rust `actions!(tooltip_story, [Info])` (renamed: `Info` clashes with `ButtonVariant.Info`). */
@:action(namespace = tooltip_story, name = Info) private class InfoAction implements Action {}

class TooltipStory extends Model implements Story {

    public static function title():String {
        return 'Tooltip';
    }

    public static function description():String {
        return 'Describe a control on hover.';
    }

    public static function zoomable():Null<PanelControl> {
        return null;
    }

    public static function init(cx:App):Void {
        cx.bindKeys([new KeyBinding('ctrl-shift-delete', new InfoAction(), 'Tooltip')]);
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<TooltipStory> {
        return cx.newEntity((c:Context<TooltipStory>) -> new TooltipStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var removableButtonVisible:Bool = true;

    function new(_:Window, cx:Context<TooltipStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        return vFlex()
            .wFull()
            .gap3()
            .child(section('Button')
                .description('Prefer the left, bottom, or right side, with an optional keyboard shortcut hint.')
                .child(new Button('btn0')
                    .label('Search')
                    .withVariant(ButtonVariant.Primary)
                    .tooltip('This is a search Button.')
                    .tooltipPlacement(Placement.Left))
                .child(new Button('btn1')
                    .label('Info')
                    .tooltipWithAction('This is a tooltip with Action for display keybinding.', new InfoAction(), 'Tooltip')
                    .tooltipPlacement(Placement.Bottom))
                .child(new Button('btn2')
                    .label('Hover me')
                    .tooltip('This tooltip prefers the right side.')
                    .tooltipPlacement(Placement.Right)))
            .child(section('Show delay')
                .description('Override the delay per trigger. Moving between triggers switches without waiting again.')
                .child(new Button('delay-immediate')
                    .label('Immediate')
                    .tooltip('Shows as soon as the pointer enters.')
                    .tooltipShowDelay(0.))
                .child(new Button('delay-default')
                    .label('Default')
                    .tooltip('Shows after the application default delay.'))
                .child(new Button('delay-slow')
                    .label('Slow')
                    .tooltip('Shows after 1 second.')
                    .tooltipShowDelay(1.)))
            .child(section('Checkbox')
                .description('Tooltips work on selection controls.')
                .child(new Checkbox('check').label('Remember me').checked(true).tooltip('This is a tooltip')))
            .child(section('Radio')
                .description('Explain an individual radio option.')
                .child(new Radio('radio').label('Radio with tooltip').checked(true).tooltip('This is a radio button')))
            .child(section('Switch')
                .description('Add context without extending the visible label.')
                .child(new Switch('switch').checked(true).tooltip('This is a switch')))
            .child(section('Toggle')
                .description('Describe text and icon-only toggles.')
                .child(hFlex()
                    .gap2()
                    .child(new Toggle('toggle1').label('Bold').tooltip('Toggle bold'))
                    .child(new Toggle('toggle2').icon(IconName.Heart).tooltip('Toggle favorite'))))
            .child(section('Clipboard')
                .description('Clarify the copy action.')
                .child(new Clipboard('clip1').value('Hello, World!').tooltip('Copy to clipboard')))
            .child(section('Custom content')
                .description('Build tooltip content with an action hint.')
                .child(div()
                    .child('Hover me')
                    .id('tooltip-2')
                    .tooltip((window, cx) -> new Tooltip('This is a default tooltip style by GPUI.')
                        .action(new InfoAction(), 'Tooltip')
                        .build(window, cx))))
            .child(section('Removed trigger')
                .description('Dismiss cleanly when the trigger leaves the view.')
                .child(hFlex()
                    .gap2()
                    .when(removableButtonVisible, this_ -> this_.child(new Button('remove-tooltip-trigger')
                        .danger()
                        .label('Remove me')
                        .tooltip('Clicking this button removes the trigger.')
                        .onClick((_, _, _) -> removableButtonVisible = false)))
                    .when(!removableButtonVisible, this_ -> this_.child(new Button('restore-tooltip-trigger')
                        .label('Restore button')
                        .onClick((_, _, _) -> removableButtonVisible = true)))));
    }

}
