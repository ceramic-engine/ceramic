// Ported from gpui-pre 0.3.10: src/executor.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import tracker.Autorun;

/**
 * Untyped part of `Task<T>`: state, completion listeners, cancellation and
 * ownership. Lets entities keep a list of their tasks whatever their type.
 */
class AnyTask {

    /**
     * Current state of the task.
     */
    public var state(default, null):TaskState = Pending;

    /**
     * The error, when the task failed.
     */
    public var error(default, null):Dynamic = null;

    /**
     * Called once when the task is cancelled while still pending. Cancels whatever
     * produces the result (a timer, an awaited task...).
     */
    @:allow(gpui)
    var cancelHook:Null<Void->Void> = null;

    var listeners:Null<Array<Void->Void>> = null;

    @:allow(gpui.EntitySlot)
    var owner:Null<EntitySlot> = null;

    var detached:Bool = false;

    var logErrors:Bool = false;

    function new() {}

    public var isPending(get, never):Bool;
    inline function get_isPending():Bool {
        return state == Pending;
    }

    public var isReady(get, never):Bool;
    inline function get_isReady():Bool {
        return state == Ready;
    }

    public var isFailed(get, never):Bool;
    inline function get_isFailed():Bool {
        return state == Failed;
    }

    public var isCancelled(get, never):Bool;
    inline function get_isCancelled():Bool {
        return state == Cancelled;
    }

    /**
     * Cancels the task (Rust: dropping it). Pending continuations never run.
     * A task is meant to have a single consumer, like a Rust future: cancelling a
     * task derived with `then` / `andThen` also cancels the task it waits on.
     */
    public function cancel():Void {
        if (state != Pending)
            return;
        state = Cancelled;
        final hook = cancelHook;
        cancelHook = null;
        if (hook != null) {
            hook();
        }
        complete();
    }

    /**
     * Lets the task run to completion even if its owner entity is destroyed
     * (Rust: `Task::detach`). Errors are ignored.
     */
    public function detach():Void {
        detached = true;
        if (owner != null) {
            final slot = owner;
            owner = null;
            slot.removeOwnedTask(this);
        }
    }

    /**
     * Same as `detach()`, but logs the error if the task fails
     * (Rust: `detach_and_log_err`).
     */
    public function detachAndLogErr():Void {
        logErrors = true;
        detach();
        if (state == Failed) {
            logError();
        }
    }

    /**
     * Calls `listener` once the task is ready, failed or cancelled, synchronously
     * if it already is. Mostly for internal use: prefer `then` / `andThen`.
     */
    public function onComplete(listener:Void->Void):Void {
        if (state != Pending) {
            listener();
            return;
        }
        if (listeners == null) {
            listeners = [];
        }
        listeners.push(listener);
    }

    @:allow(gpui)
    function rejectWith(error:Dynamic):Void {
        if (state != Pending)
            return;
        this.error = error;
        state = Failed;
        cancelHook = null;
        #if debug
        if (listeners == null && !logErrors && !Std.isOfType(error, EntityReleasedError)) {
            ceramic.Shortcuts.log.warning('Unhandled task error: $error');
        }
        #end
        if (logErrors) {
            logError();
        }
        complete();
    }

    function logError():Void {
        ceramic.Shortcuts.log.error('Task failed: $error');
    }

    function complete():Void {
        if (owner != null) {
            final slot = owner;
            owner = null;
            slot.removeOwnedTask(this);
        }
        final listeners = this.listeners;
        if (listeners != null) {
            this.listeners = null;
            for (listener in listeners) {
                listener();
            }
        }
    }

    /**
     * Runs `f` with tracker capture disabled, so that code run by executors,
     * timers and continuations never subscribes the view being rendered.
     */
    @:allow(gpui)
    static function runUnobserved(f:Void->Void):Void {
        Autorun.unobserve();
        try {
            f();
        }
        catch (e:haxe.Exception) {
            Autorun.reobserve();
            throw e;
        }
        Autorun.reobserve();
    }

}
