// Ported from gpui-pre 0.3.10: src/elements/div.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.util.Ref;

/**
 * Represents an element that can be scrolled *to* in its parent element.
 * Contrary to `ScrollHandle.scrollToItem`, an anchored element does not have to be an immediate child of the parent.
 */
class ScrollAnchor {

    final handle:ScrollHandle;

    @:allow(glaze)
    final lastOrigin:Ref<Point> = new Ref(new Point(0, 0));

    /**
     * Creates a `ScrollAnchor` associated with a given `ScrollHandle`.
     */
    public function new(handle:ScrollHandle) {
        this.handle = handle;
    }

    /**
     * Rust `ScrollAnchor::for_handle`.
     */
    public static inline function forHandle(handle:ScrollHandle):ScrollAnchor {
        return new ScrollAnchor(handle);
    }

    /**
     * Request scroll to this item on the next frame.
     */
    public function scrollTo(window:Window, cx:App):Void {
        window.onNextFrame((_, _) -> {
            final viewportBounds = handle.bounds();
            final selfBounds = lastOrigin.value;
            handle.setOffset(viewportBounds.origin.sub(selfBounds));
        });
    }

}
