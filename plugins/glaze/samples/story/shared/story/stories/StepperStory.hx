// Ported from gpui-kit 0.8.1: crates/story/src/stories/stepper_story.rs
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
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.stepper.Stepper;
import glaze.kit.stepper.StepperItem;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

@:action(namespace = stepper_story) private class ToggleDisabled implements Action {}

class StepperStory extends Model implements Story {

    public static function title():String {
        return 'Stepper';
    }

    public static function description():String {
        return 'A step-by-step process for users to navigate through a series of steps.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<StepperStory> {
        return cx.newEntity((c:Context<StepperStory>) -> new StepperStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var size:Size = glaze.kit.Size.Medium;

    @observe var stepper0Step:Int = 1;

    @observe var stepper1Step:Int = 0;

    @observe var stepper2Step:Int = 2;

    @observe var stepper3Step:Int = 0;

    @observe var disabled:Bool = false;

    function new(_:Window, cx:Context<StepperStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final disabled = this.disabled;
        return vFlex()
            .wFull()
            .gap3()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .onAction(ToggleDisabled, (_, _, _) -> this.disabled = !this.disabled)
            .child(storyToolbar(size).dropdownChild(new Button('stepper-options').label('Options'),
                (menu, _, _) -> menu.menuWithCheck('Disabled', disabled, new ToggleDisabled())))
            .child(section('Horizontal Stepper').w(px(480.)).vFlex().child(new Stepper('stepper0')
                .wFull()
                .withSize(size)
                .disabled(disabled)
                .selectedIndex(stepper0Step)
                .items([
                    new StepperItem().child('Step 1'),
                    new StepperItem().child('Step 2'),
                    new StepperItem().child('Step 3'),
                ])
                .onClick((step, _, _) -> stepper0Step = step)))
            .child(section('Icon Stepper').w(px(480.)).vFlex().child(new Stepper('stepper1')
                .wFull()
                .withSize(size)
                .disabled(disabled)
                .selectedIndex(stepper1Step)
                .items([
                    new StepperItem().icon(IconName.Calendar).child('Order Details'),
                    new StepperItem().icon(IconName.Inbox).child('Shipping'),
                    new StepperItem().icon(IconName.Frame).child('Preview'),
                    new StepperItem().icon(IconName.Info).child('Finish'),
                ])
                .onClick((step, _, _) -> stepper1Step = step)))
            .child(section('Vertical Stepper').w(px(480.)).vFlex().child(new Stepper('stepper3')
                .vertical()
                .withSize(size)
                .disabled(disabled)
                .selectedIndex(stepper2Step)
                .itemsCenter()
                .items([
                    new StepperItem().pb8().icon(IconName.Building2).child(vFlex().child('Step 1').child('Description for step 1.')),
                    new StepperItem().pb8().icon(IconName.Asterisk).child(vFlex().child('Step 2').child('Description for step 2.')),
                    new StepperItem().pb8().icon(IconName.Folder).child(vFlex().child('Step 3').child('Description for step 3.')),
                    new StepperItem().icon(IconName.CircleCheck).child(vFlex().child('Step 4').child('Description for step 4.')),
                ])
                .onClick((step, _, _) -> stepper2Step = step)))
            .child(section('Text Center').w(px(480.)).vFlex().child(new Stepper('stepper4')
                .withSize(size)
                .disabled(disabled)
                .selectedIndex(stepper3Step)
                .textCenter(true)
                .items([
                    new StepperItem().child(vFlex().itemsCenter().child('Step 1').child('Desc for step 1.')),
                    new StepperItem().child(vFlex().itemsCenter().child('Step 2').child('Desc for step 2.')),
                    new StepperItem().child(vFlex().itemsCenter().child('Step 3').child('Desc for step 3.')),
                ])
                .onClick((step, _, _) -> stepper3Step = step)));
    }

}
