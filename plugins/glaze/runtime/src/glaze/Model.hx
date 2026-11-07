// New code for the Haxe port of GPUI: base class of entities, replacing the
// entity storage of gpui-pre 0.3.10 (src/app/entity_map.rs, Zed Industries,
// Apache-2.0). See NOTICE.md.
package glaze;

/**
 * Base class of GPUI entities (the `T` of `Entity<T>`).
 *
 * A model is a plain observable Haxe object: fields read during render are
 * `@observe` fields (tracker), so changing them re-renders the views that read
 * them without `cx.notify()`. `cx.notify()` stays available for state that is
 * not observable.
 *
 * Create models with `app.newEntity(cx -> new MyModel(...))` or, from another
 * entity, `cx.newEntity(...)` (the new entity is then owned by the creating one).
 * A model constructed directly is attached to `App.current` the first time it
 * is used as an entity.
 *
 * Haxe has no `Drop`: entities are released explicitly with `destroy()`, which
 * runs the release observers and disposes everything the entity owns.
 */
class Model extends ceramic.Entity implements tracker.Observable {

    @:allow(glaze)
    var _slot:Null<EntitySlot> = null;

    /**
     * The unique id of this entity in its `App`.
     */
    public var entityId(get, never):Int;
    function get_entityId():Int {
        return slot().id;
    }

    public function new() {
        super();
    }

    @:allow(glaze)
    function slot():EntitySlot {
        if (_slot == null) {
            App.current.attachEntity(this);
        }
        return _slot;
    }

    override function destroy() {
        final slot = _slot;
        if (slot != null) {
            slot.app.releaseEntity(this);
        }
        super.destroy();
    }

}
