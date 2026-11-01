// Ported from gpui-pre 0.3.10: src/window.rs (`PaintIndex`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A position in the paint state of the next frame (scene paint operations,
 * mouse listeners, input handlers, cursor styles, accessed element states,
 * tab stops, line layouts). A range of two of them is what a cached view
 * reuses with `Window.reusePaint()`.
 *
 * Mutable and filled in place (`Window.paintIndexInto()`), see `PrepaintStateIndex`.
 */
class PaintIndex {

    public var sceneIndex:Int = 0;
    public var mouseListenersIndex:Int = 0;
    public var inputHandlersIndex:Int = 0;
    public var cursorStylesIndex:Int = 0;
    public var accessedElementStatesIndex:Int = 0;
    public var tabHandleIndex:Int = 0;
    public final lineLayoutIndex:LineLayoutIndex = new LineLayoutIndex();

    public function new() {}

    public function copyFrom(other:PaintIndex):Void {
        sceneIndex = other.sceneIndex;
        mouseListenersIndex = other.mouseListenersIndex;
        inputHandlersIndex = other.inputHandlersIndex;
        cursorStylesIndex = other.cursorStylesIndex;
        accessedElementStatesIndex = other.accessedElementStatesIndex;
        tabHandleIndex = other.tabHandleIndex;
        lineLayoutIndex.copyFrom(other.lineLayoutIndex);
    }

}
