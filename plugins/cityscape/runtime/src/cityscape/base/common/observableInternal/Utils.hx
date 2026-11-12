// Ported from vscode src/vs/base/common/observableInternal/utils.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common.observableInternal;

import cityscape.base.common.Lifecycle;
import cityscape.base.common.observableInternal.Base;

/**
 * Module functions of utils.ts (the part the ported code uses).
 */
class Utils {

    /**
     * Represents an efficient observable whose value never changes.
     */
    public static function constObservable<T>(value:T):IObservable<T> {
        return new ConstObservable<T>(value);
    }

    /**
     * An observable whose value is `getValue()`, read again when `event`
     * fires. Monaco passes the event arguments to `getValue`; the ported
     * code never uses them, so `subscribe` registers a listener without
     * argument (`cb -> editor.onDidChangeConfiguration(_ -> cb())`).
     */
    public static function observableFromEvent<T>(subscribe:(handler:() -> Void) -> IDisposable, getValue:() -> T, ?equalsFn:EqualityComparer<T>):IObservable<T> {
        return new FromEventObservable<T>(subscribe, getValue, equalsFn != null ? equalsFn : Base.strictEquals);
    }

    /**
     * Creates a signal that can be triggered to invalidate observers.
     * Signals don't have a value - when they are triggered they indicate a change.
     * However, signals can carry a delta that is passed to observers.
     */
    public static function observableSignal(debugName:String):ObservableSignal {
        return new ObservableSignal(debugName);
    }

    /**
     * A signal triggered when `event` fires (Monaco's `observableSignalFromEvent`).
     */
    public static function observableSignalFromEvent(debugName:String, subscribe:(handler:() -> Void) -> IDisposable):IObservable<Any> {
        return new FromEventObservableSignal(debugName, subscribe);
    }

    /**
     * This makes sure the observable is being observed and keeps its cache alive.
     */
    public static function keepObserved<T>(observable:IObservable<T>):IDisposable {
        final o = new KeepAliveObserver<T>(observable, false, null);
        observable.addObserver(o);
        return Lifecycle.toDisposable(() -> {
            observable.removeObserver(o);
        });
    }

    /**
     * This converts the given observable into an autorun.
     */
    public static function recomputeInitiallyAndOnChange<T>(observable:IObservable<T>, ?handleValue:(value:T) -> Void):IDisposable {
        final o = new KeepAliveObserver<T>(observable, true, handleValue);
        observable.addObserver(o);
        if (handleValue != null) {
            handleValue(observable.get());
        }
        else {
            observable.reportChanges();
        }

        return Lifecycle.toDisposable(() -> {
            observable.removeObserver(o);
        });
    }

    public static function derivedObservableWithCache<T>(computeFn:(reader:IReader, lastValue:Null<T>) -> T):IObservable<T> {
        // Typed `T`, not `Null<T>`: a captured `Null<T>` is read as `object` on C#
        var lastValue:T = null;
        return Derived.derived(reader -> {
            lastValue = computeFn(reader, lastValue);
            return lastValue;
        });
    }

}

private class ConstObservable<T> extends ConvenientObservable<T> {

    final value:T;

    public function new(value:T) {
        super();
        this.value = value;
    }

    override function get_debugName():String {
        return 'Const';
    }

    override public function get():T {
        return this.value;
    }

    override public function addObserver(observer:IObserver):Void {
        // NO OP
    }

    override public function removeObserver(observer:IObserver):Void {
        // NO OP
    }

}

class FromEventObservable<T> extends BaseObservable<T> {

    var value:Null<T> = null;
    var hasValue:Bool = false;
    var subscription:Null<IDisposable> = null;

    final subscribe:(handler:() -> Void) -> IDisposable;
    public final _getValue:() -> T;
    final _equalityComparator:EqualityComparer<T>;

    public function new(subscribe:(handler:() -> Void) -> IDisposable, getValue:() -> T, equalityComparator:EqualityComparer<T>) {
        super();
        this.subscribe = subscribe;
        this._getValue = getValue;
        this._equalityComparator = equalityComparator;
    }

    override function get_debugName():String {
        return 'From Event';
    }

    override function onFirstObserverAdded():Void {
        this.subscription = this.subscribe(this.handleEvent);
    }

    function handleEvent():Void {
        final newValue = this._getValue();
        final oldValue = this.value;

        final didChange = !this.hasValue || !(this._equalityComparator(oldValue, newValue));

        if (didChange) {
            this.value = newValue;

            if (this.hasValue) {
                Base.transaction(tx -> {
                    var i = 0;
                    while (i < this.observers.length) {
                        final o = this.observers[i];
                        tx.updateObserver(o, this);
                        o.handleChange(this, null);
                        i++;
                    }
                });
            }
            this.hasValue = true;
        }
    }

    override function onLastObserverRemoved():Void {
        final subscription = this.subscription;
        this.subscription = null;
        if (subscription != null) {
            subscription.dispose();
        }
        this.hasValue = false;
        this.value = null;
    }

    override public function get():T {
        if (this.subscription != null) {
            if (!this.hasValue) {
                this.handleEvent();
            }
            return this.value;
        }
        else {
            // no cache, as there are no subscribers to keep it updated
            return this._getValue();
        }
    }

}

private class FromEventObservableSignal extends BaseObservable<Any> {

    var subscription:Null<IDisposable> = null;
    final _debugName:String;
    final subscribe:(handler:() -> Void) -> IDisposable;

    public function new(debugName:String, subscribe:(handler:() -> Void) -> IDisposable) {
        super();
        this._debugName = debugName;
        this.subscribe = subscribe;
    }

    override function get_debugName():String {
        return _debugName;
    }

    override function onFirstObserverAdded():Void {
        this.subscription = this.subscribe(this.handleEvent);
    }

    function handleEvent():Void {
        Base.transaction(tx -> {
            var i = 0;
            while (i < this.observers.length) {
                final o = this.observers[i];
                tx.updateObserver(o, this);
                o.handleChange(this, null);
                i++;
            }
        });
    }

    override function onLastObserverRemoved():Void {
        final subscription = this.subscription;
        this.subscription = null;
        if (subscription != null) {
            subscription.dispose();
        }
    }

    override public function get():Any {
        // NO OP
        return null;
    }

}

/**
 * Monaco's `IObservableSignal` (an observable without value, typed `Any`
 * and always null here).
 */
class ObservableSignal extends BaseObservable<Any> {

    final _debugName:String;

    public function new(debugName:String) {
        super();
        this._debugName = debugName;
    }

    override function get_debugName():String {
        return _debugName;
    }

    public function toString():String {
        return this.debugName;
    }

    public function trigger(tx:Null<ITransaction>, ?change:Any):Void {
        if (tx == null) {
            Base.transaction(tx -> {
                this.trigger(tx, change);
            });
            return;
        }

        var i = 0;
        while (i < this.observers.length) {
            final o = this.observers[i];
            tx.updateObserver(o, this);
            o.handleChange(this, change);
            i++;
        }
    }

    override public function get():Any {
        // NO OP
        return null;
    }

}

/**
 * Monaco's `KeepAliveObserver`, given the observable it keeps alive (Monaco
 * reads it from the argument of `endUpdate`).
 */
class KeepAliveObserver<T> implements IObserver {

    var _counter:Int = 0;
    final _observable:IObservable<T>;
    final _forceRecompute:Bool;
    final _handleValue:Null<(value:T) -> Void>;

    public function new(observable:IObservable<T>, forceRecompute:Bool, handleValue:Null<(value:T) -> Void>) {
        this._observable = observable;
        this._forceRecompute = forceRecompute;
        this._handleValue = handleValue;
    }

    public function beginUpdate(observable:IObservableBase):Void {
        this._counter++;
    }

    public function endUpdate(observable:IObservableBase):Void {
        this._counter--;
        if (this._counter == 0 && this._forceRecompute) {
            if (this._handleValue != null) {
                this._handleValue(this._observable.get());
            }
            else {
                this._observable.reportChanges();
            }
        }
    }

    public function handlePossibleChange(observable:IObservableBase):Void {
        // NO OP
    }

    public function handleChange(observable:IObservableBase, change:Any):Void {
        // NO OP
    }

}
