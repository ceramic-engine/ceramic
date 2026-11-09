// Ported from vscode src/vs/base/common/event.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import cityscape.base.common.Lifecycle.IDisposable;

/**
 * An event: a function to which a listener is subscribed. The returned
 * `IDisposable` removes the listener.
 *
 * Monaco's `Event<T>` also takes `thisArgs` and a disposable store; Haxe
 * closures make `thisArgs` unnecessary, and the store is added by the caller.
 * `Event<void>` is `VoidEvent` (a Haxe listener of type `() -> Void`).
 */
typedef Event<T> = (listener:(e:T) -> Void) -> IDisposable;

/**
 * Monaco's `Event<void>`: an event whose listeners take no argument.
 */
typedef VoidEvent = (listener:() -> Void) -> IDisposable;

/**
 * The listeners of an emitter. Listeners removed while the emitter fires
 * are skipped and compacted once the delivery is done; listeners added while
 * it fires get the next events only; an event fired from a listener is
 * delivered after the current one (like Monaco's delivery queue). Firing
 * does not allocate.
 */
@:allow(cityscape.base.common)
private class ListenerList<L> {

    var listeners:Array<Null<ListenerEntry<L>>> = [];

    var count:Int = 0;

    var firing:Int = 0;

    var hasHoles:Bool = false;

    var disposed:Bool = false;

    /**
     * Monaco's `EventDeliveryQueue`: the event being delivered and the
     * listeners left. An event fired while another one is delivered first
     * completes the delivery of the current one, so that every listener
     * gets the events in order.
     */
    var dqActive:Bool = false;

    var dqIndex:Int = 0;

    var dqEnd:Int = 0;

    public function new() {}

    function add(listener:L):IDisposable {
        if (disposed) {
            return Lifecycle.NONE_DISPOSABLE;
        }
        final entry = new ListenerEntry<L>(this, listener);
        listeners.push(entry);
        count++;
        return entry;
    }

    function remove(entry:ListenerEntry<L>):Void {
        for (i in 0...listeners.length) {
            if (listeners[i] == entry) {
                listeners[i] = null;
                count--;
                if (firing > 0) {
                    hasHoles = true;
                }
                else {
                    listeners.splice(i, 1);
                }
                return;
            }
        }
    }

    inline function beginFire():Int {
        firing++;
        return listeners.length;
    }

    function endFire():Void {
        firing--;
        if (firing == 0 && hasHoles) {
            hasHoles = false;
            var j = 0;
            for (i in 0...listeners.length) {
                final l = listeners[i];
                if (l != null) {
                    listeners[j++] = l;
                }
            }
            listeners.resize(j);
        }
    }

    function clear():Void {
        for (i in 0...listeners.length) {
            final l = listeners[i];
            if (l != null) {
                l.list = null;
            }
        }
        if (firing > 0) {
            for (i in 0...listeners.length) {
                listeners[i] = null;
            }
            hasHoles = true;
        }
        else {
            listeners.resize(0);
        }
        count = 0;
    }

}

/**
 * A subscribed listener; disposing it removes it.
 */
@:allow(cityscape.base.common)
private class ListenerEntry<L> implements IDisposable {

    var list:Null<ListenerList<L>>;

    final fn:L;

    function new(list:ListenerList<L>, fn:L) {
        this.list = list;
        this.fn = fn;
    }

    public function dispose():Void {
        final list = this.list;
        if (list != null) {
            this.list = null;
            list.remove(this);
        }
    }

}

/**
 * The Emitter can be used to expose an Event to the public
 * to fire it from the insides.
 * Sample:
 * ```haxe
 * class Document {
 *
 *     final _onDidChange = new Emitter<String>();
 *
 *     public final onDidChange:Event<String> = _onDidChange.event;
 *
 *     // getter-style
 *     // get onDidChange(): Event<(value:string)=>any> {
 *     //  return this._onDidChange.event;
 *     // }
 *
 *     private _doIt() {
 *         //...
 *         this._onDidChange.fire(value);
 *     }
 * }
 * ```
 *
 * Only the core of Monaco's `Emitter` is ported (no leak monitor, no
 * delivery queue options, no `onWillAddFirstListener` hooks).
 */
class Emitter<T> implements IDisposable {

    final _listeners:ListenerList<(e:T) -> Void> = new ListenerList<(e:T) -> Void>();

    /**
     * For the public to allow to subscribe to events from this Emitter.
     */
    public final event:Event<T>;

    public function new() {
        event = (listener:(e:T) -> Void) -> _listeners.add(listener);
    }

    /**
     * To be kept private to fire an event to subscribers.
     */
    var _deliveredValue:Null<T> = null;

    public function fire(event:T):Void {
        final list = _listeners;
        if (list.dqActive) {
            // Fired while delivering: complete the current delivery first
            _deliverQueue();
        }
        if (list.count == 0) {
            return;
        }
        list.beginFire();
        list.dqActive = true;
        list.dqIndex = 0;
        list.dqEnd = list.listeners.length;
        _deliveredValue = event;
        _deliverQueue();
        list.endFire();
    }

    function _deliverQueue():Void {
        final list = _listeners;
        final listeners = list.listeners;
        while (list.dqIndex < list.dqEnd) {
            // dqIndex is incremented before the call, which might reenter
            final entry = listeners[list.dqIndex++];
            if (entry != null) {
                // Like Monaco, an error in a listener is reported and the
                // other listeners still get the event
                try {
                    entry.fn(_deliveredValue);
                }
                catch (e:Dynamic) {
                    Errors.onUnexpectedError(e);
                }
            }
        }
        list.dqActive = false;
        _deliveredValue = null;
    }

    public function hasListeners():Bool {
        return _listeners.count > 0;
    }

    public function dispose():Void {
        _listeners.disposed = true;
        _listeners.clear();
    }

}

/**
 * Monaco's `Emitter<void>`: an emitter whose listeners take no argument.
 */
class VoidEmitter implements IDisposable {

    final _listeners:ListenerList<() -> Void> = new ListenerList<() -> Void>();

    /**
     * For the public to allow to subscribe to events from this Emitter.
     */
    public final event:VoidEvent;

    public function new() {
        event = (listener:() -> Void) -> _listeners.add(listener);
    }

    /**
     * To be kept private to fire an event to subscribers.
     */
    public function fire():Void {
        final list = _listeners;
        if (list.dqActive) {
            // Fired while delivering: complete the current delivery first
            _deliverQueue();
        }
        if (list.count == 0) {
            return;
        }
        list.beginFire();
        list.dqActive = true;
        list.dqIndex = 0;
        list.dqEnd = list.listeners.length;
        _deliverQueue();
        list.endFire();
    }

    function _deliverQueue():Void {
        final list = _listeners;
        final listeners = list.listeners;
        while (list.dqIndex < list.dqEnd) {
            // dqIndex is incremented before the call, which might reenter
            final entry = listeners[list.dqIndex++];
            if (entry != null) {
                // Like Monaco, an error in a listener is reported and the
                // other listeners still get the event
                try {
                    entry.fn();
                }
                catch (e:Dynamic) {
                    Errors.onUnexpectedError(e);
                }
            }
        }
        list.dqActive = false;
    }

    public function hasListeners():Bool {
        return _listeners.count > 0;
    }

    public function dispose():Void {
        _listeners.disposed = true;
        _listeners.clear();
    }

}
