// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/decorations.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.App;
import gpui.Range;
import gpui.WeakEntity;

/**
 * An independently managed collection of geometric range decorations.
 *
 * Clones address the same collection. Dropping a handle does not clear it; use
 * `clear` to empty it or `dispose` to release it permanently.
 * Operations on a disposed collection or a dropped editor are harmless no-ops.
 */
@:access(gpui.base.input.InputBaseState)
class RangeDecorationCollection {

    final state:WeakEntity<InputBaseState>;

    final id:Int;

    public function new(state:WeakEntity<InputBaseState>, id:Int) {
        this.state = state;
        this.id = id;
    }

    static inline function extras(state:InputBaseState):EditorExtras {
        return cast state.extras;
    }

    /** Replace only this owner's decorations, clipping ranges to UTF-8 boundaries. */
    public function set(decorations:Array<RangeDecoration>, cx:App):Void {
        state.tryUpdate(cx, (state, cx) -> {
            final decorations = DecorationCollections.normalize(state.text, decorations);
            if (extras(state).rangeDecorationCollections.set(id, decorations))
                cx.notify();
        });
    }

    /** Append decorations, preserving their paint order. */
    public function append(decorations:Array<RangeDecoration>, cx:App):Void {
        state.tryUpdate(cx, (state, cx) -> {
            final decorations = DecorationCollections.normalize(state.text, decorations);
            if (extras(state).rangeDecorationCollections.append(id, decorations))
                cx.notify();
        });
    }

    /** Empty this collection without invalidating its handles. */
    public function clear(cx:App):Void {
        set([], cx);
    }

    /** Release this collection, invalidating all of its cloned handles. */
    public function dispose(cx:App):Void {
        state.tryUpdate(cx, (state, cx) -> {
            if (extras(state).rangeDecorationCollections.remove(id))
                cx.notify();
        });
    }

    /** Read tracked UTF-8 byte ranges in insertion order. */
    public function getRanges(cx:App):Array<Range> {
        final entity = state.upgrade();
        if (entity == null)
            return [];
        final decorations = extras(entity.read(cx)).rangeDecorationCollections.get(id);
        return decorations == null ? [] : [for (decoration in decorations) decoration.range()];
    }

}
