// Ported from gpui-kit 0.8.1: crates/base/src/dock/layout/tree.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

/**
 * Whether the root of this tree is pinned to a split.
 *
 * The center of a `DockArea` must serialize as a `StackPanel` even when
 * empty, which `RootKind.Split` guarantees. A dock's root is unconstrained.
 */
enum abstract RootKind(Int) {
    var Split;
    var Any;

    public function toString():String {
        return (cast this : RootKind) == Split ? 'Split' : 'Any';
    }
}
