// Ported from gpui-pre 0.3.10: src/text_system/line_layout.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Rust's `Result<usize, usize>` returned by index lookups: `Ok` when the
 * position is inside the text, `Err` with the closest boundary otherwise.
 */
enum IndexResult {
    Ok(index:Int);
    Err(index:Int);
}
