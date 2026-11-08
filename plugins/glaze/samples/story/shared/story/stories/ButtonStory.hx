// Ported from gpui-kit 0.8.1: crates/story/src/stories/button_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.Action;
import glaze.AnyView;
import glaze.App;
import glaze.ClickEvent;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.button.ButtonGroup;
import glaze.kit.progress.ProgressCircle;
import glaze.kit.theme.Theme;
import story.Story;
import story.StoryActions.ChangeStorySize;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

enum ButtonActionKind {
    Disabled;
    Loading;
    Selected;
    Compact;
    Shadow;
    Multiple;
}

/** Rust `enum ButtonAction` (an action). */
@:action(namespace = button_story, noJson)
class ButtonStoryAction implements Action {
    public final value:ButtonActionKind;
}

class ButtonStory extends Model implements Story {

    final focusHandle:FocusHandle;

    var disabled:Bool = false;

    var loading:Bool = false;

    var selected:Bool = false;

    var compact:Bool = false;

    var toggleMultiple:Bool = false;

    var size:Size = Medium;

    function new(cx:Context<ButtonStory>) {
        super();
        focusHandle = cx.focusHandle();
    }

    public static function view(_:Window, cx:App):Entity<ButtonStory> {
        return cx.newEntity((cx:Context<ButtonStory>) -> new ButtonStory(cx));
    }

    static function onClickHandler(ev:ClickEvent, _:Window, _:App):Void {
        trace('Button clicked $ev');
    }

    static function onHoverHandler(hovered:Bool, _:Window, _:App):Void {
        trace('Button hovered $hovered');
    }

    public static function title():String {
        return 'Button';
    }

    public static function description():String {
        return 'Displays a button or a component that looks like a button.';
    }

    public static function closable():Bool {
        return false;
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<ButtonStory> = cast cx;
        final theme = Theme.global(cx);
        final disabled = this.disabled;
        final loading = this.loading;
        final selected = this.selected;
        final compact = this.compact;
        final toggleMultiple = this.toggleMultiple;
        final size = this.size;
        final button = (id:String) -> Button.component(id).withSize(size);
        // `.disabled(disabled).selected(selected)[.loading(loading)].when(compact, compact)[.on_click][.on_hover]`
        final full = (b:Button, click:Bool, hover:Bool) -> {
            b.disabled(disabled).selected(selected).loading(loading);
            if (compact) b.compact();
            if (click) b.onClick(onClickHandler);
            if (hover) b.onHover(onHoverHandler);
            return b;
        };
        // `.disabled(disabled).selected(selected).when(compact, compact).on_click`
        final groupItem = (b:Button) -> {
            b.disabled(disabled).selected(selected);
            if (compact) b.compact();
            return b.onClick(onClickHandler);
        };

        final customVariant = new ButtonCustomVariant(cx.app)
            .color(theme.magenta)
            .foreground(theme.magenta)
            .hover(theme.magenta.opacity(0.1))
            .active(theme.magenta.opacity(0.2));

        final shadow = theme.shadow;

        return vFlex()
            .onAction(ButtonStoryAction, self.listener((this_:ButtonStory, action:ButtonStoryAction, window, cx) -> {
                switch action.value {
                    case Disabled: this_.disabled = !this_.disabled;
                    case Loading: this_.loading = !this_.loading;
                    case Selected: this_.selected = !this_.selected;
                    case Compact: this_.compact = !this_.compact;
                    case Shadow:
                        Theme.update(cx, theme -> theme.shadow = !theme.shadow);
                        window.refresh();
                    case Multiple: this_.toggleMultiple = !this_.toggleMultiple;
                }
                cx.notify();
            }))
            .onAction(ChangeStorySize, self.listener((this_:ButtonStory, action:ChangeStorySize, _, cx) -> {
                this_.size = action.value;
                cx.notify();
            }))
            .gap6()
            .child(storyToolbar(size).dropdownChild(button('button-options').label('Options'), (menu, _, _) -> menu
                .menuWithCheck('Disabled', disabled, new ButtonStoryAction(Disabled))
                .menuWithCheck('Loading', loading, new ButtonStoryAction(Loading))
                .menuWithCheck('Selected', selected, new ButtonStoryAction(Selected))
                .menuWithCheck('Compact', compact, new ButtonStoryAction(Compact))
                .menuWithCheck('Shadow', shadow, new ButtonStoryAction(Shadow))
                .separator()
                .menuWithCheck('Multiple selection', toggleMultiple, new ButtonStoryAction(Multiple))))
            .child(section('Variants')
                .description('Visual treatments communicate action priority.')
                .w128()
                .child(full(button('button-0').label('Default'), true, true))
                .child(full(button('button-1').primary().label('Primary'), true, true))
                .child(full(button('button-2').secondary().label('Secondary'), true, true))
                .child(full(button('button-4').danger().label('Danger'), true, true))
                .child(full(button('button-4-warning').warning().label('Warning'), true, true))
                .child(full(button('button-4-success').success().label('Success'), true, true))
                .child(full(button('button-5-info').info().label('Info'), true, true))
                .child(full(button('button-5-ghost').ghost().label('Ghost'), true, true))
                .child(full(button('button-5-link').link().label('Link'), true, true))
                .child(full(button('button-5-text').text().label('Text'), true, true)))
            .child(section('Icons')
                .description('Icons can lead labels or appear in custom content.')
                .child(full(button('button-icon-1').outline().label('Confirm').icon(IconName.Check), true, false))
                .child(full(button('button-icon-2').outline().label('Abort').icon(IconName.Close), true, false))
                .child(full(button('button-icon-3').outline().label('Maximize').icon(Icon.component(IconName.Maximize)), true, false))
                .child(full(button('button-icon-4').child(hFlex().itemsCenter().gap2().child('Custom Child').child(Icon.component(IconName.ChevronDown)).child(Icon.component(IconName.Eye))), true, false))
                .child(full(button('button-icon-5-ghost').ghost().icon(IconName.Check).label('Confirm'), true, false))
                .child(full(button('button-icon-6-link').link().icon(IconName.Check).label('Link'), true, false))
                .child(full(button('button-icon-6-text').text().icon(IconName.Check).label('Text Button'), true, false)))
            .child(section('Progress')
                .description('Buttons can show determinate progress.')
                .child(hFlex()
                    .gap4()
                    .child(button('progress-button-1')
                        .primary()
                        .icon(ProgressCircle.component('circle-progress-1')
                            .color(theme.primaryForeground)
                            .value(25.))
                        .label('Installing...'))
                    .child(button('progress-button-2')
                        .icon(ProgressCircle.component('circle-progress-2').value(35.))
                        .label('Installing...'))
                    .child(button('progress-button-3')
                        .icon(ProgressCircle.component('circle-progress-3').value(68.))
                        .label('Installing...'))
                    .child(button('progress-button-4')
                        .icon(ProgressCircle.component('circle-progress-4').value(85.))
                        .label('Installing...'))))
            .child(section('Outline')
                .description('Outlined treatments keep actions visually quiet.')
                .w128()
                .child(full(button('button-outline-1').primary().outline().label('Primary Button'), true, false))
                .child(full(button('button-outline-2').outline().label('Normal Button'), true, false))
                .child(full(button('button-outline-4-danger').danger().outline().label('Danger Button'), true, false))
                .child(full(button('button-outline-4-warning').warning().outline().label('Warning Button'), true, false))
                .child(full(button('button-outline-4-success').success().outline().label('Success Button'), true, false))
                .child(full(button('button-outline-5-info').info().outline().label('Info Button'), true, false))
                .child(full(button('button-outline-5-ghost').ghost().outline().label('Ghost Button'), true, false))
                .child(full(button('button-outline-5-link').link().outline().label('Link Button'), true, false))
                .child(full(button('button-outline-5-text').text().outline().label('Text Button'), true, false)))
            .child(section('Dropdown')
                .description('A caret indicates an attached menu.')
                .w128()
                .child(full(button('button-dropdown-caret-primary').primary().dropdownCaret(true).label('Primary Button'), true, false))
                .child(full(button('button-dropdown-caret-default').label('Default Button').dropdownCaret(true), true, false))
                .child(full(button('button-outline-3').secondary().label('Secondary Button').dropdownCaret(true), true, false))
                .child(full(button('button-dropdown-caret-ghost').ghost().dropdownCaret(true).label('Ghost Button'), true, false))
                .child(full(button('button-dropdown-caret-link').link().dropdownCaret(true).label('Link Button'), true, false))
                .child(full(button('button-dropdown-caret-small').outline().dropdownCaret(true).label('Small Button'), true, false)))
            .child(section('Horizontal group').child(ButtonGroup.component('button-group')
                .outline()
                .disabled(disabled)
                .child(groupItem(button('button-one').label('One')))
                .child(groupItem(button('button-two').label('Two')))
                .child(groupItem(button('button-three').label('Three')))))
            .child(section('Vertical group').child(ButtonGroup.component('button-group-vertical')
                .outline()
                .layout(Vertical)
                .disabled(disabled)
                .child(groupItem(button('button-vertical-one').label('One')))
                .child(groupItem(button('button-vertical-two').label('Two')))
                .child(groupItem(button('button-vertical-three').label('Three')))))
            .child(section('Selection group')
                .description('Groups support single or multiple selection.')
                .child(ButtonGroup.component('toggle-button-group')
                    .outline()
                    .compact()
                    .multiple(toggleMultiple)
                    .child(button('disabled-toggle-button').label('Disabled').selected(disabled))
                    .child(button('loading-toggle-button').label('Loading').selected(loading))
                    .child(button('selected-toggle-button').label('Selected').selected(selected))
                    .child(button('compact-toggle-button').label('Compact').selected(compact))
                    .onClick(self.listener((view:ButtonStory, selected:Array<Int>, _, cx) -> {
                        view.disabled = selected.indexOf(0) >= 0;
                        view.loading = selected.indexOf(1) >= 0;
                        view.selected = selected.indexOf(2) >= 0;
                        view.compact = selected.indexOf(3) >= 0;
                        cx.notify();
                    }))))
            .child(section('Icon-only')
                .description('Compact actions can omit visible labels.')
                .child(full(button('icon-button-primary').icon(IconName.Search).loadingIcon(IconName.LoaderCircle).primary(), false, false))
                .child(full(button('icon-button-secondary').icon(IconName.Info).loading(true), false, false))
                .child(full(button('icon-button-danger').icon(IconName.Close).danger(), false, false))
                .child(full(button('icon-button-small-primary').icon(IconName.Search).primary(), false, false))
                .child(full(button('icon-button-outline').icon(IconName.Search).outline(), false, false))
                .child(full(button('icon-button-ghost').icon(IconName.ArrowLeft).loadingIcon(IconName.LoaderCircle).ghost(), false, false)))
            .child(section('Custom size')
                .description('A fixed pixel size is available for compact icon actions.')
                .child(full(button('icon-button-9')
                    .icon(IconName.Heart)
                    .size(px(24.))
                    .ghost(), false, false)))
            .child(section('Custom color')
                .child(full(button('button-6-custom')
                    .custom(customVariant)
                    .label('Custom Button'), true, false))
                .child(full(button('button-outline-6-custom')
                    .outline()
                    .custom(customVariant)
                    .label('Outline Button'), true, false))
                .child(full(button('button-outline-6-custom-1')
                    .outline()
                    .icon(IconName.Bell)
                    .custom(customVariant)
                    .label('Icon Button'), true, false)));
    }

}
