// Ported from gpui-pre 0.3.10: src/app/entity_map.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A strong handle to an entity: a zero cost abstract over the model itself,
 * which keeps GPUI's API (`read`, `update`, `downgrade`...).
 */
abstract Entity<T:Model>(T) from T to T {

    /**
     * Get the entity ID associated with this entity.
     */
    public inline function entityId():Int {
        return this.entityId;
    }

    /**
     * Downgrade this entity pointer to a non-retaining weak pointer.
     */
    public inline function downgrade():WeakEntity<T> {
        return new WeakEntity<T>(this.slot());
    }

    /**
     * Upcast this entity into an untyped model.
     */
    public inline function intoAny():Model {
        return this;
    }

    /**
     * Grab a reference to this entity from the context.
     */
    public inline function read(cx:AppContext):T {
        return this;
    }

    /**
     * Read the entity referenced by this handle with the given function.
     */
    public function readWith<R>(cx:AppContext, f:(T, App) -> R):R {
        return f(this, cx);
    }

    /**
     * Updates the entity referenced by this handle with the given function,
     * inside an `App.update` (effects are flushed at the end of the outermost update).
     */
    public function update<R>(cx:AppContext, f:(T, Context<T>) -> R):R {
        final app:App = cx;
        return app.updateEntity(this, f);
    }

    /**
     * Embed this entity (a view) as a cached `ViewElement` laid out at `style`
     * (GPUI's `Entity::cached`, see `AnyView.cached`).
     */
    public inline function cached(style:StyleRefinement):ViewElement {
        return ViewElement.forView(this).cached(style);
    }

    /**
     * Embed this entity (a view) without the default view caching: it
     * renders every frame.
     */
    public inline function uncached():ViewElement {
        return ViewElement.forView(this).uncached();
    }

    /**
     * `true` if both handles point to the same entity.
     */
    public inline function equals(other:Null<Entity<T>>):Bool {
        return (this : Model) == (other : Model);
    }

}
