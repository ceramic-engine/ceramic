// Ported from gpui-kit 0.8.1: crates/base/src/text/text_view.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.AnyElement;
import gpui.App;
import gpui.Window;

/** Type for code block actions generator function. */
typedef CodeBlockActionsFn = (codeBlock:CodeBlock, window:Window, cx:App) -> AnyElement;
