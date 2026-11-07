// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.questionnaire;

class QuestionnaireSubmission {

    final itemsValue:Array<QuestionnaireSubmissionItem>;

    @:allow(gpui.base.questionnaire)
    function new(items:Array<QuestionnaireSubmissionItem>) {
        this.itemsValue = items;
    }

    public inline function items():Array<QuestionnaireSubmissionItem> {
        return itemsValue;
    }

    public function answer(name:String):Null<QuestionnaireAnswer> {
        for (item in itemsValue) {
            if (item.name() == name) return item.answer();
        }
        return null;
    }

}

class QuestionnaireSubmissionItem {

    final nameValue:String;

    final statusValue:QuestionnaireItemStatus;

    final answerValue:QuestionnaireAnswer;

    @:allow(gpui.base.questionnaire)
    function new(name:String, status:QuestionnaireItemStatus, answer:QuestionnaireAnswer) {
        this.nameValue = name;
        this.statusValue = status;
        this.answerValue = answer;
    }

    public inline function name():String {
        return nameValue;
    }

    public inline function status():QuestionnaireItemStatus {
        return statusValue;
    }

    public inline function answer():QuestionnaireAnswer {
        return answerValue;
    }

}
