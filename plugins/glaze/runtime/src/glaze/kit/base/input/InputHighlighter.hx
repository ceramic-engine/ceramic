// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/highlighting.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Context;
import glaze.HighlightStyle;
import glaze.Range;
import glaze.Window;
import ropey.Rope;


/**
 * Parser-independent syntax highlighting seam consumed by the Base editor.
 *
 * Implementations own parsing, incremental state, and language-specific
 * behavior. Base only asks for styled ranges and fold candidates.
 *
 * Extend `InputHighlighterBase` to get the trait's default methods. The
 * context is the one of the editor state (Rust `Context<EditorState>`): the
 * port has a single non-generic `InputBaseState`.
 *
 * tree-sitter is not ported: no highlighter exists in the port yet, so an
 * editor without one behaves like gpui-kit without a language.
 */
interface InputHighlighter {

    function language():String;

    function update(edit:Null<InputEdit>, text:Rope, folding:Bool, window:Window, cx:Context<InputBaseState>):Void;

    /**
     * Apply several edits made as one change, such as typing with multiple
     * cursors. Each entry is an edit with the text as it stood right after
     * it, in the order the edits were applied.
     */
    function updateBatch(edits:Array<EditedText>, folding:Bool, window:Window, cx:Context<InputBaseState>):Void;

    /**
     * Return ordered, non-overlapping style runs that fully cover `range`.
     * Use a default `HighlightStyle` for text without a semantic style.
     */
    function styles(range:Range, resolver:HighlightStyleResolver):Array<StyledRange>;

    function foldRanges(text:Rope):Array<FoldRange>;

    function foldRangesForEdit(range:Range, text:Rope):Array<FoldRange>;

}

/**
 * The default methods of the `InputHighlighter` trait.
 */
abstract class InputHighlighterBase implements InputHighlighter {

    public abstract function language():String;

    public abstract function update(edit:Null<InputEdit>, text:Rope, folding:Bool, window:Window, cx:Context<InputBaseState>):Void;

    /** The default hands each edit to `update` in turn. Override it to reparse once for the whole change. */
    public function updateBatch(edits:Array<EditedText>, folding:Bool, window:Window, cx:Context<InputBaseState>):Void {
        for (edit in edits)
            update(edit.edit, edit.text, folding, window, cx);
    }

    public abstract function styles(range:Range, resolver:HighlightStyleResolver):Array<StyledRange>;

    public abstract function foldRanges(text:Rope):Array<FoldRange>;

    public function foldRangesForEdit(range:Range, text:Rope):Array<FoldRange> {
        return foldRanges(text);
    }

}
