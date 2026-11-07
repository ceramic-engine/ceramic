// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/overlay.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The editor overlays an overlay action handler is called for.
 */
enum abstract InputOverlayKind(Int) {

    var Completion = 0;

    var CodeAction = 1;

}
