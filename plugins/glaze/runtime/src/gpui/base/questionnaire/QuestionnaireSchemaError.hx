// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.questionnaire;

/**
 * A schema or answer that does not match the questionnaire. Compare with
 * `Type.enumEq`; `toString()` gives Rust's `Display` text.
 */
@:using(gpui.base.questionnaire.QuestionnaireSchemaError.QuestionnaireSchemaErrorTools)
enum QuestionnaireSchemaError {
    DuplicateItem(item:String);
    DuplicateChoice(item:String, choice:String);
    MultipleDefaultsForSingleItem(item:String);
    UnknownItem(item:String);
    UnknownChoice(item:String, choice:String);
    AnswerDoesNotMatchItem(item:String);
}

class QuestionnaireSchemaErrorTools {

    /** Rust `Display`. */
    public static function toString(self:QuestionnaireSchemaError):String {
        return switch self {
            case DuplicateItem(item): 'duplicate questionnaire item `' + item + '`';
            case DuplicateChoice(item, choice): 'duplicate choice `' + choice + '` in item `' + item + '`';
            case MultipleDefaultsForSingleItem(item): 'single-choice item `' + item + '` has more than one default answer';
            case UnknownItem(item): 'unknown questionnaire item `' + item + '`';
            case UnknownChoice(item, choice): 'unknown choice `' + choice + '` in item `' + item + '`';
            case AnswerDoesNotMatchItem(item): 'answer does not match item `' + item + '`';
        }
    }

}
