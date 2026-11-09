// Ported from vscode src/vs/base/common/observableInternal/base.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common.observableInternal;

import cityscape.base.common.Lifecycle;

/**
 * The part of `IObservable` that does not depend on the type of its value:
 * observers and transactions hold observables of any type through it (Haxe
 * type parameters are invariant, TypeScript's `IObservable<any>` is not).
 */
interface IObservableBase {

    /**
     * Forces the observable to check for changes and report them.
     *
     * Has the same effect as calling `IObservable.get`, but does not force the observable
     * to actually construct the value, e.g. if change deltas are used.
     * Calls `IObserver.handleChange` if the observable notices that the value changed.
     * Must not be called from `IObserver.handleChange`!
     */
    function reportChanges():Void;

    /**
     * Adds the observer to the set of subscribed observers.
     * This method is idempotent.
     */
    function addObserver(observer:IObserver):Void;

    /**
     * Removes the observer from the set of subscribed observers.
     * This method is idempotent.
     */
    function removeObserver(observer:IObserver):Void;

    /**
     * A human-readable name for debugging purposes.
     */
    var debugName(get, never):String;

}

/**
 * Represents an observable value.
 *
 * While observers can miss temporary values of an observable,
 * they will receive all change values (as long as they are subscribed)!
 * The type of the change values (Monaco's `TChange`) is `Any` here.
 */
interface IObservable<T> extends IObservableBase {

    /**
     * Returns the current value.
     *
     * Calls `IObserver.handleChange` if the observable notices that the value changed.
     * Must not be called from `IObserver.handleChange`!
     */
    function get():T;

    /**
     * Reads the current value and subscribes the reader to this observable.
     *
     * Calls `IReader.readObservable` if a reader is given, otherwise `IObservable.get`.
     */
    function read(reader:Null<IReader>):T;

    /**
     * Creates a derived observable that depends on this observable.
     * Use the reader to read other observables.
     */
    function map<TNew>(fn:(value:T, reader:IReader) -> TNew):IObservable<TNew>;

    /**
     * Makes sure this value is computed eagerly.
     */
    function recomputeInitiallyAndOnChange(store:DisposableStore, ?handleValue:(value:T) -> Void):IObservable<T>;

    /**
     * Makes sure this value is cached.
     */
    function keepObserved(store:DisposableStore):IObservable<T>;

}

interface IReader {

    /**
     * Reads the value of an observable and subscribes to it.
     */
    function readObservable<T>(observable:IObservable<T>):T;

}

/**
 * Represents an observer that can be subscribed to an observable.
 *
 * If an observer is subscribed to an observable and that observable didn't signal
 * a change through one of the observer methods, the observer can assume that the
 * observable didn't change.
 * If an observable reported a possible change, `IObservable.reportChanges` forces
 * the observable to report an actual change if there was one.
 */
interface IObserver {

    /**
     * Signals that the given observable might have changed and a transaction potentially modifying that observable started.
     * Before the given observable can call this method again, is must call `IObserver.endUpdate`.
     *
     * Implementations must not get/read the value of other observables, as they might not have received this event yet!
     * The method `IObservable.reportChanges` can be used to force the observable to report the changes.
     */
    function beginUpdate(observable:IObservableBase):Void;

    /**
     * Signals that the transaction that potentially modified the given observable ended.
     * This is a good place to react to (potential) changes.
     */
    function endUpdate(observable:IObservableBase):Void;

    /**
     * Signals that the given observable might have changed.
     * The method `IObservable.reportChanges` can be used to force the observable to report the changes.
     *
     * Implementations must not get/read the value of other observables, as they might not have received this event yet!
     * The change should be processed lazily or in `IObserver.endUpdate`.
     */
    function handlePossibleChange(observable:IObservableBase):Void;

    /**
     * Signals that the given `observable` changed.
     *
     * Implementations must not get/read the value of other observables, as they might not have received this event yet!
     * The change should be processed lazily or in `IObserver.endUpdate`.
     *
     * @param change Indicates how or why the value changed.
     */
    function handleChange(observable:IObservableBase, change:Any):Void;

}

interface ISettable<T> {

    /**
     * Sets the value of the observable.
     * Use a transaction to batch multiple changes (with a transaction, observers only react at the end of the transaction).
     *
     * @param transaction When given, value changes are handled on demand or when the transaction ends.
     * @param change Describes how or why the value changed.
     */
    function set(value:T, transaction:Null<ITransaction>, ?change:Any):Void;

}

interface ITransaction {

    /**
     * Calls `Observer.beginUpdate` immediately
     * and `Observer.endUpdate` when the transaction ends.
     */
    function updateObserver(observer:IObserver, observable:IObservableBase):Void;

}

/**
 * A settable observable.
 */
interface ISettableObservable<T> extends IObservable<T> extends ISettable<T> {}

/**
 * Monaco's `EqualityComparer<T>` (equals.ts).
 */
typedef EqualityComparer<T> = (a:T, b:T) -> Bool;

/**
 * The change given to a `handleChange` function of a derived or an autorun
 * (Monaco's `IChangeContext`). One instance per observer, reused.
 */
class ChangeContext {

    public var changedObservable(default, null):Null<IObservableBase> = null;

    public var change(default, null):Any = null;

    public function new() {}

    @:allow(cityscape.base.common.observableInternal)
    function reset(observable:IObservableBase, change:Any):ChangeContext {
        this.changedObservable = observable;
        this.change = change;
        return this;
    }

    /**
     * Returns if the given observable caused the change.
     */
    public function didChange(observable:IObservableBase):Bool {
        return observable == changedObservable;
    }

}

typedef IChangeContext = ChangeContext;

class ConvenientObservable<T> implements IObservable<T> {

    public var debugName(get, never):String;

    function get_debugName():String {
        return '(anonymous)';
    }

    function new() {}

    public function get():T {
        throw 'abstract';
    }

    public function reportChanges():Void {
        this.get();
    }

    public function addObserver(observer:IObserver):Void {
        throw 'abstract';
    }

    public function removeObserver(observer:IObserver):Void {
        throw 'abstract';
    }

    /** @sealed */
    public function read(reader:Null<IReader>):T {
        if (reader != null) {
            return reader.readObservable(this);
        }
        else {
            return this.get();
        }
    }

    /** @sealed */
    public function map<TNew>(fn:(value:T, reader:IReader) -> TNew):IObservable<TNew> {
        return Derived.derived(reader -> fn(this.read(reader), reader));
    }

    public function recomputeInitiallyAndOnChange(store:DisposableStore, ?handleValue:(value:T) -> Void):IObservable<T> {
        store.add(Utils.recomputeInitiallyAndOnChange(this, handleValue));
        return this;
    }

    /**
     * Ensures that this observable is observed. This keeps the cache alive.
     * However, in case of deriveds, it does not force eager evaluation (only when the value is read/get).
     * Use `recomputeInitiallyAndOnChange` for eager evaluation.
     */
    public function keepObserved(store:DisposableStore):IObservable<T> {
        store.add(Utils.keepObserved(this));
        return this;
    }

}

/**
 * Monaco's `BaseObservable`. Its `Set` of observers is an array in insertion
 * order (iterated by index, like a JavaScript `Set` that sees the
 * observers added during an iteration).
 */
class BaseObservable<T> extends ConvenientObservable<T> {

    final observers:Array<IObserver> = [];

    function new() {
        super();
    }

    override public function addObserver(observer:IObserver):Void {
        final len = this.observers.length;
        if (this.observers.indexOf(observer) == -1) {
            this.observers.push(observer);
        }
        if (len == 0) {
            this.onFirstObserverAdded();
        }
    }

    override public function removeObserver(observer:IObserver):Void {
        final deleted = this.observers.remove(observer);
        if (deleted && this.observers.length == 0) {
            this.onLastObserverRemoved();
        }
    }

    function onFirstObserverAdded():Void {}

    function onLastObserverRemoved():Void {}

    inline function hasObserver(observer:IObserver):Bool {
        return this.observers.indexOf(observer) != -1;
    }

}

/**
 * Module functions of base.ts.
 */
class Base {

    /**
     * Starts a transaction in which many observables can be changed at once.
     * Reaction run on demand or when the transaction ends.
     */
    public static function transaction(fn:(tx:ITransaction) -> Void):Void {
        final tx = new TransactionImpl();
        var error:Null<haxe.Exception> = null;
        try {
            fn(tx);
        }
        catch (e:haxe.Exception) {
            error = e;
        }
        tx.finish();
        if (error != null) {
            throw error;
        }
    }

    /**
     * Allows to chain transactions.
     */
    public static function subtransaction(tx:Null<ITransaction>, fn:(tx:ITransaction) -> Void):Void {
        if (tx == null) {
            transaction(fn);
        }
        else {
            fn(tx);
        }
    }

    /**
     * Creates an observable value.
     * Observers get informed when the value changes.
     */
    public static function observableValue<T>(debugName:String, initialValue:T):ISettableObservable<T> {
        return new ObservableValue<T>(debugName, initialValue, strictEquals);
    }

    /**
     * Monaco's `observableValueOpts` (without the `lazy` option).
     */
    public static function observableValueOpts<T>(debugName:String, equalsFn:EqualityComparer<T>, initialValue:T):ISettableObservable<T> {
        return new ObservableValue<T>(debugName, initialValue, equalsFn);
    }

    /**
     * A disposable observable. When disposed, its value is also disposed.
     * When a new value is set, the previous value is disposed.
     */
    public static function disposableObservableValue<T:IDisposable>(debugName:String, initialValue:Null<T>):DisposableObservableValue<T> {
        return new DisposableObservableValue<T>(debugName, initialValue, strictEquals);
    }

    /**
     * Monaco's `strictEquals` (equals.ts): `===`.
     */
    public static function strictEquals<T>(a:T, b:T):Bool {
        return a == b;
    }

}

class TransactionImpl implements ITransaction {

    var updatingObservers:Null<Array<IObserver>> = [];
    var updatingObservables:Null<Array<IObservableBase>> = [];

    public function new() {}

    public function updateObserver(observer:IObserver, observable:IObservableBase):Void {
        // When this gets called while finish is active, they will still get considered
        this.updatingObservers.push(observer);
        this.updatingObservables.push(observable);
        observer.beginUpdate(observable);
    }

    public function finish():Void {
        final updatingObservers = this.updatingObservers;
        final updatingObservables = this.updatingObservables;
        var i = 0;
        while (i < updatingObservers.length) {
            updatingObservers[i].endUpdate(updatingObservables[i]);
            i++;
        }
        // Prevent anyone from updating observers from now on.
        this.updatingObservers = null;
        this.updatingObservables = null;
    }

}

class ObservableValue<T> extends BaseObservable<T> implements ISettableObservable<T> {

    var _value:T;
    final _debugName:String;
    final _equalityComparator:EqualityComparer<T>;

    override function get_debugName():String {
        return _debugName;
    }

    public function new(debugName:String, initialValue:T, equalityComparator:EqualityComparer<T>) {
        super();
        this._debugName = debugName;
        this._value = initialValue;
        this._equalityComparator = equalityComparator;
    }

    override public function get():T {
        return this._value;
    }

    public function set(value:T, tx:Null<ITransaction>, ?change:Any):Void {
        if (change == null && this._equalityComparator(this._value, value)) {
            return;
        }

        var _tx:Null<TransactionImpl> = null;
        if (tx == null) {
            tx = _tx = new TransactionImpl();
        }
        var error:Null<haxe.Exception> = null;
        try {
            this._setValue(value);
            var i = 0;
            while (i < this.observers.length) {
                final observer = this.observers[i];
                tx.updateObserver(observer, this);
                observer.handleChange(this, change);
                i++;
            }
        }
        catch (e:haxe.Exception) {
            error = e;
        }
        if (_tx != null) {
            _tx.finish();
        }
        if (error != null) {
            throw error;
        }
    }

    function _setValue(newValue:T):Void {
        this._value = newValue;
    }

    public function toString():String {
        return this.debugName + ': ' + Std.string(this._value);
    }

}

/**
 * A disposable observable. When disposed, its value is also disposed.
 * When a new value is set, the previous value is disposed.
 */
class DisposableObservableValue<T:IDisposable> extends ObservableValue<Null<T>> implements IDisposable {

    override function _setValue(newValue:Null<T>):Void {
        if (this._value == newValue) {
            return;
        }
        if (this._value != null) {
            this._value.dispose();
        }
        this._value = newValue;
    }

    public function dispose():Void {
        if (this._value != null) {
            this._value.dispose();
        }
    }

}
