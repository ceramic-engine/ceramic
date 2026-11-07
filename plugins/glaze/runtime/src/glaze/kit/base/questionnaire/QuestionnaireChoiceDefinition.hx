// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.questionnaire;

/**
 * Describes one selectable answer.
 *
 * Builders return a modified copy, like the Rust value builders.
 */
class QuestionnaireChoiceDefinition {

    var valueValue:String;

    var accessibilityLabelValue:String;

    var descriptionValue:Null<String> = null;

    var disabledValue:Bool = false;

    var defaultSelectedValue:Bool = false;

    public function new(value:String, accessibilityLabel:String) {
        this.valueValue = value;
        this.accessibilityLabelValue = accessibilityLabel;
    }

    /** Rust `clone()`. */
    public function clone():QuestionnaireChoiceDefinition {
        final copy = new QuestionnaireChoiceDefinition(valueValue, accessibilityLabelValue);
        copy.descriptionValue = descriptionValue;
        copy.disabledValue = disabledValue;
        copy.defaultSelectedValue = defaultSelectedValue;
        return copy;
    }

    public function withDescription(description:String):QuestionnaireChoiceDefinition {
        final copy = clone();
        copy.descriptionValue = description;
        return copy;
    }

    public function withDisabled(disabled:Bool):QuestionnaireChoiceDefinition {
        final copy = clone();
        copy.disabledValue = disabled;
        return copy;
    }

    public function withDefaultSelected(selected:Bool):QuestionnaireChoiceDefinition {
        final copy = clone();
        copy.defaultSelectedValue = selected;
        return copy;
    }

    public inline function value():String {
        return valueValue;
    }

    public inline function accessibilityLabel():String {
        return accessibilityLabelValue;
    }

    public inline function description():Null<String> {
        return descriptionValue;
    }

    public inline function isDisabled():Bool {
        return disabledValue;
    }

    public inline function isDefaultSelected():Bool {
        return defaultSelectedValue;
    }

}
