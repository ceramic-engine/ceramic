// Ported from gpui-kit 0.8.1: crates/component/src/dock/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dock;

import glaze.Action;

/**
 * Zoom the focused tab group in or out (Rust `actions!(dock, [ToggleZoom, ..])`).
 */
@:action(namespace = dock) class ToggleZoom implements Action {}
