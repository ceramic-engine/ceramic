// Ported from gpui-kit 0.8.1: crates/base/src/text/text_view.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.App;
import glaze.ClickEvent;
import glaze.Window;

/** Handles a click on a rendered link. */
typedef LinkClickHandlerFn = (url:String, event:ClickEvent, window:Window, cx:App) -> Void;
