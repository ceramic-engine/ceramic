// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/decorations.rs (`impl InputBaseState<EditorMode>`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Context;

/**
 * The decoration methods of an editor state (Rust `impl InputBaseState<EditorMode>`
 * in `decorations.rs`), as static extensions: see `InputSearchExt`. They
 * only exist for the code editor (`EditorExtras` holds the collections).
 */
@:access(glaze.kit.base.input.InputBaseState)
class InputDecorationsExt {

    static inline function extras(state:InputBaseState):EditorExtras {
        return cast state.extras;
    }

    /**
     * Create an independently owned collection of geometric range decorations.
     *
     * Ranges use UTF-8 byte offsets and the same tracking as text decorations:
     * insertion at either edge does not expand the range, insertion inside does,
     * replacement clips overlapping anchors, and deletion removes empty ranges.
     * Undo, redo, whole-document replacement and formatting apply these same edit
     * transforms; decorations themselves are not undo history, so deleted ranges
     * are not resurrected by undo. Folding changes projection, not stored ranges.
     *
     * Fills paint behind frames; within each style, later collections/items paint
     * over earlier ones. Neither affects text layout, hit testing or focus. The
     * default color is the editor foreground (12% opacity for fills).
     * Collections live until explicitly disposed or the editor is dropped.
     */
    public static function createRangeDecorationsCollection(self:InputBaseState, decorations:Array<RangeDecoration>, cx:Context<InputBaseState>):RangeDecorationCollection {
        final id = extras(self).rangeDecorationCollections.create(DecorationCollections.normalize(self.text, decorations));
        cx.notify();
        return new RangeDecorationCollection(cx.entity().downgrade(), id);
    }

    /**
     * Create an independently managed collection of text decorations.
     *
     * This follows Monaco's `createDecorationsCollection` ownership model.
     * Ranges use UTF-8 byte offsets into the value.
     *
     * Decoration ranges follow text edits and do not need to be set again
     * after each change. Insertions at a range boundary do not expand the
     * range (Monaco's `NeverGrowsWhenTypingAtEdges`). Decorations are not
     * rendered while the input is masked. Collections live until their state
     * is dropped.
     *
     * Collections are layered in insertion order; the first collection wins
     * when overlapping decorations set the same `HighlightStyle` property.
     */
    public static function createDecorationsCollection(self:InputBaseState, decorations:Array<TextDecoration>, cx:Context<InputBaseState>):TextDecorationCollection {
        final decorations = DecorationCollections.normalize(self.text, decorations);
        final id = extras(self).decorations.create(decorations);
        cx.notify();
        return new TextDecorationCollection(cx.entity().downgrade(), id);
    }

}
