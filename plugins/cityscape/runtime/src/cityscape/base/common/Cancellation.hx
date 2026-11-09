// Ported from vscode src/vs/base/common/cancellation.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import cityscape.base.common.Event.VoidEmitter;
import cityscape.base.common.Lifecycle.IDisposable;

/**
 * A token telling an operation whether it was cancelled.
 *
 * Monaco's `onCancellationRequested` is an `Event<any>`; here it is a method
 * taking a listener without argument (the event carries no value).
 */
interface CancellationToken {

    /**
     * A flag signalling is cancellation has been requested.
     */
    var isCancellationRequested(get, never):Bool;

    /**
     * An event which fires when cancellation is requested. This event
     * only ever fires `once` as cancellation can only happen once. Listeners
     * that are registered after cancellation will be called (next event loop run),
     * but also only once.
     */
    function onCancellationRequested(listener:() -> Void):IDisposable;

}

/**
 * The constants of Monaco's `CancellationToken` namespace.
 */
class CancellationTokens {

    public static final None:CancellationToken = new FixedToken(false);

    public static final Cancelled:CancellationToken = new FixedToken(true);

    public static function isCancellationToken(thing:Any):Bool {
        return Std.isOfType(thing, CancellationToken);
    }

}

/**
 * `CancellationToken.None` and `CancellationToken.Cancelled`.
 */
private class FixedToken implements CancellationToken {

    final _cancelled:Bool;

    public var isCancellationRequested(get, never):Bool;
    function get_isCancellationRequested():Bool {
        return _cancelled;
    }

    public function new(cancelled:Bool) {
        _cancelled = cancelled;
    }

    public function onCancellationRequested(listener:() -> Void):IDisposable {
        if (!_cancelled) {
            return Lifecycle.NONE_DISPOSABLE;
        }
        return shortcutEvent(listener);
    }

    /**
     * Calls the listener on the next run of the loop.
     */
    public static function shortcutEvent(listener:() -> Void):IDisposable {
        final cancel = Async.setTimeout(listener, 0);
        return Lifecycle.toDisposable(cancel);
    }

}

private class MutableToken implements CancellationToken {

    var _isCancelled:Bool = false;
    var _emitter:Null<VoidEmitter> = null;

    public function new() {}

    public function cancel():Void {
        if (!_isCancelled) {
            _isCancelled = true;
            if (_emitter != null) {
                _emitter.fire();
                dispose();
            }
        }
    }

    public var isCancellationRequested(get, never):Bool;
    function get_isCancellationRequested():Bool {
        return _isCancelled;
    }

    public function onCancellationRequested(listener:() -> Void):IDisposable {
        if (_isCancelled) {
            return FixedToken.shortcutEvent(listener);
        }
        if (_emitter == null) {
            _emitter = new VoidEmitter();
        }
        return _emitter.event(listener);
    }

    public function dispose():Void {
        if (_emitter != null) {
            _emitter.dispose();
            _emitter = null;
        }
    }

}

class CancellationTokenSource {

    var _token:Null<CancellationToken> = null;
    var _parentListener:Null<IDisposable> = null;

    public function new(?parent:CancellationToken) {
        _parentListener = parent != null ? parent.onCancellationRequested(cancel) : null;
    }

    public var token(get, never):CancellationToken;
    function get_token():CancellationToken {
        if (_token == null) {
            // be lazy and create the token only when
            // actually needed
            _token = new MutableToken();
        }
        return _token;
    }

    public function cancel():Void {
        if (_token == null) {
            // save an object by returning the default
            // cancelled token when cancellation happens
            // before someone asks for the token
            _token = CancellationTokens.Cancelled;
        }
        else if (Std.isOfType(_token, MutableToken)) {
            // actually cancel
            (cast _token : MutableToken).cancel();
        }
    }

    public function dispose(cancel:Bool = false):Void {
        if (cancel) {
            this.cancel();
        }
        if (_parentListener != null) {
            _parentListener.dispose();
        }
        if (_token == null) {
            // ensure to initialize with an empty token if we had none
            _token = CancellationTokens.None;
        }
        else if (Std.isOfType(_token, MutableToken)) {
            // actually dispose
            (cast _token : MutableToken).dispose();
        }
    }

}
