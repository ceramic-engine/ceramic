// Ported from gpui-pre 0.3.10: src/window.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A change of the focus path of a window, given to focus listeners.
 * Paths are focus ids from the root to the focused element.
 */
class WindowFocusEvent {

    public final previousFocusPath:Array<Int>;

    public final currentFocusPath:Array<Int>;

    public function new(previousFocusPath:Array<Int>, currentFocusPath:Array<Int>) {
        this.previousFocusPath = previousFocusPath;
        this.currentFocusPath = currentFocusPath;
    }

    public function isFocusIn(focusId:Int):Bool {
        return previousFocusPath.indexOf(focusId) == -1 && currentFocusPath.indexOf(focusId) != -1;
    }

    public function isFocusOut(focusId:Int):Bool {
        return previousFocusPath.indexOf(focusId) != -1 && currentFocusPath.indexOf(focusId) == -1;
    }

    public inline function previousLast():Int {
        return previousFocusPath.length > 0 ? previousFocusPath[previousFocusPath.length - 1] : -1;
    }

    public inline function currentLast():Int {
        return currentFocusPath.length > 0 ? currentFocusPath[currentFocusPath.length - 1] : -1;
    }

}
