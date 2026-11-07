// Ported from gpui-pre 0.3.10: src/elements/text.rs (Text, `impl Element for &str / SharedString`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * An `Element` that renders text with the current text style of the window.
 *
 * Strings are elements too: `div().child("hello")` creates a `Text` without
 * id (Rust `impl Element for SharedString`). The id is only used by
 * accessibility in GPUI (not ported), it does not keep any state.
 */
class Text extends Element {

    var id:Null<ElementId>;

    final textValue:String;

    final textLayout:TextLayout = new TextLayout();

    /**
     * Create a new `Text` element, with an id or (`null`) without one
     * (Rust `Text::new` and `Text::new_inaccessible`).
     */
    public function new(id:Null<ElementId>, text:String) {
        #if glaze_count_allocations glaze.util.AllocationCounters.texts++; #end
        this.id = id;
        this.textValue = text;
    }

    /** The ID of this `Text`. */
    public inline function textId():Null<ElementId> {
        return id;
    }

    /** Produce a new `Text` with the given `id`. */
    public function withId(id:ElementIdArg):Text {
        this.id = id;
        return this;
    }

    /** The text that this `Text` element will display. */
    public inline function text():String {
        return textValue;
    }

    /** The layout of this text (valid once laid out). */
    public inline function layout():TextLayout {
        return textLayout;
    }

    override function elementId():Null<ElementId> {
        return id;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return textLayout.layout(textValue, null, window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        textLayout.prepaint(bounds, textValue);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        textLayout.paint(textValue, window, cx);
    }

    /**
     * Trivial hash function for the location information produced by the
     * `Prelude.text()` macro (FNV-1a, truncated to 32 bits).
     */
    public static function hashTextMacroLocation(s:String):Int {
        var hash = 0x811c9dc5;
        for (i in 0...s.length) {
            hash ^= StringTools.fastCodeAt(s, i) & 0xFF;
            // hash * 0x01000193 (2^24 + 0x193), wrapped to 32 bits on every target
            hash = ((hash << 24) + hash * 0x193) | 0;
        }
        return hash;
    }

}
