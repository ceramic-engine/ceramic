// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.util.Ref;

/**
 * The input handler a window gives to its platform: an `InputHandler`
 * registered during paint with `window.handleInput()`, bound to its window.
 *
 * Methods without a `window` argument run in their own app update (Rust
 * `AsyncWindowContext::update`) and do nothing (return `null` / `false`) once
 * the window is closed. The platform gets it with `window.takeInputHandler()`
 * and gives it back with `window.setInputHandler()`.
 */
class PlatformInputHandler {

    final window:Window;

    final app:App;

    final handler:InputHandler;

    var _focusId:Int = -1;

    public function new(window:Window, app:App, handler:InputHandler) {
        this.window = window;
        this.app = app;
        this.handler = handler;
    }

    @:allow(gpui)
    function withFocus(focusId:Int):PlatformInputHandler {
        _focusId = focusId;
        return this;
    }

    /**
     * Identifies the input field registered through `Window.handleInput`
     * (-1 when unknown). It survives handler replacement during repaint.
     */
    public function focusId():Int {
        return _focusId;
    }

    /** The wrapped handler */
    public inline function inputHandler():InputHandler {
        return handler;
    }

    inline function available():Bool {
        return !window.isDestroyed();
    }

    public function selectedTextRange(ignoreDisabledInput:Bool):Null<UTF16Selection> {
        if (!available()) return null;
        return app.update(cx -> handler.selectedTextRange(ignoreDisabledInput, window, cx));
    }

    public function markedTextRange():Null<Range> {
        if (!available()) return null;
        return app.update(cx -> handler.markedTextRange(window, cx));
    }

    public function textForRange(rangeUtf16:Range, adjusted:Ref<Null<Range>>):Null<String> {
        if (!available()) return null;
        return app.update(cx -> handler.textForRange(rangeUtf16, adjusted, window, cx));
    }

    public function replaceTextInRange(replacementRange:Null<Range>, text:String):Void {
        if (!available()) return;
        app.update(cx -> handler.replaceTextInRange(replacementRange, text, window, cx));
    }

    public function replaceAndMarkTextInRange(rangeUtf16:Null<Range>, newText:String, newSelectedRange:Null<Range>):Void {
        if (!available()) return;
        app.update(cx -> handler.replaceAndMarkTextInRange(rangeUtf16, newText, newSelectedRange, window, cx));
    }

    public function unmarkText():Void {
        if (!available()) return;
        app.update(cx -> handler.unmarkText(window, cx));
    }

    public function paste(item:ClipboardItem):Void {
        if (!available()) return;
        app.update(cx -> handler.paste(item, window, cx));
    }

    public function boundsForRange(rangeUtf16:Range):Null<Bounds> {
        if (!available()) return null;
        return app.update(cx -> handler.boundsForRange(rangeUtf16, window, cx));
    }

    public function selectionBoundsForRange(rangeUtf16:Range):Array<Bounds> {
        if (!available()) return [];
        return app.update(cx -> handler.selectionBoundsForRange(rangeUtf16, window, cx));
    }

    public function applePressAndHoldEnabled():Bool {
        return handler.applePressAndHoldEnabled();
    }

    /**
     * Inserts typed text (`replaceTextInRange(null, input)`), with the window and app
     * of the caller (Rust `dispatch_input`).
     */
    public function dispatchInput(input:String, window:Window, cx:App):Void {
        handler.replaceTextInRange(null, input, window, cx);
    }

    /**
     * Where the IME candidate window goes: the start of the marked text on the caret's
     * line when composing, the selection head otherwise.
     */
    public static function computeImeCandidateBounds(markedRange:Null<Range>, selection:UTF16Selection, boundsForRange:(Range) -> Null<Bounds>):Null<Bounds> {
        if (markedRange != null) {
            // Default to the start of the marked (composing) range.
            var lineStart = markedRange.start;

            // Walk backward from the caret looking for a line break. A change in
            // the Y coordinate means we crossed into the previous visual line, so
            // the line start is one position after the break point.
            final caret = selection.range.end;
            final caretBounds = boundsForRange(new Range(caret, caret));
            if (caretBounds != null) {
                var i = caret - 1;
                while (i >= markedRange.start) {
                    final b = boundsForRange(new Range(i, i));
                    if (b != null) {
                        if (Math.abs(b.origin.y - caretBounds.origin.y) > 0.1) {
                            lineStart = i + 1;
                            break;
                        }
                    }
                    i--;
                }
            }
            return boundsForRange(new Range(lineStart, lineStart));
        }
        else {
            // No active composition: use the selection endpoint.
            final offset = selection.reversed ? selection.range.start : selection.range.end;
            return boundsForRange(new Range(offset, offset));
        }
    }

    /**
     * IME candidate bounds, with the window and app of the caller.
     */
    public function selectedBounds(window:Window, cx:App):Null<Bounds> {
        final markedRange = handler.markedTextRange(window, cx);
        final selection = handler.selectedTextRange(true, window, cx);
        if (selection == null) return null;
        return computeImeCandidateBounds(markedRange, selection, range -> handler.boundsForRange(range, window, cx));
    }

    /**
     * IME candidate bounds, each query in its own update.
     */
    public function imeCandidateBounds():Null<Bounds> {
        final markedRange = markedTextRange();
        final selection = selectedTextRange(true);
        if (selection == null) return null;
        return computeImeCandidateBounds(markedRange, selection, range -> boundsForRange(range));
    }

    public function characterIndexForPoint(point:Point):Null<Int> {
        if (!available()) return null;
        return app.update(cx -> handler.characterIndexForPoint(point, window, cx));
    }

    public function setSelectedTextRange(rangeUtf16:Range):Void {
        if (!available()) return;
        app.update(cx -> handler.setSelectedTextRange(rangeUtf16, window, cx));
    }

    public function elementBounds():Null<Bounds> {
        if (!available()) return null;
        return app.update(cx -> handler.elementBounds(window, cx));
    }

    public function textLengthUtf16():Null<Int> {
        if (!available()) return null;
        return app.update(cx -> handler.textLengthUtf16(window, cx));
    }

    /** With the window and app of the caller. */
    public function acceptsTextInput(window:Window, cx:App):Bool {
        return handler.acceptsTextInput(window, cx);
    }

    public function queryAcceptsTextInput():Bool {
        if (!available()) return true;
        return app.update(cx -> handler.acceptsTextInput(window, cx));
    }

    /**
     * Checks eligibility against the current focus, including before the next frame
     * is drawn. Fails closed when the window is closed, and requires registration
     * through `Window.handleInput`.
     */
    public function queryAcceptsFocusedTextInput():Bool {
        if (!available()) return false;
        final focusId = _focusId;
        return app.update(cx -> focusId != -1 && window.focusId() == focusId && handler.acceptsTextInput(window, cx));
    }

    /**
     * `InputHandler.prefersImeForPrintableKeys`, except while a multi-stroke binding is
     * pending: the next printable key may complete a binding whose prefix already
     * bypassed the IME, so this returns `false`.
     */
    public function queryPrefersImeForPrintableKeys():Bool {
        if (!available()) return false;
        return app.update(cx -> !window.hasPendingKeystrokes() && handler.prefersImeForPrintableKeys(window, cx));
    }

    /** With the window and app of the caller. */
    public function textInputConfiguration(window:Window, cx:App):TextInputConfiguration {
        return handler.textInputConfiguration(window, cx);
    }

    public function textInputEditableRange():Null<Range> {
        if (!available()) return null;
        return app.update(cx -> handler.textInputEditableRange(window, cx));
    }

}
