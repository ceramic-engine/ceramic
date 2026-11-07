// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.questionnaire;

/**
 * Immutable validation input. Validators cannot mutate the questionnaire.
 */
class QuestionnaireValidationContext {

    final itemValue:String;

    final answerValue:QuestionnaireAnswer;

    final answersValue:QuestionnaireAnswers;

    @:allow(glaze.kit.base.questionnaire)
    function new(item:String, answer:QuestionnaireAnswer, answers:QuestionnaireAnswers) {
        this.itemValue = item;
        this.answerValue = answer;
        this.answersValue = answers;
    }

    public inline function item():String {
        return itemValue;
    }

    public inline function answer():QuestionnaireAnswer {
        return answerValue;
    }

    public inline function answers():QuestionnaireAnswers {
        return answersValue;
    }

}
