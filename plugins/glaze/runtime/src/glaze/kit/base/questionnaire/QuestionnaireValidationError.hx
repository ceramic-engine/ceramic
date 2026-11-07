// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.questionnaire;

/**
 * Why an item currently fails validation.
 *
 * `Required` and `Unanswered` carry no text: base does not own product copy,
 * so the presentation layer supplies the localized sentence. `Message` is the
 * text a validator or the host already wrote. Compare with `Type.enumEq`.
 */
@:using(glaze.kit.base.questionnaire.QuestionnaireValidationError.QuestionnaireValidationErrorTools)
enum QuestionnaireValidationError {
    /** A required item has no answer. */
    Required;
    /** An optional item has no answer and has not been skipped. */
    Unanswered;
    /** A validator or the host supplied this text. */
    Message(message:String);
}

class QuestionnaireValidationErrorTools {

    /** The text the host or a validator wrote, if this is not a built-in reason. */
    public static function message(self:QuestionnaireValidationError):Null<String> {
        return switch self {
            case Message(message): message;
            case _: null;
        }
    }

}
