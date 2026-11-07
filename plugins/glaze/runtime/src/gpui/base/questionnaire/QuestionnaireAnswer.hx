// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.questionnaire;

using StringTools;

/**
 * A serializable-in-spirit answer snapshot. Input drafts are deliberately excluded.
 *
 * The Rust fields `choices` and `freeform` are `choiceValues` and
 * `freeformValue` here (their getters keep the Rust names).
 */
class QuestionnaireAnswer {

    @:allow(gpui.base.questionnaire)
    var choiceValues:Array<String> = [];

    @:allow(gpui.base.questionnaire)
    var freeformValue:Null<String> = null;

    public function new() {}

    /** Rust `clone()`. */
    public function clone():QuestionnaireAnswer {
        final copy = new QuestionnaireAnswer();
        copy.choiceValues = choiceValues.copy();
        copy.freeformValue = freeformValue;
        return copy;
    }

    public function withChoices(choices:Array<String>):QuestionnaireAnswer {
        final copy = clone();
        copy.choiceValues = [];
        for (choice in choices) {
            if (copy.choiceValues.indexOf(choice) == -1) {
                copy.choiceValues.push(choice);
            }
        }
        return copy;
    }

    public function withFreeform(value:String):QuestionnaireAnswer {
        final copy = clone();
        copy.freeformValue = !isBlank(value) ? value : null;
        return copy;
    }

    public inline function choices():Array<String> {
        return choiceValues;
    }

    public inline function freeform():Null<String> {
        return freeformValue;
    }

    public function isEmpty():Bool {
        return choiceValues.length == 0 && freeformValue == null;
    }

    /** Rust `PartialEq`. */
    public function equals(other:Null<QuestionnaireAnswer>):Bool {
        if (other == null) return false;
        if (freeformValue != other.freeformValue) return false;
        if (choiceValues.length != other.choiceValues.length) return false;
        for (i in 0...choiceValues.length) {
            if (choiceValues[i] != other.choiceValues[i]) return false;
        }
        return true;
    }

    /**
     * Rust `str::trim().is_empty()`: only whitespace (Unicode White_Space).
     */
    @:allow(gpui.base.questionnaire)
    static function isBlank(value:String):Bool {
        return isWhitespaceOnly(value);
    }

    /**
     * Whether `value` holds only Unicode White_Space characters, like
     * Rust's `trim()` sees them.
     */
    public static function isWhitespaceOnly(value:String):Bool {
        for (code in new haxe.iterators.StringIteratorUnicode(value)) {
            if (!isUnicodeWhitespace(code)) return false;
        }
        return true;
    }

    static function isUnicodeWhitespace(code:Int):Bool {
        return (code >= 0x09 && code <= 0x0D) || code == 0x20 || code == 0x85 || code == 0xA0 || code == 0x1680
            || (code >= 0x2000 && code <= 0x200A) || code == 0x2028 || code == 0x2029 || code == 0x202F || code == 0x205F || code == 0x3000;
    }

    public function toString():String {
        return 'QuestionnaireAnswer { choices: [' + [for (c in choiceValues) '"' + c + '"'].join(', ') + '], freeform: '
            + (freeformValue != null ? 'Some("' + freeformValue + '")' : 'None') + ' }';
    }

}
