// Ported from gpui-pre-web 0.3.10: src/events.rs (keydown, compositionupdate / compositionend
// handling) and gpui-pre 0.3.10 src/window.rs (IME position)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: rewritten in Haxe on top of Ceramic's text editing events. See NOTICE.md.
package gpui;

/**
 * The platform text input layer of a window on Ceramic: what GPUI's platform
 * windows do with their input handler, driven by Ceramic's key events and
 * text editing events (`input.onTextCommit`, `input.onTextComposition`).
 * `GpuiInput` creates one per bound window and sets it as the window's
 * `textInputPlatform`.
 *
 * Ceramic delivers a key down, then (when the key types text) a text commit
 * with its character, then composition events for IMEs. The behaviour follows
 * GPUI's web platform (`gpui-pre-web` `events.rs`), the closest to Ceramic:
 *
 * - `keyDown`: dispatched to the window (`KeyDownEvent`). When a handler or a
 *   key binding consumes it, the text commit Ceramic sends next for the same
 *   key is dropped (the web platform inserts the key char itself when the
 *   key down propagates; here the commit carries it). While composing, keys
 *   belong to the IME and are not dispatched (like macOS).
 * - `textCommit(text)`: `replaceTextInRange(null, text)` on the focused input
 *   handler. Right after the end of a composition (an empty
 *   `textComposition`), it is web's `compositionend`: if text is still marked,
 *   `replaceTextInRange(null, text)`, then `unmarkText()`.
 * - `textComposition(text, start, length)`: `replaceAndMarkTextInRange(null,
 *   text, start..start + length)` (the selection inside the composed text,
 *   converted from code points to UTF-16). An empty text ends the composition:
 *   committed if a `textCommit` follows in the same batch of events, cancelled
 *   otherwise (`flush()`, web `compositionend` with an empty text: the marked
 *   text is replaced with nothing, then unmarked).
 * - Text editing follows the window's focused text input: started on
 *   `FocusGained` (Ceramic `input.startTextEditing()` with the element bounds),
 *   stopped on `FocusLost`. The IME candidate area is kept in sync with
 *   `PlatformInputHandler.imeCandidateBounds()` (start of the marked text, or
 *   the selection head) after text input and selection / content changes, and
 *   with `window.invalidateCharacterCoordinates()`.
 *
 * Every input handler call goes through the `PlatformInputHandler` registered
 * by the last frame (`window.peekInputHandler()`), like a platform window.
 * The methods talking to Ceramic (`startEditing`, `stopEditing`,
 * `setEditingArea`, `scheduleImeUpdate`) can be overridden (tests do).
 */
class TextInputBridge implements PlatformTextInput {

    public final window:Window;

    /** Whether an IME composition is in progress (keys belong to the IME). */
    public var composing(default, null):Bool = false;

    /** Whether Ceramic text editing was started for this window. */
    public var editing(default, null):Bool = false;

    /** The character of the last consumed key down, dropped if it is committed next. */
    var suppressedCommit:Null<String> = null;

    /** An empty composition was received: committed or cancelled by what follows. */
    var compositionEndPending:Bool = false;

    var imeUpdateScheduled:Bool = false;

    public function new(window:Window) {
        this.window = window;
    }

/// Ceramic events

    /**
     * A key down from the platform. Returns the dispatch result, or `null` when the
     * key was left to the IME (composing).
     */
    public function keyDown(event:KeyDownEvent):Null<DispatchEventResult> {
        suppressedCommit = null;
        if (composing) {
            return null;
        }
        final result = window.dispatchEvent(event);
        if (!result.propagate) {
            // Handled: the platform will still deliver the character, drop it.
            suppressedCommit = event.keystroke.keyChar;
        }
        scheduleImeUpdate();
        return result;
    }

    /**
     * Text committed by the platform: a typed character, or the final text of a composition.
     */
    public function textCommit(text:String):Void {
        if (suppressedCommit != null) {
            final suppressed = suppressedCommit;
            suppressedCommit = null;
            if (suppressed == text && !compositionEndPending && !composing) {
                return;
            }
        }
        final endingComposition = compositionEndPending || composing;
        compositionEndPending = false;
        composing = false;
        final handler = window.peekInputHandler();
        if (handler == null) {
            return;
        }
        if (endingComposition) {
            // Web `compositionend`: only commit when a marked range still exists.
            // When a caret move ended the composition, the editor has already
            // unmarked, and inserting would duplicate the text.
            if (handler.markedTextRange() != null) {
                handler.replaceTextInRange(null, text);
            }
            handler.unmarkText();
        }
        else {
            handler.replaceTextInRange(null, text);
        }
        scheduleImeUpdate();
    }

    /**
     * The IME composition changed. `start` and `length` are the selection inside
     * `text`, in characters (code points). An empty text ends the composition.
     */
    public function textComposition(text:String, start:Int, length:Int):Void {
        if (text == null || text.length == 0) {
            if (composing) {
                compositionEndPending = true;
            }
            composing = false;
            return;
        }
        if (compositionEndPending) {
            // A new composition without a commit: the previous one was cancelled
            endComposition('');
        }
        composing = true;
        final handler = window.peekInputHandler();
        if (handler == null) {
            return;
        }
        final selectionStart = codePointsToUtf16(text, start);
        final selectionEnd = codePointsToUtf16(text, start + length);
        handler.replaceAndMarkTextInRange(null, text, new Range(selectionStart, selectionEnd));
        scheduleImeUpdate();
    }

    /**
     * End of a batch of platform events: a composition that ended without a
     * commit is cancelled.
     */
    public function flush():Void {
        suppressedCommit = null;
        if (compositionEndPending) {
            endComposition('');
        }
    }

    function endComposition(text:String):Void {
        compositionEndPending = false;
        final handler = window.peekInputHandler();
        if (handler == null) {
            return;
        }
        if (handler.markedTextRange() != null) {
            handler.replaceTextInRange(null, text);
        }
        handler.unmarkText();
        scheduleImeUpdate();
    }

    /**
     * Platform paste (no Ceramic event yet): `paste(item)` on the input handler.
     */
    public function paste(item:ClipboardItem):Void {
        final handler = window.peekInputHandler();
        if (handler != null) {
            handler.paste(item);
        }
    }

    /**
     * UTF-16 length of the first `count` code points of `text`.
     */
    public static function codePointsToUtf16(text:String, count:Int):Int {
        var i = 0;
        var n = 0;
        final len = text.length;
        while (i < len && n < count) {
            final c = StringTools.fastCodeAt(text, i);
            i += (c >= 0xD800 && c <= 0xDBFF && i + 1 < len) ? 2 : 1;
            n++;
        }
        return i;
    }

/// PlatformTextInput

    public function setTextInputConfiguration(configuration:TextInputConfiguration):Void {
        // Ceramic text editing has no text assistance settings
    }

    public function textInputStateChanged(change:TextInputStateChange):Void {
        switch change {
            case FocusGained:
                composing = false;
                compositionEndPending = false;
                final handler = window.peekInputHandler();
                final bounds = handler != null ? handler.inputHandler().elementBounds(window, window.app) : null;
                startEditing(bounds != null ? bounds : new Bounds());
                editing = true;
                scheduleImeUpdate();
            case FocusLost:
                if (editing) {
                    editing = false;
                    stopEditing();
                }
                composing = false;
                compositionEndPending = false;
            case SelectionChanged | ContentChanged:
                scheduleImeUpdate();
        }
    }

    public function updateImePosition(bounds:Bounds):Void {
        if (editing) {
            setEditingArea(bounds);
        }
    }

/// Ceramic side (overridable)

    /**
     * Starts Ceramic text editing over `bounds` (window coordinates).
     */
    function startEditing(bounds:Bounds):Void {
        final input = ceramic.App.app.input;
        final area = toScreen(bounds);
        input.startTextEditing(area.origin.x, area.origin.y, area.size.width, area.size.height);
    }

    function stopEditing():Void {
        ceramic.App.app.input.stopTextEditing();
    }

    /**
     * Moves the IME area to `bounds` (window coordinates), the cursor at its left edge.
     */
    function setEditingArea(bounds:Bounds):Void {
        final area = toScreen(bounds);
        ceramic.App.app.input.setTextEditingArea(area.origin.x, area.origin.y, Math.max(1, area.size.width), Math.max(1, area.size.height), 0);
    }

    /**
     * Updates the IME area at the end of the frame, once state changes are applied.
     */
    function scheduleImeUpdate():Void {
        if (imeUpdateScheduled || !editing)
            return;
        imeUpdateScheduled = true;
        ceramic.App.app.onceImmediate(() -> {
            imeUpdateScheduled = false;
            if (!editing || window.isDestroyed())
                return;
            final handler = window.peekInputHandler();
            if (handler == null)
                return;
            final bounds = handler.imeCandidateBounds();
            if (bounds != null) {
                setEditingArea(bounds);
            }
        });
    }

    function toScreen(bounds:Bounds):Bounds {
        final renderable = window.renderable;
        final point = new ceramic.Point();
        renderable.visualToScreen(bounds.origin.x, bounds.origin.y, point);
        final x0 = point.x;
        final y0 = point.y;
        renderable.visualToScreen(bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height, point);
        return Bounds.fromCorners(new Point(x0, y0), new Point(point.x, point.y));
    }

}
