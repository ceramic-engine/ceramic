// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/decorations.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.App;
import gpui.Range;
import gpui.WeakEntity;

/**
 * An independently managed collection of `TextDecoration`s.
 *
 * This is the GPUI Component counterpart of Monaco's `IEditorDecorationsCollection`.
 * The state is an editor's (`EditorExtras` holds the collections).
 */
@:access(gpui.base.input.InputBaseState)
class TextDecorationCollection {

    final state:WeakEntity<InputBaseState>;

    final id:Int;

    public function new(state:WeakEntity<InputBaseState>, id:Int) {
        this.state = state;
        this.id = id;
    }

    static inline function extras(state:InputBaseState):EditorExtras {
        return cast state.extras;
    }

    /** Replace all decorations in this collection (Monaco `set`). */
    public function set(decorations:Array<TextDecoration>, cx:App):Void {
        state.tryUpdate(cx, (state, cx) -> {
            final decorations = DecorationCollections.normalize(state.text, decorations);
            if (extras(state).decorations.set(id, decorations))
                cx.notify();
        });
    }

    /** Add decorations to this collection (Monaco `append`). */
    public function append(decorations:Array<TextDecoration>, cx:App):Void {
        state.tryUpdate(cx, (state, cx) -> {
            final decorations = DecorationCollections.normalize(state.text, decorations);
            if (extras(state).decorations.append(id, decorations))
                cx.notify();
        });
    }

    /** Remove all decorations from this collection (Monaco `clear`). */
    public function clear(cx:App):Void {
        set([], cx);
    }

    /** Return the UTF-8 byte ranges in this collection (Monaco `getRanges`). */
    public function getRanges(cx:App):Array<Range> {
        final entity = state.upgrade();
        if (entity == null)
            return [];
        final decorations = extras(entity.read(cx)).decorations.get(id);
        return decorations == null ? [] : [for (decoration in decorations) decoration.range];
    }

}
