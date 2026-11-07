// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.questionnaire;

class QuestionnaireProgressState {

    final currentValue:Int;

    final totalValue:Int;

    @:allow(glaze.kit.base.questionnaire)
    function new(current:Int, total:Int) {
        this.currentValue = current;
        this.totalValue = total;
    }

    public inline function current():Int {
        return currentValue;
    }

    public inline function total():Int {
        return totalValue;
    }

}
