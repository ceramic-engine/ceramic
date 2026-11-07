// Ported from gpui-kit 0.8.1: crates/component/src/dock/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.dock;

/**
 * `gpui.base.dock.PaneNode.PaneRef`, re-exported so a consumer of the component dock never has to
 * depend on `gpui.base.dock` directly to write a skin or read a container's
 * state (Rust `pub use gpui_base::dock::PaneRef`).
 */
typedef PaneRef = gpui.base.dock.PaneNode.PaneRef;
