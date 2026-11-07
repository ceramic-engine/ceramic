// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/text_wrapper.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * Controls how soft-wrapped continuation lines are indented.
 */
enum abstract WrappingIndent(Int) {

    /** Continuation lines start flush-left at the full editor width. */
    var None = 0;

    /** Continuation lines keep the same indentation as the first line (the default). */
    var Same = 1;

    public static inline function defaultValue():WrappingIndent {
        return Same;
    }

    public function toString():String {
        return this == 0 ? 'None' : 'Same';
    }

}
