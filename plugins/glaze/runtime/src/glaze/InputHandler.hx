// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.util.Ref;

/**
 * GPUI's interface for native text input, IME composition, and selection.
 * Platform backends translate their native text protocols into these
 * operations (on Ceramic: `TextInputBridge`).
 *
 * Text offsets and ranges use UTF-16 code units unless stated otherwise.
 *
 * Rust trait with default methods: an abstract class here. Views usually
 * implement `EntityInputHandler` instead and register an
 * `ElementInputHandler` with `window.handleInput()` during paint.
 */
abstract class InputHandler {

    /**
     * Get the range of the user's currently selected text, if any
     * (NSTextInputClient `selectedRange`).
     * Return value is in terms of UTF-16 characters, from 0 to the length of the document.
     */
    public abstract function selectedTextRange(ignoreDisabledInput:Bool, window:Window, cx:App):Null<UTF16Selection>;

    /**
     * Get the range of the currently marked text, if any (NSTextInputClient `markedRange`).
     * Return value is in terms of UTF-16 characters, from 0 to the length of the document.
     */
    public abstract function markedTextRange(window:Window, cx:App):Null<Range>;

    /**
     * Get the text for the given document range in UTF-16 characters
     * (NSTextInputClient `attributedSubstring(forProposedRange:actualRange:)`).
     * `adjustedRange.value` may be set to the range actually returned.
     */
    public abstract function textForRange(rangeUtf16:Range, adjustedRange:Ref<Null<Range>>, window:Window, cx:App):Null<String>;

    /**
     * Replace the text in the given document range with the given text
     * (NSTextInputClient `insertText(_:replacementRange:)`).
     * `replacementRange` is in terms of UTF-16 characters.
     */
    public abstract function replaceTextInRange(replacementRange:Null<Range>, text:String, window:Window, cx:App):Void;

    /**
     * Replace the text in the given document range with the given text, and mark
     * the given text as part of an IME 'composing' state
     * (NSTextInputClient `setMarkedText(_:selectedRange:replacementRange:)`).
     * `rangeUtf16` and `newSelectedRange` are in terms of UTF-16 characters.
     */
    public abstract function replaceAndMarkTextInRange(rangeUtf16:Null<Range>, newText:String, newSelectedRange:Null<Range>, window:Window, cx:App):Void;

    /**
     * Remove the IME 'composing' state from the document (NSTextInputClient `unmarkText`).
     */
    public abstract function unmarkText(window:Window, cx:App):Void;

    /**
     * Insert a platform-initiated paste at the current selection. The default
     * implementation inserts only the plain-text portion of the item.
     */
    public function paste(item:ClipboardItem, window:Window, cx:App):Void {
        final text = item.text();
        if (text != null) {
            replaceTextInRange(null, text, window, cx);
        }
    }

    /**
     * Get the bounds of the given document range in window coordinates
     * (NSTextInputClient `firstRect(forCharacterRange:actualRange:)`).
     * This is used for positioning the IME candidate window.
     */
    public abstract function boundsForRange(rangeUtf16:Range, window:Window, cx:App):Null<Bounds>;

    /**
     * Returns selection rectangles in document order, in window coordinates.
     * Empty means native selection geometry is unavailable.
     */
    public function selectionBoundsForRange(rangeUtf16:Range, window:Window, cx:App):Array<Bounds> {
        return [];
    }

    /**
     * Get the character offset for the given point in terms of UTF16 characters
     * (NSTextInputClient `characterIndexForPoint:`).
     */
    public abstract function characterIndexForPoint(point:Point, window:Window, cx:App):Null<Int>;

    /**
     * Set the range of the user's currently selected text (the platform moved the
     * selection on the application's behalf).
     */
    public function setSelectedTextRange(rangeUtf16:Range, window:Window, cx:App):Void {}

    /**
     * Get the bounds of the focused text element in window coordinates, if known.
     */
    public function elementBounds(window:Window, cx:App):Null<Bounds> {
        return null;
    }

    /**
     * Get the length of the document in UTF-16 characters, if known.
     */
    public function textLengthUtf16(window:Window, cx:App):Null<Int> {
        return null;
    }

    /**
     * Allows a given input context to opt into getting raw key repeats instead of
     * sending these to the platform (macOS press and hold).
     */
    public function applePressAndHoldEnabled():Bool {
        return true;
    }

    /**
     * Returns whether this handler is accepting text input to be inserted.
     */
    public function acceptsTextInput(window:Window, cx:App):Bool {
        return true;
    }

    /**
     * The contiguous range of text, in UTF-16 code units, that platform text
     * input may read and edit around the current selection. `null` places no bound.
     */
    public function textInputEditableRange(window:Window, cx:App):Null<Range> {
        return null;
    }

    /**
     * Returns whether printable keys should be routed to the IME before keybinding
     * matching when a non-ASCII input source (e.g. Japanese, Korean, Chinese IME)
     * is active. Defaults to `false`.
     */
    public function prefersImeForPrintableKeys(window:Window, cx:App):Bool {
        return false;
    }

    /**
     * Get this handler's preferences for platform text assistance. GPUI re-queries
     * this every frame and forwards it to the platform only when it changes.
     */
    public function textInputConfiguration(window:Window, cx:App):TextInputConfiguration {
        return TextInputConfiguration.defaultValue();
    }

}
