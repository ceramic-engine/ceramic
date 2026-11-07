// Ported from gpui-pre 0.3.10: src/input.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.util.Ref;

/**
 * Implement this interface to allow views to handle textual input when
 * implementing an editor, field, etc.
 *
 * Once your view implements it, construct an `ElementInputHandler` and
 * register it during paint with `window.handleInput(focusHandle, handler, cx)`.
 *
 * After application-driven edits or selection changes, also call
 * `window.notifyTextInputChanged()` or `window.notifyTextSelectionChanged()`.
 *
 * See `InputHandler` for details on each method. Ranges are UTF-16 code units.
 *
 * Rust trait with default methods: the methods marked "default" below are
 * added by `EntityInputHandlerMacro` to implementing classes that don't
 * define them (`paste`, `selectionBoundsForRange`, `setSelectedTextRange`,
 * `textLengthUtf16`, `acceptsTextInput`, `textInputConfiguration`,
 * `textInputEditableRange`). Like `Render`, the context is a `Context<Dynamic>`.
 */
@:autoBuild(gpui.EntityInputHandlerMacro.build())
interface EntityInputHandler {

    function textForRange(range:Range, adjustedRange:Ref<Null<Range>>, window:Window, cx:Context<Dynamic>):Null<String>;

    function selectedTextRange(ignoreDisabledInput:Bool, window:Window, cx:Context<Dynamic>):Null<UTF16Selection>;

    function markedTextRange(window:Window, cx:Context<Dynamic>):Null<Range>;

    function unmarkText(window:Window, cx:Context<Dynamic>):Void;

    /** Default: inserts the text of the item with `replaceTextInRange(null, text)`. */
    function paste(item:ClipboardItem, window:Window, cx:Context<Dynamic>):Void;

    function replaceTextInRange(range:Null<Range>, text:String, window:Window, cx:Context<Dynamic>):Void;

    function replaceAndMarkTextInRange(range:Null<Range>, newText:String, newSelectedRange:Null<Range>, window:Window, cx:Context<Dynamic>):Void;

    function boundsForRange(rangeUtf16:Range, elementBounds:Bounds, window:Window, cx:Context<Dynamic>):Null<Bounds>;

    /** Default: `[]` */
    function selectionBoundsForRange(rangeUtf16:Range, elementBounds:Bounds, window:Window, cx:Context<Dynamic>):Array<Bounds>;

    function characterIndexForPoint(point:Point, window:Window, cx:Context<Dynamic>):Null<Int>;

    /** Default: does nothing */
    function setSelectedTextRange(rangeUtf16:Range, window:Window, cx:Context<Dynamic>):Void;

    /** Default: `null` */
    function textLengthUtf16(window:Window, cx:Context<Dynamic>):Null<Int>;

    /** Default: `true` */
    function acceptsTextInput(window:Window, cx:Context<Dynamic>):Bool;

    /** Default: `TextInputConfiguration.defaultValue()` */
    function textInputConfiguration(window:Window, cx:Context<Dynamic>):TextInputConfiguration;

    /** Default: `null` */
    function textInputEditableRange(window:Window, cx:Context<Dynamic>):Null<Range>;

}
