// Ported from lsp-types 0.97 (src/lib.rs, InlineCompletionContext), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * Provides information about the context in which an inline completion was requested.
 */
class InlineCompletionContext {

    /** How the completion was triggered: 0 invoked, 1 automatic. */
    public var triggerKind:Int;

    public function new(triggerKind:Int) {
        this.triggerKind = triggerKind;
    }

}
