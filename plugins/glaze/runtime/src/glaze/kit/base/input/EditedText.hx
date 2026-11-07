// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/highlighting.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import ropey.Rope;

/**
 * An edit with the text as it stood right after it (Rust tuple `(InputEdit, Rope)`).
 */
class EditedText {

    public final edit:InputEdit;

    public final text:Rope;

    public inline function new(edit:InputEdit, text:Rope) {
        this.edit = edit;
        this.text = text;
    }

}
