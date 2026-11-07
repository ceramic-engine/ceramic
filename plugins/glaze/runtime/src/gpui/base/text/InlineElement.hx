// Ported from gpui-kit 0.8.1: crates/base/src/text/inline_element.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.AnyElement;
import gpui.IntoElement;
import gpui.Pixels;

/**
 * A GPUI element participating as one atomic object in a text line.
 *
 * Use native GPUI styles, events and components on the element. TextView
 * measures its intrinsic size and wraps around the whole object.
 * Fixed-width elements keep their actual size; constrain them with GPUI
 * styles as needed.
 */
class InlineElement {

    @:allow(gpui.base.text)
    var element:AnyElement;

    @:allow(gpui.base.text)
    var baseline:Null<Pixels> = null;

    public function new(element:IntoElement) {
        this.element = element.intoAnyElement();
    }

    /**
     * Distance from the top edge to the alphabetic baseline, in logical
     * pixels. By default the box aligns its bottom with the surrounding
     * text's descent.
     */
    public function withBaseline(baseline:Pixels):InlineElement {
        this.baseline = baseline;
        return this;
    }

}
