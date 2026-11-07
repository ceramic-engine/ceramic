// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.questionnaire;

class QuestionnaireNavigationState {

    final previousVisible:Bool;

    final nextVisible:Bool;

    final skipVisible:Bool;

    final submitVisible:Bool;

    final confirmable:Bool;

    /** Without arguments, Rust `Default` (everything false). */
    @:allow(glaze.kit.base.questionnaire)
    function new(previousVisible:Bool = false, nextVisible:Bool = false, skipVisible:Bool = false, submitVisible:Bool = false, confirmable:Bool = false) {
        this.previousVisible = previousVisible;
        this.nextVisible = nextVisible;
        this.skipVisible = skipVisible;
        this.submitVisible = submitVisible;
        this.confirmable = confirmable;
    }

    public inline function isPreviousVisible():Bool {
        return previousVisible;
    }

    public inline function isNextVisible():Bool {
        return nextVisible;
    }

    public inline function isSkipVisible():Bool {
        return skipVisible;
    }

    public inline function isSubmitVisible():Bool {
        return submitVisible;
    }

    public inline function isConfirmable():Bool {
        return confirmable;
    }

}
