// Ported from gpui-pre 0.3.10: src/app/entity_map.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Bookkeeping of one entity: its id, the model once built, and what it owns.
 *
 * Stands for the `Slot` reserved in GPUI's `EntityMap` (the id exists before
 * the model is built, so a `Context` can be given to the build closure) and
 * replaces Rust's ownership: subscriptions, tasks and child entities created
 * through the entity's `Context` are disposed when it is released.
 * `Context<T>` extends this class, and `WeakEntity<T>` wraps it.
 */
class EntitySlot {

    /**
     * The app owning the entity.
     */
    public final app:App;

    /**
     * The entity id.
     */
    public final id:Int;

    /**
     * The model, `null` while it is being built and once it has been released.
     */
    @:allow(gpui)
    var model:Null<Model> = null;

    /**
     * The entity that created this one through its `Context`, if any.
     */
    @:allow(gpui)
    var parent:Null<EntitySlot> = null;

    var ownedSubscriptions:Null<Array<Subscription>> = null;

    var ownedTasks:Null<Array<AnyTask>> = null;

    var ownedEntities:Null<Array<Model>> = null;

    @:allow(gpui)
    function new(app:App, id:Int) {
        this.app = app;
        this.id = id;
    }

    /**
     * `true` once the model is built, until it is destroyed.
     */
    public function isAlive():Bool {
        return model != null && !model.destroyed;
    }

    @:allow(gpui)
    function ownSubscription(subscription:Subscription):Subscription {
        if (subscription.owner != null || !subscription.isActive)
            return subscription;
        if (model != null && model.destroyed) {
            subscription.dispose();
            return subscription;
        }
        if (ownedSubscriptions == null) {
            ownedSubscriptions = [];
        }
        subscription.owner = this;
        ownedSubscriptions.push(subscription);
        return subscription;
    }

    @:allow(gpui)
    function removeOwnedSubscription(subscription:Subscription):Void {
        if (ownedSubscriptions != null) {
            ownedSubscriptions.remove(subscription);
        }
    }

    @:allow(gpui)
    function ownTask(task:AnyTask):Void {
        if (!task.isPending || task.owner != null)
            return;
        if (model != null && model.destroyed) {
            task.cancel();
            return;
        }
        if (ownedTasks == null) {
            ownedTasks = [];
        }
        task.owner = this;
        ownedTasks.push(task);
    }

    @:allow(gpui)
    function removeOwnedTask(task:AnyTask):Void {
        if (ownedTasks != null) {
            ownedTasks.remove(task);
        }
    }

    @:allow(gpui)
    function ownEntity(entity:Model):Void {
        if (ownedEntities == null) {
            ownedEntities = [];
        }
        ownedEntities.push(entity);
    }

    @:allow(gpui)
    function removeOwnedEntity(entity:Model):Void {
        if (ownedEntities != null) {
            ownedEntities.remove(entity);
        }
    }

    /**
     * Disposes owned subscriptions, cancels owned tasks and destroys owned
     * entities (what dropping the fields of the entity does in Rust).
     */
    @:allow(gpui)
    function releaseOwned():Void {
        final subscriptions = ownedSubscriptions;
        if (subscriptions != null) {
            ownedSubscriptions = null;
            for (subscription in subscriptions) {
                subscription.owner = null;
                subscription.dispose();
            }
        }
        final tasks = ownedTasks;
        if (tasks != null) {
            ownedTasks = null;
            for (task in tasks) {
                task.owner = null;
                task.cancel();
            }
        }
        final entities = ownedEntities;
        if (entities != null) {
            ownedEntities = null;
            for (entity in entities) {
                entity.destroy();
            }
        }
    }

}
