// Ported from gpui-kit 0.8.1: crates/base/src/dock/layout/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.Entity;
import glaze.Model;

/**
 * Stable panel identity. Wraps the entity id of the panel entity so the
 * layout algebra can be exercised without an `App`.
 */
abstract PanelId(Int) {

    inline function new(raw:Int) {
        this = raw;
    }

    public static inline function fromU64(raw:Int):PanelId {
        return new PanelId(raw);
    }

    /**
     * Rust `impl From<EntityId> for PanelId`.
     */
    public static inline function fromEntity<T:Model>(entity:Entity<T>):PanelId {
        return new PanelId(entity.entityId());
    }

    /**
     * Rust `PanelId::from(entity_id)`.
     */
    public static inline function fromEntityId(entityId:Int):PanelId {
        return new PanelId(entityId);
    }

    public inline function asU64():Int {
        return this;
    }

    public inline function toString():String {
        return 'PanelId(' + this + ')';
    }

}
