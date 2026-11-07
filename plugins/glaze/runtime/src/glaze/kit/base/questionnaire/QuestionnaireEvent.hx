// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.questionnaire;

enum QuestionnaireEvent {
    CurrentItemChanged(previous:Null<String>, current:Null<String>);
    AnswerChanged(change:QuestionnaireAnswerChange);
    Completed(submission:QuestionnaireSubmission);
    Submit(submission:QuestionnaireSubmission);
}
