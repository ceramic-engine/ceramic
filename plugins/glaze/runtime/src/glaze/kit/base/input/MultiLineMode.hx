// Ported from gpui-kit 0.8.1: crates/base/src/input/base/kind.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The modes whose layout spans more than one line: `TextareaMode` and
 * `EditorMode` (a marker).
 *
 * Soft wrap, wrapping indent and the search session are meaningless in a
 * single-line field, but shared by the two multi-line modes.
 */
interface MultiLineMode extends InputModeKind {}
