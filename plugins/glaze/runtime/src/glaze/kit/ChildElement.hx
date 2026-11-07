// Ported from gpui-kit 0.8.1: crates/component/src/element_ext.rs (`ChildElement`, `AnyChildElement`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component;

import gpui.AnyElement;
import gpui.IntoElement;
import gpui.RenderOnce;

/**
 * An element that takes its index among its siblings and the size of its
 * owner before being rendered (the parts of the component `Table`).
 *
 * `setIx` is Rust `with_ix`, in place.
 */
interface ChildElement extends Sizable extends RenderOnce {

    function setIx(ix:Int):Void;

}

/**
 * A type-erased element that can accept its options (index and size)
 * before being rendered.
 */
class AnyChildElement {

    final element:ChildElement;

    public function new(element:ChildElement) {
        this.element = element;
    }

    public function intoAny(ix:Int, size:Size):AnyElement {
        element.setIx(ix);
        element.setSize(size);
        return (element : IntoElement).intoAnyElement();
    }

}
