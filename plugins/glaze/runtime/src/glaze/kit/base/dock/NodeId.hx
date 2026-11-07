// Ported from gpui-kit 0.8.1: crates/base/src/dock/layout/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

/**
 * Stable container identity. Survives structural edits and normalization so
 * the `DockArea` view cache does not tear down and rebuild entities.
 *
 * Rust wraps a `u64`; the port uses an `Int`, which no process will exhaust.
 */
abstract NodeId(Int) {

    inline function new(raw:Int) {
        this = raw;
    }

    @:allow(gpui.base.dock, tests)
    static inline function fromU64(raw:Int):NodeId {
        return new NodeId(raw);
    }

    public inline function asU64():Int {
        return this;
    }

    public inline function toString():String {
        return 'NodeId(' + this + ')';
    }

}
