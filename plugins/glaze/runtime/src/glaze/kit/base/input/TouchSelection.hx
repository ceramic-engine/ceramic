// Ported from gpui-kit 0.8.1: crates/base/src/input/base/touch.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Range;

/**
 * The selection a touch gesture made, and what it is doing now.
 */
class TouchSelection {

    /** The range the gesture left; null when no touch selection is live. */
    public var range:Null<Range> = null;

    public var menuOpen:Bool = false;

    public var drag:Null<EdgeDrag> = null;

    public function new() {}

}
