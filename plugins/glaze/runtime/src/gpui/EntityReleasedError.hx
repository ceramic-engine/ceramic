// Ported from gpui-pre 0.3.10: src/app/entity_map.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Thrown by `WeakEntity.update` / `readWith` when the entity has been released
 * (Rust: the `Err` of `anyhow!("entity released")`). Inside task continuations,
 * it fails the task like the `?` operator would.
 */
class EntityReleasedError extends haxe.Exception {

    public final entityId:Int;

    public function new(entityId:Int) {
        super('entity released');
        this.entityId = entityId;
    }

}
