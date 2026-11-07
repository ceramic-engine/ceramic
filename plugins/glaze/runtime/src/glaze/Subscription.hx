// Ported from gpui-pre 0.3.10: src/subscription.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A handle to a subscription created by GPUI. Disposing it cancels the
 * subscription and the callback will no longer be invoked.
 *
 * Haxe has no `Drop`: a subscription returned by a `Context` method is owned
 * by the entity of that context and disposed when the entity is destroyed.
 * A subscription created directly on `App` has no owner and lives until
 * `dispose()` is called or until the observed entity is released.
 */
class Subscription {

    var unsubscribe:Null<() -> Void>;

    @:allow(glaze.EntitySlot)
    var owner:Null<EntitySlot> = null;

    /**
     * Creates a new subscription with a callback that gets invoked when
     * this subscription is disposed.
     */
    public function new(unsubscribe:() -> Void) {
        this.unsubscribe = unsubscribe;
    }

    /**
     * Cancels the subscription (Rust: dropping the `Subscription`).
     */
    public function dispose():Void {
        if (owner != null) {
            final slot = owner;
            owner = null;
            slot.removeOwnedSubscription(this);
        }
        final unsubscribe = this.unsubscribe;
        if (unsubscribe != null) {
            this.unsubscribe = null;
            unsubscribe();
        }
    }

    /**
     * Detaches the subscription from this handle. The callback will continue to be
     * invoked until the entities it has been subscribed to are released. A detached
     * subscription is not disposed anymore when its owner entity is destroyed
     * (callbacks that need the owner still stop, because they check that it is alive).
     */
    public function detach():Void {
        if (owner != null) {
            final slot = owner;
            owner = null;
            slot.removeOwnedSubscription(this);
        }
        unsubscribe = null;
    }

    /**
     * Joins two subscriptions into a single subscription. Detach will
     * detach both interior subscriptions.
     */
    public static function join(subscriptionA:Subscription, subscriptionB:Subscription):Subscription {
        final aUnsubscribe = subscriptionA.takeUnsubscribe();
        final bUnsubscribe = subscriptionB.takeUnsubscribe();
        return new Subscription(() -> {
            if (aUnsubscribe != null) aUnsubscribe();
            if (bUnsubscribe != null) bUnsubscribe();
        });
    }

    function takeUnsubscribe():Null<() -> Void> {
        if (owner != null) {
            final slot = owner;
            owner = null;
            slot.removeOwnedSubscription(this);
        }
        final result = unsubscribe;
        unsubscribe = null;
        return result;
    }

    /**
     * `true` until the subscription is disposed or detached.
     */
    public var isActive(get, never):Bool;
    inline function get_isActive():Bool {
        return unsubscribe != null;
    }

}
