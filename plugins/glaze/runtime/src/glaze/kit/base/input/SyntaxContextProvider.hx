// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/highlighting.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import ropey.Rope;

/**
 * Answers syntax context for editing decisions (pairing, skip, indent).
 *
 * Created per editor by the application's `LanguageProvider`.
 * Base never imports a parser; implementations live in UI crates or apps.
 */
interface SyntaxContextProvider {

    function contextAt(text:Rope, offset:Int):SyntaxContext;

}
