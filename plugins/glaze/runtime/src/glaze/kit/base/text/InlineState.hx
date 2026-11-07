// Ported from gpui-kit 0.8.1: crates/base/src/text/inline.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.base.input.Selection;

/**
 * The inline text state, shared (Rust `Arc<Mutex<InlineState>>`) between the
 * document nodes and the elements rendering them, to keep the selection.
 */
class InlineState {

    /** The text that actually rendering, matched with selection. */
    @:allow(gpui.base.text)
    var text:String = '';

    @:allow(gpui.base.text)
    var selection:Null<Selection> = null;

    /**
     * Set only through the editor host API (`Paragraph.withLeafKey`): the
     * leaf reports its geometry to the collector installed by
     * `EditorHost.collectLeafGeometry`. `null` for every plain `TextView`.
     */
    @:allow(gpui.base.text)
    var editorKey:Null<Int> = null;

    /**
     * The shaped text an `Inline` of this state handed over to the next
     * frame (Rust keeps it in a thread-local table keyed by the state's
     * address, see `RetainedLayout`). Released with the state.
     *
     * Rust also keeps `cleanup_senders` here (the UI owners to wake when the
     * state drops, so that they sweep the table): the slot makes them
     * unnecessary.
     */
    @:allow(gpui.base.text)
    var retainedLayout:Null<Inline.RetainedLayout> = null;

    public function new() {}

    /** Save actually rendered text for selected text to use. */
    @:allow(gpui.base.text)
    function setText(text:String):Void {
        this.text = text;
    }

    public function equals(other:Null<InlineState>):Bool {
        return other != null && text == other.text && (selection == null ? other.selection == null : selection.equals(other.selection))
            && editorKey == other.editorKey;
    }

}
