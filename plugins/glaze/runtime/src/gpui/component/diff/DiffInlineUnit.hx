// Ported from gpui-kit 0.8.1: crates/component/src/diff/presentation.rs (`DiffInlineUnit`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

/**
 * The unit inline changes are compared and emphasized in.
 */
enum abstract DiffInlineUnit(Int) {

    /**
     * Words and punctuation; changed words separated only by whitespace are
     * emphasized as one run.
     */
    var Word;

    /** Grapheme clusters. */
    var Character;

}
