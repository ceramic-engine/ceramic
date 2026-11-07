// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.questionnaire;

import glaze.Entity;
import glaze.kit.base.input.InputState;

/**
 * Describes the optional freeform answer owned by an item.
 */
class QuestionnaireInputDefinition {

    var stateValue:Entity<InputState>;

    var accessibilityLabelValue:String;

    var disabledValue:Bool = false;

    public function new(state:Entity<InputState>, accessibilityLabel:String) {
        this.stateValue = state;
        this.accessibilityLabelValue = accessibilityLabel;
    }

    /** Rust `clone()`. */
    public function clone():QuestionnaireInputDefinition {
        final copy = new QuestionnaireInputDefinition(stateValue, accessibilityLabelValue);
        copy.disabledValue = disabledValue;
        return copy;
    }

    public function withDisabled(disabled:Bool):QuestionnaireInputDefinition {
        final copy = clone();
        copy.disabledValue = disabled;
        return copy;
    }

    public inline function state():Entity<InputState> {
        return stateValue;
    }

    public inline function accessibilityLabel():String {
        return accessibilityLabelValue;
    }

    public inline function isDisabled():Bool {
        return disabledValue;
    }

}
