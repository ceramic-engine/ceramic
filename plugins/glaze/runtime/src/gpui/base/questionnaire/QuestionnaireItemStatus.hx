// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.questionnaire;

enum abstract QuestionnaireItemStatus(Int) {
    var Unanswered = 0;
    var Answered = 1;
    var Skipped = 2;

    public function toString():String {
        return switch (cast this : QuestionnaireItemStatus) {
            case Unanswered: 'Unanswered';
            case Answered: 'Answered';
            case Skipped: 'Skipped';
        }
    }
}
