// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/types.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.questionnaire;

/**
 * The effective answers of the enabled items, in schema order.
 */
class QuestionnaireAnswers {

    final names:Array<String>;

    final values:Array<QuestionnaireAnswer>;

    @:allow(glaze.kit.base.questionnaire)
    function new(names:Array<String>, values:Array<QuestionnaireAnswer>) {
        this.names = names;
        this.values = values;
    }

    public function get(name:String):Null<QuestionnaireAnswer> {
        for (i in 0...names.length) {
            if (names[i] == name) return values[i];
        }
        return null;
    }

    /** Rust `iter()`: the (name, answer) pairs in order. */
    public function iter():Array<{name:String, answer:QuestionnaireAnswer}> {
        return [for (i in 0...names.length) {name: names[i], answer: values[i]}];
    }

    public inline function len():Int {
        return names.length;
    }

    public inline function isEmpty():Bool {
        return names.length == 0;
    }

    /** Rust `PartialEq`. */
    public function equals(other:Null<QuestionnaireAnswers>):Bool {
        if (other == null || other.names.length != names.length) return false;
        for (i in 0...names.length) {
            if (names[i] != other.names[i] || !values[i].equals(other.values[i])) return false;
        }
        return true;
    }

}
