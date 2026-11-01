// Ported from gpui-pre 0.3.10: src/app/entity_map.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A handle to an entity that does not keep it alive: once the entity is
 * destroyed, `upgrade()` returns null and `update` throws `EntityReleasedError`
 * (Rust's `Result`: inside task continuations the error fails the task, like `?`).
 * Use `tryUpdate` where Rust code calls `.ok()` on the result.
 */
abstract WeakEntity<T:Model>(EntitySlot) {

    @:allow(gpui)
    inline function new(slot:EntitySlot) {
        this = slot;
    }

    /**
     * Get the entity ID associated with this entity.
     */
    public inline function entityId():Int {
        return this.id;
    }

    /**
     * Upgrade this weak entity reference into a strong entity reference,
     * or null if the entity has been released.
     */
    public function upgrade():Null<Entity<T>> {
        return this.isAlive() ? cast this.model : null;
    }

    /**
     * `true` if `upgrade()` would succeed.
     */
    public inline function isUpgradable():Bool {
        return this.isAlive();
    }

    /**
     * Updates the entity referenced by this handle with the given function if
     * the referenced entity still exists. Throws `EntityReleasedError` otherwise.
     */
    public function update<R>(cx:AppContext, f:(T, Context<T>) -> R):R {
        final entity = upgrade();
        if (entity == null) {
            throw new EntityReleasedError(this.id);
        }
        return entity.update(cx, f);
    }

    /**
     * Same as `update` but returns `false` instead of throwing when the entity
     * was released (Rust: `weak.update(cx, ...).ok()`).
     */
    public function tryUpdate(cx:AppContext, f:(T, Context<T>) -> Void):Bool {
        final entity = upgrade();
        if (entity == null) {
            return false;
        }
        entity.update(cx, f);
        return true;
    }

    /**
     * Reads the entity referenced by this handle with the given function if the
     * referenced entity still exists. Throws `EntityReleasedError` otherwise.
     */
    public function readWith<R>(cx:AppContext, f:(T, App) -> R):R {
        final entity = upgrade();
        if (entity == null) {
            throw new EntityReleasedError(this.id);
        }
        return f(entity, cx);
    }

    /**
     * `true` if both handles point to the same entity.
     */
    public inline function equals(other:Null<WeakEntity<T>>):Bool {
        return other != null && this.id == other.entityId() && this.app == (cast other : EntitySlot).app;
    }

}
