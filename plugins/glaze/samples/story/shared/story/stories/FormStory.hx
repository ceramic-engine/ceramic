// Ported from gpui-kit 0.8.1: crates/story/src/stories/form_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import gpui.Action;
import gpui.AnyView;
import gpui.App;
import gpui.Axis;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Window;
import gpui.base.ColorPicker.ColorPickerState;
import gpui.base.IndexPath;
import gpui.base.input.InputState;
import gpui.base.input.TextareaState;
import gpui.component.Size;
import gpui.component.button.Button;
import gpui.component.checkbox.Checkbox;
import gpui.component.colorpicker.ColorPicker.ColorSelect;
import gpui.component.form.Field;
import gpui.component.form.Form;
import gpui.component.input.Input;
import gpui.component.input.Textarea;
import gpui.component.searchablelist.SearchableVec;
import gpui.component.select.Select;
import gpui.component.select.SelectState;
import gpui.component.separator.Separator;
import gpui.component.switch_.Switch;
import gpui.component.theme.Color;
import gpui.component.time.DatePicker;
import story.Story;
import story.StoryActions.ChangeStorySize;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Lib.*;

enum FormToggle {
    Horizontal;
    MultipleColumns;
}

/** Rust `enum ToggleOption` (an action). */
@:action(namespace = form_story, noJson)
class FormToggleOption implements Action {
    public final value:FormToggle;
}

class FormStory extends Model implements Story {

    final focusHandle:FocusHandle;

    final namePrefixState:Entity<SelectState<String>>;

    final nameInput:Entity<InputState>;

    final emailInput:Entity<InputState>;

    final bioInput:Entity<TextareaState>;

    final colorState:Entity<ColorPickerState>;

    var subscribeEmail:Bool;

    final date:Entity<DatePickerState>;

    var layout:Axis;

    var size:Size;

    var columns:Int;

    public static function title():String {
        return 'Form';
    }

    public static function description():String {
        return 'Form to collect multiple inputs.';
    }

    public static function closable():Bool {
        return false;
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<FormStory> {
        return cx.newEntity((cx:Context<FormStory>) -> new FormStory(window, cx));
    }

    function new(window:Window, cx:Context<FormStory>) {
        super();
        namePrefixState = cx.newEntity((cx:Context<SelectState<String>>) ->
            new SelectState(new SearchableVec(['Mr.', 'Mrs.', 'Ms.', 'Dr.']), IndexPath.defaultValue(), window, cx));

        nameInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).defaultValue('Jason Lee'));
        colorState = cx.newEntity((cx:Context<ColorPickerState>) -> new ColorPickerState(window, cx).defaultValue(Color.indigo500()));

        emailInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Enter text here...'));
        bioInput = cx.newEntity((cx:Context<TextareaState>) -> new TextareaState(window, cx)
            .autoGrow(5, 20)
            .withPlaceholder('Enter text here...')
            .defaultValue('Hello 世界，this is GPUI component.'));
        date = cx.newEntity((cx:Context<DatePickerState>) -> new DatePickerState(window, cx));

        focusHandle = cx.focusHandle();
        subscribeEmail = false;
        layout = Vertical;
        size = Medium;
        columns = 1;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<FormStory> = cast cx;
        final isMultiColumn = columns > 1;
        final isHorizontal = layout == Horizontal;
        final horizontal = isHorizontal;
        final multipleColumns = isMultiColumn;

        final bioField = Form.field().label('Bio');
        if (layout == Vertical) bioField.itemsStart();
        bioField.child(new Textarea(bioInput).withSize(size))
            .descriptionFn((_, _) -> div().child('Use at most 100 words to describe yourself.'));

        final fullWidthField = Form.field().labelIndent(false);
        if (isMultiColumn) fullWidthField.colSpan(2);
        fullWidthField.child('This is a full width form field.');

        final switchField = Form.field();
        if (isHorizontal && isMultiColumn) switchField.labelIndent(false);
        if (isMultiColumn) switchField.colStart(1);
        switchField.child(new Switch('subscribe-newsletter')
            .withSize(size)
            .label('Subscribe our newsletter')
            .checked(subscribeEmail)
            .onClick(self.listener((this_:FormStory, checked:Bool, _, cx) -> {
                this_.subscribeEmail = checked;
                cx.notify();
            })));

        final checkboxField = Form.field();
        if (isHorizontal && isMultiColumn) checkboxField.labelIndent(false);
        checkboxField.child(new Checkbox('use-vertical-layout')
            .withSize(size)
            .label('Use this color for future events')
            .checked(subscribeEmail)
            .onClick(self.listener((this_:FormStory, checked:Bool, _, cx) -> {
                this_.subscribeEmail = checked;
                cx.notify();
            })));

        return vFlex()
            .id('form-story')
            .sizeFull()
            .p4()
            .justifyStart()
            .gap3()
            .onAction(ChangeStorySize, self.listener((this_:FormStory, action:ChangeStorySize, _, cx) -> {
                this_.size = action.value;
                cx.notify();
            }))
            .onAction(FormToggleOption, self.listener((this_:FormStory, action:FormToggleOption, _, cx) -> {
                switch action.value {
                    case Horizontal:
                        this_.layout = this_.layout == Horizontal ? Vertical : Horizontal;
                    case MultipleColumns:
                        this_.columns = this_.columns > 1 ? 1 : 2;
                }
                cx.notify();
            }))
            .child(storyToolbar(size).flexWrap().dropdownChild(new Button('form-options').label('Options'), (menu, _, _) -> menu
                .menuWithCheck('Horizontal', horizontal, new FormToggleOption(Horizontal))
                .menuWithCheck('Multiple columns', multipleColumns, new FormToggleOption(MultipleColumns))))
            .child(Separator.horizontal())
            .child(Form.vForm()
                .layout(layout)
                .withSize(size)
                .columns(columns)
                .labelWidth(px(isMultiColumn ? 100. : 140.))
                .child(Form.field().labelFn((_, _) -> 'Name').child(new Input(nameInput)
                    .withSize(size)
                    .pl0()
                    .prefix(div().w(px(90.)).child(new Select(namePrefixState)
                        .withSize(size)
                        .pr0()
                        .appearance(false)))))
                .child(Form.field()
                    .label('Email')
                    .child(new Input(emailInput).withSize(size))
                    .required(true))
                .child(bioField)
                .child(fullWidthField)
                .child(Form.field()
                    .label('Please select your birthday')
                    .description('Select your birthday, we will send you a gift.')
                    .child(new DatePicker(date).withSize(size)))
                .child(switchField)
                .child(Form.field()
                    .label('Theme color')
                    .child(new ColorSelect(colorState).withSize(size)))
                .child(checkboxField));
    }

}
