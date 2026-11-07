// Ported from lsp-types 0.97 (src/lib.rs, CompletionContext), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * Contains additional information about the context in which a completion request is triggered.
 */
class CompletionContext {

    /** How the completion was triggered: 1 invoked, 2 trigger character, 3 for incomplete completions. */
    public var triggerKind:Int;

    /** The trigger character (a single character) that has trigger code complete. */
    public var triggerCharacter:Null<String>;

    public function new(triggerKind:Int, ?triggerCharacter:String) {
        this.triggerKind = triggerKind;
        this.triggerCharacter = triggerCharacter;
    }

}
