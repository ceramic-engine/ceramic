// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.questionnaire;

class QuestionnaireChoiceState {

    final valueValue:String;

    final selectedValue:Bool;

    final disabledValue:Bool;

    final invalidValue:Bool;

    final shortcutValue:Null<String>;

    @:allow(gpui.base.questionnaire)
    function new(value:String, selected:Bool, disabled:Bool, invalid:Bool, shortcut:Null<String>) {
        this.valueValue = value;
        this.selectedValue = selected;
        this.disabledValue = disabled;
        this.invalidValue = invalid;
        this.shortcutValue = shortcut;
    }

    public inline function value():String {
        return valueValue;
    }

    public inline function isSelected():Bool {
        return selectedValue;
    }

    public inline function isDisabled():Bool {
        return disabledValue;
    }

    public inline function isInvalid():Bool {
        return invalidValue;
    }

    public inline function shortcut():Null<String> {
        return shortcutValue;
    }

}
