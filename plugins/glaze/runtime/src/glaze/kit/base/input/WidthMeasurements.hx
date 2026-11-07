// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/text_wrapper/measurements.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * Bounded exact substring widths survive width-only reflows, including
 * wrap-boundary crossings.
 *
 * Keep only scalar results; native shaped runs and their GPU resources remain frame-owned.
 */
class WidthMeasurements {

    static inline final MAX_ENTRIES:Int = 32768;

    static inline final MAX_TEXT_BYTES:Int = 4 * 1024 * 1024;

    /** Content keys also share common prefixes and suffixes between logical source lines. */
    final widths:Map<String, MeasuredWidth> = new Map();

    /** Number of entries of `widths` (Rust `HashMap::len`) */
    var count:Int = 0;

    /** FIFO eviction bounds retained source fragments without rescanning the document. */
    final order:Array<String> = [];

    /** Index of the front of `order` (avoids shifting the array on each eviction) */
    var orderStart:Int = 0;

    /** Byte length of each entry of `order` */
    final orderBytes:Array<Int> = [];

    /** Payload budget is separate from the entry limit that bounds map/queue overhead. */
    var textBytes:Int = 0;

    public function new() {}

    /**
     * Return the exact native width previously measured with the current font configuration.
     * `textLen` is the UTF-8 byte length of `text`.
     */
    public function measure(text:String, textLen:Int, measure:() -> Float):Float {
        final cached = widths.get(text);
        if (cached != null)
            return cached.width;
        return remember(text, textLen, measure());
    }

    /**
     * The width measured earlier for `text`, or NaN (`measure()` without a
     * function value, whose Float result is boxed on hxcpp).
     */
    @:allow(gpui.base.input)
    function cachedWidth(text:String):Float {
        // The width in an object: a `Map<String, Float>` boxes the value it
        // returns on hxcpp (one allocation per hit)
        final cached = widths.get(text);
        return cached != null ? cached.width : Math.NaN;
    }

    /** Records `width`, just measured for `text` (the rest of `measure()`), and returns it */
    @:allow(gpui.base.input)
    function remember(text:String, textLen:Int, width:Float):Float {
        if (textLen > MAX_TEXT_BYTES)
            return width;
        while (count >= MAX_ENTRIES || textBytes + textLen > MAX_TEXT_BYTES) {
            if (orderStart >= order.length)
                break;
            final expired = order[orderStart];
            textBytes -= orderBytes[orderStart];
            order[orderStart] = null;
            orderStart++;
            if (widths.remove(expired))
                count--;
        }
        if (orderStart > 1024 && orderStart * 2 > order.length) {
            order.splice(0, orderStart);
            orderBytes.splice(0, orderStart);
            orderStart = 0;
        }
        textBytes += textLen;
        order.push(text);
        orderBytes.push(textLen);
        widths.set(text, new MeasuredWidth(width));
        count++;
        return width;
    }

    /** Text/font/tab-size/indent/inline updates delimit reuse; old measurements cannot survive. */
    public function clear():Void {
        widths.clear();
        count = 0;
        order.resize(0);
        orderBytes.resize(0);
        orderStart = 0;
        textBytes = 0;
    }

}

/** A width of `WidthMeasurements` */
private class MeasuredWidth {

    public final width:Float;

    public inline function new(width:Float) {
        this.width = width;
    }

}
