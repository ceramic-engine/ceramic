// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/overlay.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Range;

/**
 * The hover popover of an editor: the symbol it is anchored to and its content.
 */
class HoverPopoverState {

    public var symbolRange:Range;

    public var hover:LspHover;

    public function new(symbolRange:Range, hover:LspHover) {
        this.symbolRange = symbolRange;
        this.hover = hover;
    }

}
