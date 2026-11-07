// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.questionnaire;

/**
 * Validates one questionnaire item against the current questionnaire answers.
 *
 * Rust returns `Result<(), SharedString>`: here `null` is `Ok(())` and a
 * string is the `Err` message.
 */
typedef QuestionnaireValidator = (context:QuestionnaireValidationContext) -> Null<String>;

/**
 * Describes one ordered questionnaire item.
 *
 * Builders return a modified copy, like the Rust value builders.
 */
class QuestionnaireItemDefinition {

    var nameValue:String;

    var accessibilityLabelValue:String;

    var descriptionValue:Null<String> = null;

    var requiredValue:Bool = false;

    var multipleValue:Bool = false;

    var disabledValue:Bool = false;

    var choicesValue:Array<QuestionnaireChoiceDefinition> = [];

    var inputValue:Null<QuestionnaireInputDefinition> = null;

    var validatorValue:Null<QuestionnaireValidator> = null;

    public function new(name:String, accessibilityLabel:String) {
        this.nameValue = name;
        this.accessibilityLabelValue = accessibilityLabel;
    }

    /** Rust `clone()`. */
    public function clone():QuestionnaireItemDefinition {
        final copy = new QuestionnaireItemDefinition(nameValue, accessibilityLabelValue);
        copy.descriptionValue = descriptionValue;
        copy.requiredValue = requiredValue;
        copy.multipleValue = multipleValue;
        copy.disabledValue = disabledValue;
        copy.choicesValue = choicesValue.copy();
        copy.inputValue = inputValue;
        copy.validatorValue = validatorValue;
        return copy;
    }

    public function withDescription(description:String):QuestionnaireItemDefinition {
        final copy = clone();
        copy.descriptionValue = description;
        return copy;
    }

    public function withRequired(required:Bool):QuestionnaireItemDefinition {
        final copy = clone();
        copy.requiredValue = required;
        return copy;
    }

    public function withMultiple(multiple:Bool):QuestionnaireItemDefinition {
        final copy = clone();
        copy.multipleValue = multiple;
        return copy;
    }

    public function withDisabled(disabled:Bool):QuestionnaireItemDefinition {
        final copy = clone();
        copy.disabledValue = disabled;
        return copy;
    }

    public function withChoices(choices:Array<QuestionnaireChoiceDefinition>):QuestionnaireItemDefinition {
        final copy = clone();
        copy.choicesValue = choices.copy();
        return copy;
    }

    public function withChoice(choice:QuestionnaireChoiceDefinition):QuestionnaireItemDefinition {
        final copy = clone();
        copy.choicesValue.push(choice);
        return copy;
    }

    public function withInput(input:QuestionnaireInputDefinition):QuestionnaireItemDefinition {
        final copy = clone();
        copy.inputValue = input;
        return copy;
    }

    public function withValidator(validator:QuestionnaireValidator):QuestionnaireItemDefinition {
        final copy = clone();
        copy.validatorValue = validator;
        return copy;
    }

    public inline function name():String {
        return nameValue;
    }

    public inline function accessibilityLabel():String {
        return accessibilityLabelValue;
    }

    public inline function description():Null<String> {
        return descriptionValue;
    }

    public inline function isRequired():Bool {
        return requiredValue;
    }

    public inline function isMultiple():Bool {
        return multipleValue;
    }

    public inline function isDisabled():Bool {
        return disabledValue;
    }

    public inline function choices():Array<QuestionnaireChoiceDefinition> {
        return choicesValue;
    }

    public inline function input():Null<QuestionnaireInputDefinition> {
        return inputValue;
    }

    public inline function validator():Null<QuestionnaireValidator> {
        return validatorValue;
    }

    public function toString():String {
        return 'QuestionnaireItemDefinition { name: "' + nameValue + '", accessibility_label: "' + accessibilityLabelValue + '", required: ' + requiredValue
            + ', multiple: ' + multipleValue + ', disabled: ' + disabledValue + ', choices: ' + choicesValue.length + ', input: ' + (inputValue != null)
            + ', validator: ' + (validatorValue != null ? '<validator>' : 'None') + ' }';
    }

}
