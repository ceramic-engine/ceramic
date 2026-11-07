// Ported from gpui-kit 0.8.1: crates/base/src/input/base/token_presentation.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.App;
import gpui.Window;

/** A click listener installed by a styled control. Not part of the supported API. */
typedef InlineTokenClickListener = (InlineTokenClickEvent, Window, App) -> Void;
