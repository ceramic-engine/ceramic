// Ported from gpui-pre 0.3.10: src/window.rs (`PrepaintStateIndex`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A position in the prepaint state of the next frame (hitboxes, tooltips,
 * deferred draws, dispatch tree nodes, accessed element states, line
 * layouts). A range of two of them is what a cached view reuses with
 * `Window.reusePrepaint()`.
 *
 * Rust copies small structs; here instances are mutable and filled in place
 * (`Window.prepaintIndexInto()`) so that view caching doesn't allocate.
 */
class PrepaintStateIndex {

    public var hitboxesIndex:Int = 0;
    public var tooltipsIndex:Int = 0;
    public var deferredDrawsIndex:Int = 0;
    public var dispatchTreeIndex:Int = 0;
    public var accessedElementStatesIndex:Int = 0;
    public final lineLayoutIndex:LineLayoutIndex = new LineLayoutIndex();

    public function new() {}

    public function copyFrom(other:PrepaintStateIndex):Void {
        hitboxesIndex = other.hitboxesIndex;
        tooltipsIndex = other.tooltipsIndex;
        deferredDrawsIndex = other.deferredDrawsIndex;
        dispatchTreeIndex = other.dispatchTreeIndex;
        accessedElementStatesIndex = other.accessedElementStatesIndex;
        lineLayoutIndex.copyFrom(other.lineLayoutIndex);
    }

}
