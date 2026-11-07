// Ported from gpui-pre 0.3.10: src/input.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.util.Ref;

/**
 * The canonical implementation of `InputHandler`: forwards every call to a
 * view implementing `EntityInputHandler`, inside an update of that view.
 * Create it in your element's paint with the element's bounds and register it
 * with `window.handleInput(focusHandle, new ElementInputHandler(bounds, view), cx)`.
 */
class ElementInputHandler<V:Model & EntityInputHandler> extends InputHandler {

    final view:Entity<V>;

    final _elementBounds:Bounds;

    public function new(elementBounds:Bounds, view:Entity<V>) {
        this.view = view;
        this._elementBounds = elementBounds;
    }

    public function selectedTextRange(ignoreDisabledInput:Bool, window:Window, cx:App):Null<UTF16Selection> {
        return view.update(cx, (view, cx) -> view.selectedTextRange(ignoreDisabledInput, window, cx));
    }

    public function markedTextRange(window:Window, cx:App):Null<Range> {
        return view.update(cx, (view, cx) -> view.markedTextRange(window, cx));
    }

    public function textForRange(rangeUtf16:Range, adjustedRange:Ref<Null<Range>>, window:Window, cx:App):Null<String> {
        return view.update(cx, (view, cx) -> view.textForRange(rangeUtf16, adjustedRange, window, cx));
    }

    public function replaceTextInRange(replacementRange:Null<Range>, text:String, window:Window, cx:App):Void {
        view.update(cx, (view, cx) -> view.replaceTextInRange(replacementRange, text, window, cx));
    }

    public function replaceAndMarkTextInRange(rangeUtf16:Null<Range>, newText:String, newSelectedRange:Null<Range>, window:Window, cx:App):Void {
        view.update(cx, (view, cx) -> view.replaceAndMarkTextInRange(rangeUtf16, newText, newSelectedRange, window, cx));
    }

    public function unmarkText(window:Window, cx:App):Void {
        view.update(cx, (view, cx) -> view.unmarkText(window, cx));
    }

    override public function paste(item:ClipboardItem, window:Window, cx:App):Void {
        view.update(cx, (view, cx) -> view.paste(item, window, cx));
    }

    public function boundsForRange(rangeUtf16:Range, window:Window, cx:App):Null<Bounds> {
        return view.update(cx, (view, cx) -> view.boundsForRange(rangeUtf16, _elementBounds, window, cx));
    }

    override public function selectionBoundsForRange(rangeUtf16:Range, window:Window, cx:App):Array<Bounds> {
        return view.update(cx, (view, cx) -> view.selectionBoundsForRange(rangeUtf16, _elementBounds, window, cx));
    }

    public function characterIndexForPoint(point:Point, window:Window, cx:App):Null<Int> {
        return view.update(cx, (view, cx) -> view.characterIndexForPoint(point, window, cx));
    }

    override public function setSelectedTextRange(rangeUtf16:Range, window:Window, cx:App):Void {
        view.update(cx, (view, cx) -> view.setSelectedTextRange(rangeUtf16, window, cx));
    }

    override public function elementBounds(window:Window, cx:App):Null<Bounds> {
        return _elementBounds;
    }

    override public function textLengthUtf16(window:Window, cx:App):Null<Int> {
        return view.update(cx, (view, cx) -> view.textLengthUtf16(window, cx));
    }

    override public function acceptsTextInput(window:Window, cx:App):Bool {
        return view.update(cx, (view, cx) -> view.acceptsTextInput(window, cx));
    }

    override public function prefersImeForPrintableKeys(window:Window, cx:App):Bool {
        return view.update(cx, (view, cx) -> view.acceptsTextInput(window, cx));
    }

    override public function textInputConfiguration(window:Window, cx:App):TextInputConfiguration {
        return view.update(cx, (view, cx) -> view.textInputConfiguration(window, cx));
    }

    override public function textInputEditableRange(window:Window, cx:App):Null<Range> {
        return view.update(cx, (view, cx) -> view.textInputEditableRange(window, cx));
    }

}
