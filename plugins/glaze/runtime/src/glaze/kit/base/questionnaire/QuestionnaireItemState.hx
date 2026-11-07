// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.questionnaire;

class QuestionnaireItemState {

    final nameValue:String;

    final statusValue:QuestionnaireItemStatus;

    final requiredValue:Bool;

    final multipleValue:Bool;

    final disabledValue:Bool;

    final invalidValue:Bool;

    final hasInputValue:Bool;

    @:allow(gpui.base.questionnaire)
    function new(name:String, status:QuestionnaireItemStatus, required:Bool, multiple:Bool, disabled:Bool, invalid:Bool, hasInput:Bool) {
        this.nameValue = name;
        this.statusValue = status;
        this.requiredValue = required;
        this.multipleValue = multiple;
        this.disabledValue = disabled;
        this.invalidValue = invalid;
        this.hasInputValue = hasInput;
    }

    public inline function name():String {
        return nameValue;
    }

    public inline function status():QuestionnaireItemStatus {
        return statusValue;
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

    public inline function isInvalid():Bool {
        return invalidValue;
    }

    public inline function hasInput():Bool {
        return hasInputValue;
    }

}
