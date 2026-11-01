// Ported from lsp-types 0.97 (src/lib.rs, DiagnosticTag), as used by gpui-kit 0.8.1: crates/base/src/input/editor/diagnostics.rs
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * The diagnostic tags (an open set of integers in lsp-types).
 */
enum abstract DiagnosticTag(Int) from Int to Int {

    /** Unused or unnecessary code. */
    var UNNECESSARY = 1;

    /** Deprecated or obsolete code. */
    var DEPRECATED = 2;

}
