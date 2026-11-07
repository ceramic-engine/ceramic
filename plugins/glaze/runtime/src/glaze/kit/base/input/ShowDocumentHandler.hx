// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.App;
import glaze.Window;

/**
 * Host hook to show a document when following an LSP location
 * (Go to Definition), modeled after the `window/showDocument` request.
 *
 * Called before the built-in behavior. Return `true` if the host has shown
 * the document; return `false` to fall through to the default handling
 * (`external` URIs open in the browser, anything else jumps within the
 * current document).
 */
typedef ShowDocumentHandler = (params:LspShowDocumentParams, window:Window, cx:App) -> Bool;
