// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.questionnaire;

class QuestionnaireAnswerChange {

    final itemValue:String;

    final answerValue:QuestionnaireAnswer;

    final statusValue:QuestionnaireItemStatus;

    @:allow(glaze.kit.base.questionnaire)
    function new(item:String, answer:QuestionnaireAnswer, status:QuestionnaireItemStatus) {
        this.itemValue = item;
        this.answerValue = answer;
        this.statusValue = status;
    }

    public inline function item():String {
        return itemValue;
    }

    public inline function answer():QuestionnaireAnswer {
        return answerValue;
    }

    public inline function status():QuestionnaireItemStatus {
        return statusValue;
    }

}
