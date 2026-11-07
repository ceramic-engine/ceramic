// Ported from gpui-kit 0.8.1: crates/base/src/text/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

/** The content format of the text view. */
enum abstract TextViewFormat(Int) {
    /** Markdown view */
    var Markdown = 0;
    /** HTML view */
    var Html = 1;
}
