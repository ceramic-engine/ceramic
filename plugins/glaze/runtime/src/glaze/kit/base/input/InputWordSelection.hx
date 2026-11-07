// Ported from gpui-kit 0.8.1: crates/base/src/input/base/selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Context;
import glaze.Range;
import glaze.Window;

/**
 * Double and triple click selection: the `impl InputBaseState` block of
 * selection.rs, as static extensions
 * (`using glaze.kit.base.input.InputWordSelection;`).
 */
class InputWordSelection {

    /** Select the word at the given UTF-8 offset on double-click. */
    public static function selectWord(self:InputBaseState, offset:Int, window:Window, cx:Context<InputBaseState>):Void {
        // A masked value renders as one unbroken run of mask characters, so it
        // has no word boundaries to select by. Take all of it instead, rather
        // than let the selection highlight reveal where the words are.
        final range:Range = if (self.masked) {
            new Range(0, self.text.len());
        }
        else {
            final range = TextSelector.wordRange(self.text, offset);
            if (range == null) {
                return;
            }
            range;
        }

        self.undoManager.breakTransactionCoalescing();
        self.selections.removeAllButActive();
        self.setSelection(range.start, range.end);
        self.selectedWordRange = self.activeSelection().copy();
        cx.notify();
    }

    /** Select the line at the given UTF-8 offset on triple-click. */
    public static function selectLine(self:InputBaseState, offset:Int, window:Window, cx:Context<InputBaseState>):Void {
        final range = TextSelector.lineRange(self.text, offset);
        self.undoManager.breakTransactionCoalescing();
        self.selections.removeAllButActive();
        self.setSelection(range.start, range.end);
        self.selectedWordRange = null;
        cx.notify();
    }

}
