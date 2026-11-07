// Ported from gpui-kit 0.8.1: crates/base/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

/**
 * Rust `enum PanelEvent`, emitted by panels (`cx.emit`).
 */
enum PanelEvent {
    ZoomIn;
    ZoomOut;
    LayoutChanged;
}

