// Ported from gpui-kit 0.8.1: crates/base/src/input/base/mode.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The syntax highlighter of a code editor, shared by the clones of its
 * layout mode (Rust `Rc<RefCell<Option<Box<dyn InputHighlighter>>>>`).
 */
class HighlighterCell {

    public var value:Null<InputHighlighter> = null;

    public function new() {}

}
