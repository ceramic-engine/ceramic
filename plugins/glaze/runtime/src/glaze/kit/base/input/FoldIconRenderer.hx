// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/highlighting.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.AnyElement;

/**
 * Renders the fold icon of a line: (line, folded) to element.
 */
typedef FoldIconRenderer = (Int, Bool) -> AnyElement;
