// Ported from gpui-kit 0.8.1: crates/base/src/text/text_view.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.App;
import gpui.Bounds;
import gpui.Window;

/** Kept by the element only, so unlike the handlers the state carries, it may hold a `ScrollHandle`. */
typedef RevealHandlerFn = (line:Bounds, window:Window, cx:App) -> Void;
