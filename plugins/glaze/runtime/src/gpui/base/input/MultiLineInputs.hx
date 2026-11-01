// Ported from gpui-kit 0.8.1: crates/base/src/input/base/state.rs (`impl<M: MultiLineMode> InputBaseState<M>`,
// the shared part of `rows`/`set_rows`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Context;
import gpui.Point;
import gpui.Window;

/**
 * The methods Rust shares between the two multi-line modes (`impl<M:
 * MultiLineMode> InputBaseState<M>`). `TextareaState` and `EditorState`
 * forward to them; a single-line `InputState` does not offer them.
 */
@:access(gpui.base.input.LayoutMode)
class MultiLineInputs {

    /**
     * Update whether the text stretches past its ends. Turning it off drops
     * a stretch in progress.
     */
    public static function setScrollBounce(self:InputBaseState, scrollBounce:Bool, cx:Context<InputBaseState>):Void {
        if (self.scrollBounce != scrollBounce) {
            self.scrollBounce = scrollBounce;
            self.overscroll.reset();
            cx.notify();
        }
    }

    /**
     * Whether the built-in search panel and its shortcut are enabled.
     *
     * This only concerns the panel. An input that is not searchable still
     * answers `setSearchQuery` and the other search methods.
     */
    public static function setSearchable(self:InputBaseState, searchable:Bool, cx:Context<InputBaseState>):Void {
        self.searchable = searchable;
        cx.notify();
    }

    /** Update the soft wrap mode, default is true. */
    public static function setSoftWrap(self:InputBaseState, wrap:Bool, window:Window, cx:Context<InputBaseState>):Void {
        self.softWrap = wrap;
        if (wrap) {
            final lastLayout = self.lastLayout;
            final wrapWidth:Float = lastLayout != null && lastLayout.wrapWidth != null ? lastLayout.wrapWidth : self.inputBounds.size.width;

            self.displayMap.onLayoutChanged(wrapWidth, cx.app);

            // Reset scroll to left 0
            final offset = self.scrollHandle.offset();
            self.scrollHandle.setOffset(new Point(0., offset.y));
        }
        else {
            self.displayMap.onLayoutChanged(null, cx.app);
        }
        cx.notify();
    }

    /** Update how soft-wrapped continuation lines are indented. */
    public static function setWrappingIndent(self:InputBaseState, wrappingIndent:WrappingIndent, window:Window, cx:Context<InputBaseState>):Void {
        self.wrappingIndent = wrappingIndent;
        self.displayMap.setWrappingIndent(wrappingIndent, cx.app);
        cx.notify();
    }

    /**
     * Rust's `rows` / `set_rows` match: plain text and code editor set the
     * rows, auto grow sets both the rows and the maximum rows.
     */
    public static function setLayoutRows(self:InputBaseState, rows:Int):Void {
        final mode = self.mode;
        switch mode.kind {
            case PlainText | CodeEditor:
                mode._rows = rows;
            case AutoGrow:
                mode._rows = rows;
                mode._maxRows = rows;
        }
    }

}
