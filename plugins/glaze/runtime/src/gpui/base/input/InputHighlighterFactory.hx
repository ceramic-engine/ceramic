// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/highlighting.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * Creates the highlighter of a language, or null (Rust `InputHighlighterFactory`).
 */
typedef InputHighlighterFactory = String -> Null<InputHighlighter>;
