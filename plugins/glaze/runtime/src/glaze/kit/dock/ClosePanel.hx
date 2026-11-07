// Ported from gpui-kit 0.8.1: crates/component/src/dock/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dock;

import glaze.Action;

/**
 * Close the focused tab group's displayed panel (Rust `actions!(dock, [.., ClosePanel])`).
 */
@:action(namespace = dock) class ClosePanel implements Action {}
