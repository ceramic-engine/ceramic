// Ported from gpui-kit 0.8.1: crates/story/src/stories/label_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import gpui.Action;
import gpui.AnyView;
import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Subscription;
import gpui.Window;
import gpui.base.input.InputEvent;
import gpui.base.input.InputState;
import gpui.component.IconName;
import gpui.component.button.Button;
import gpui.component.button.Toggle;
import gpui.component.input.Input;
import gpui.component.label.Label;
import gpui.component.theme.Theme;
import story.Story;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Lib.*;

using gpui.base.StyledExt;

@:action(namespace = label_story, noJson) class TogglePrefix implements Action {}

class LabelStory extends Model implements Story {

    final focusHandle:FocusHandle;

    var masked:Bool;

    var highlightsText:String;

    final highlightsInput:Entity<InputState>;

    var prefix:Bool;

    final subscriptions:Array<Subscription>;

    public static function title():String {
        return 'Label';
    }

    public static function description():String {
        return 'Display concise text with hierarchy, highlighting, and masking.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    function new(window:Window, cx:Context<LabelStory>) {
        super();
        highlightsInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('Search labels')
            .withCleanOnEscape());

        subscriptions = [cx.subscribe(highlightsInput, InputEvent, (this_:LabelStory, state:Entity<InputState>, e:InputEvent, cx) -> {
            if (e.match(Change)) {
                this_.highlightsText = state.read(cx).value();
                cx.notify();
            }
        })];

        focusHandle = cx.focusHandle();
        masked = false;
        highlightsText = '';
        prefix = false;
    }

    public static function view(window:Window, cx:App):Entity<LabelStory> {
        return cx.newEntity((cx:Context<LabelStory>) -> new LabelStory(window, cx));
    }

    function currentHighlights():HighlightsMatch {
        return prefix ? HighlightsMatch.Prefix(highlightsText) : HighlightsMatch.Full(highlightsText);
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<LabelStory> = cast cx;
        final theme = Theme.global(cx);
        final ht = currentHighlights();
        final prefix = this.prefix;

        return vFlex()
            .wFull()
            .itemsCenter()
            .gap6()
            .onAction(TogglePrefix, self.listener((this_:LabelStory, _:TogglePrefix, _, cx) -> {
                this_.prefix = !this_.prefix;
                cx.notify();
            }))
            .child(storyToolbarGroup().dropdownChild(new Button('label-options').label('Options'), (menu, _, _) -> menu
                .menuWithCheck('Prefix Match', prefix, new TogglePrefix())))
            .child(section('Default')
                .description('Present primary text with optional supporting context.')
                .w(px(560.))
                .itemsCenter()
                .child(vFlex()
                    .w(px(320.))
                    .gap4()
                    .child(new Label('Account details'))
                    .child(new Label('Company address').secondary('Optional'))
                    .child(new Label('Workspace owner')
                        .fontSemibold()
                        .secondary('Administrator'))))
            .child(section('Highlighting')
                .description('Find matching text across Latin and CJK content.')
                .w(px(560.))
                .itemsCenter()
                .child(vFlex()
                    .w(px(320.))
                    .gap4()
                    .child(hFlex()
                        .wFull()
                        .gap2()
                        .child(div().flex1().child(new Input(highlightsInput)))
                        .child(new Toggle('highlight-mask')
                            .label('Mask')
                            .checked(masked)
                            .onClick(self.listener((this_:LabelStory, checked:Bool, _, cx) -> {
                                this_.masked = checked;
                                cx.notify();
                            }))))
                    .child(vFlex()
                        .wFull()
                        .gap3()
                        .p4()
                        .rounded(theme.radiusLg)
                        .border1()
                        .borderColor(theme.border)
                        .child(new Label('Design system documentation')
                            .highlights(ht)
                            .masked(masked))
                        // Keeps the mixed ASCII/CJK matching regression visible.
                        .child(new Label('AAA中文BB')
                            .highlights(ht)
                            .masked(masked)))))
            .child(section('Layout')
                .description('Labels support alignment and natural wrapping.')
                .w(px(560.))
                .itemsCenter()
                .child(vFlex()
                    .w(px(320.))
                    .gap4()
                    .child(vFlex()
                        .wFull()
                        .gap2()
                        .p4()
                        .rounded(theme.radiusLg)
                        .bg(theme.muted.opacity(0.4))
                        .child(new Label('Start aligned'))
                        .child(new Label('Center aligned').textCenter())
                        .child(new Label('End aligned').textRight()))
                    .child(div().w(px(220.)).child(new Label('Long labels wrap cleanly inside constrained layouts.')
                        .lineHeight(rems(1.5))))))
            .child(section('Masked')
                .description('Reveal or conceal sensitive values in place.')
                .w(px(560.))
                .itemsCenter()
                .child(hFlex()
                    .w(px(320.))
                    .itemsCenter()
                    .justifyBetween()
                    .p4()
                    .rounded(theme.radiusLg)
                    .border1()
                    .borderColor(theme.border)
                    .child(vFlex()
                        .gap1()
                        .child(div()
                            .textXs()
                            .textColor(theme.mutedForeground)
                            .child('Available balance'))
                        .child(new Label('$$9,182.10')
                            .text2xl()
                            .fontSemibold()
                            .masked(masked)))
                    .child(new Button('btn-mask')
                        .ghost()
                        .icon(masked ? IconName.EyeOff : IconName.Eye)
                        .onClick(self.listener((this_:LabelStory, _, _, cx) -> {
                            this_.masked = !this_.masked;
                            cx.notify();
                        })))));
    }

}
