// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/highlighting.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * Where in the syntax tree an offset sits, for editing decisions.
 *
 * Parser-independent: `gpui-component` answers from tree-sitter, apps may
 * answer heuristically. No provider installed means `Code`.
 */
enum abstract SyntaxContext(Int) {

    var Code = 0;

    var String = 1;

    var Comment = 2;

    public function toString():std.String {
        return switch (cast this:SyntaxContext) {
            case Code: 'Code';
            case String: 'String';
            case Comment: 'Comment';
        }
    }

}
