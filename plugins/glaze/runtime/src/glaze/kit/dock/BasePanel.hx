// Ported from gpui-kit 0.8.1: crates/component/src/dock/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.dock;

/**
 * The behavior half of the panel traits, which every panel implements
 * alongside `Panel` (Rust `pub use gpui_base::dock::Panel as BasePanel`).
 * Exported under this name because `Panel` in this package is the
 * presentation half that extends it.
 */
typedef BasePanel = gpui.base.dock.Panel;
