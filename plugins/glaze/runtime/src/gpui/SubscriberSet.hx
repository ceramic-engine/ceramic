// Ported from gpui-pre 0.3.10: src/subscription.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import haxe.ds.IntMap;

/**
 * One subscriber of a `SubscriberSet`.
 */
@:allow(gpui.SubscriberSet)
class Subscriber<Callback> {

    var active:Bool = false;

    var dropped:Bool = false;

    final callback:Callback;

    /**
     * The handle given back to the caller.
     */
    public var subscription(default, null):Subscription = null;

    function new(callback:Callback) {
        this.callback = callback;
    }

    /**
     * Activates the subscriber. Subscribers are inert until activated: GPUI
     * usually activates them with `defer` so that a subscription created while
     * an effect is dispatched does not receive that effect.
     */
    public function activate():Void {
        active = true;
    }

}

/**
 * Subscribers grouped by emitter key (an entity id or a global type id),
 * called in insertion order.
 */
class SubscriberSet<Callback> {

    /**
     * A key mapped to `null` means its subscribers are being iterated by `retain`.
     */
    final subscribers:IntMap<Null<Array<Subscriber<Callback>>>> = new IntMap();

    public function new() {}

    /**
     * Inserts a new subscriber for the given `emitterKey`. The subscriber is inert
     * until `activate()` is called on the returned value.
     */
    public function insert(emitterKey:Int, callback:Callback):Subscriber<Callback> {
        final subscriber = new Subscriber(callback);
        var list = subscribers.get(emitterKey);
        if (list == null) {
            list = [];
            subscribers.set(emitterKey, list);
        }
        list.push(subscriber);

        subscriber.subscription = new Subscription(() -> {
            subscriber.dropped = true;
            if (!subscribers.exists(emitterKey))
                return;
            final list = subscribers.get(emitterKey);
            if (list != null) {
                list.remove(subscriber);
                if (list.length == 0) {
                    subscribers.remove(emitterKey);
                }
            }
        });
        return subscriber;
    }

    /**
     * Removes every subscriber of the given emitter and returns the callbacks
     * of the active ones.
     */
    public function remove(emitterKey:Int):Array<Callback> {
        final list = subscribers.get(emitterKey);
        subscribers.remove(emitterKey);
        final result:Array<Callback> = [];
        if (list != null) {
            for (subscriber in list) {
                if (subscriber.active) {
                    result.push(subscriber.callback);
                }
            }
        }
        return result;
    }

    /**
     * Calls `f` for each active subscriber to the given emitter.
     * If `f` returns false, the subscriber is removed.
     */
    public function retain(emitterKey:Int, f:(Callback) -> Bool):Void {
        final list = subscribers.get(emitterKey);
        if (list == null)
            return;
        subscribers.set(emitterKey, null);

        var i = 0;
        while (i < list.length) {
            final subscriber = list[i];
            var keep = true;
            if (subscriber.active) {
                if (subscriber.dropped) {
                    keep = false;
                }
                else {
                    keep = f(subscriber.callback) && !subscriber.dropped;
                }
            }
            if (keep) {
                i++;
            }
            else {
                list.splice(i, 1);
            }
        }

        // Add any new subscribers that were added while invoking the callback
        if (subscribers.exists(emitterKey)) {
            final newSubscribers = subscribers.get(emitterKey);
            if (newSubscribers != null) {
                for (subscriber in newSubscribers) {
                    list.push(subscriber);
                }
            }
            subscribers.remove(emitterKey);
        }

        if (list.length > 0) {
            subscribers.set(emitterKey, list);
        }
    }

    /**
     * `true` if at least one subscriber (active or not) exists for this key.
     */
    public function hasSubscribers(emitterKey:Int):Bool {
        final list = subscribers.get(emitterKey);
        return list != null && list.length > 0;
    }

}
