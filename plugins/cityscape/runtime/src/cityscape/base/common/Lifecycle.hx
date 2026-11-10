// Ported from vscode src/vs/base/common/lifecycle.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * An object that holds resources and releases them in `dispose()`.
 */
interface IDisposable {
    function dispose():Void;
}

/**
 * Module functions of lifecycle.ts. Only what the ported code needs so far
 * (no leak tracking).
 */
class Lifecycle {

    /**
     * Monaco's `Disposable.None`: a disposable that does nothing.
     */
    public static final NONE_DISPOSABLE:IDisposable = new NoneDisposable();

    /**
     * Turns a function that cleans up into an `IDisposable`.
     */
    public static function toDisposable(fn:() -> Void):IDisposable {
        return new FunctionDisposable(fn);
    }

    /**
     * Combine multiple disposable values into a single `IDisposable`.
     */
    public static function combinedDisposable(disposables:Array<IDisposable>):IDisposable {
        return toDisposable(() -> dispose(disposables));
    }

    /**
     * Disposes all the given disposables (null entries are skipped).
     */
    public static function dispose(disposables:Array<Null<IDisposable>>):Void {
        for (d in disposables) {
            if (d != null) {
                d.dispose();
            }
        }
    }

}

private class NoneDisposable implements IDisposable {

    public function new() {}

    public function dispose():Void {}

}

/**
 * Manages a collection of disposable values.
 *
 * This is the preferred way to manage multiple disposables. A `DisposableStore` is safer to work with than an
 * `IDisposable[]` as it considers edge cases, such as registering the same value multiple times or adding an item to a
 * store that has already been disposed of.
 */
class DisposableStore implements IDisposable {

    final _toDispose:Array<IDisposable> = [];

    var _isDisposed:Bool = false;

    public function new() {}

    /**
     * Dispose of all registered disposables and mark this object as disposed.
     *
     * Any future disposables added to this object will be disposed of on `add`.
     */
    public function dispose():Void {
        if (_isDisposed) {
            return;
        }
        _isDisposed = true;
        clear();
    }

    /**
     * Returns `true` if this object has been disposed
     */
    public var isDisposed(get, never):Bool;
    function get_isDisposed():Bool {
        return _isDisposed;
    }

    /**
     * Dispose of all registered disposables but do not mark this object as disposed.
     */
    public function clear():Void {
        if (_toDispose.length == 0) {
            return;
        }
        final toDispose = _toDispose.copy();
        _toDispose.resize(0);
        for (d in toDispose) {
            d.dispose();
        }
    }

    /**
     * Add a new `IDisposable` to the collection.
     */
    public function add<T:IDisposable>(o:T):T {
        if (o == null) {
            return o;
        }
        if ((cast o : IDisposable) == (cast this : IDisposable)) {
            throw 'Cannot register a disposable on itself!';
        }
        if (_isDisposed) {
            haxe.Log.trace('Trying to add a disposable to a DisposableStore that has already been disposed of. The added object will be leaked!', null);
        }
        else if (_toDispose.indexOf(o) == -1) {
            _toDispose.push(o);
        }
        return o;
    }

    /**
     * Deletes a disposable from store and disposes of it. This will not throw or warn and proceed to dispose the
     * disposable even when the disposable is not part in the store.
     */
    public function delete<T:IDisposable>(o:T):Void {
        if (o == null) {
            return;
        }
        _toDispose.remove(o);
        o.dispose();
    }

}

/**
 * Abstract base class for a disposable object.
 *
 * Subclasses can `_register` disposables that will be automatically cleaned up when this object is disposed of.
 */
class Disposable implements IDisposable {

    final _store:DisposableStore = new DisposableStore();

    public function new() {
        #if cityscape_debug_counters
        DebugCounters.disposables++;
        #end
    }

    public function dispose():Void {
        #if cityscape_debug_counters
        if (!_store.isDisposed) {
            DebugCounters.disposables--;
        }
        #end
        _store.dispose();
    }

    /**
     * Adds `o` to the collection of disposables managed by this object.
     */
    function _register<T:IDisposable>(o:T):T {
        if ((cast o : IDisposable) == (cast this : IDisposable)) {
            throw 'Cannot register a disposable on itself!';
        }
        return _store.add(o);
    }

}

/**
 * Manages the lifecycle of a disposable value that may be changed.
 *
 * This ensures that when the disposable value is changed, the previously held disposable is disposed of. You can
 * also register a `MutableDisposable` on a `Disposable` to ensure it is automatically cleaned up.
 */
class MutableDisposable<T:IDisposable> implements IDisposable {

    var _value:Null<T> = null;

    var _isDisposed:Bool = false;

    public function new() {}

    public var value(get, set):Null<T>;
    function get_value():Null<T> {
        return _isDisposed ? null : _value;
    }
    function set_value(value:Null<T>):Null<T> {
        if (_isDisposed || value == _value) {
            return value;
        }
        final old = _value;
        if (old != null) {
            old.dispose();
        }
        _value = value;
        return value;
    }

    /**
     * Resets the stored value and disposed of the previously stored value.
     */
    public function clear():Void {
        value = null;
    }

    public function dispose():Void {
        _isDisposed = true;
        final old = _value;
        if (old != null) {
            old.dispose();
        }
        _value = null;
    }

}

/**
 * The `IDisposable` returned by `Lifecycle.toDisposable`: calls the function
 * once, the first time it is disposed.
 */
class FunctionDisposable implements IDisposable {

    var fn:Null<() -> Void>;

    public function new(fn:() -> Void) {
        this.fn = fn;
    }

    public function dispose():Void {
        final fn = this.fn;
        if (fn != null) {
            this.fn = null;
            fn();
        }
    }

}
