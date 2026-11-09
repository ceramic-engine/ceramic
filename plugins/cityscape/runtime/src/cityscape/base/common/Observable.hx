// Ported from vscode src/vs/base/common/observable.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import cityscape.base.common.Lifecycle;
import cityscape.base.common.observableInternal.Autorun;
import cityscape.base.common.observableInternal.Base;
import cityscape.base.common.observableInternal.Derived;
import cityscape.base.common.observableInternal.Utils;

/**
 * Monaco's observables (observable.ts, which re-exports
 * observableInternal): the subset the inline completions use. Import the
 * types from `cityscape.base.common.observableInternal.Base`
 * (`IObservable`, `IReader`, `ITransaction`, `ISettableObservable`) and call
 * the functions here: `Observable.derived(reader -> ...)`,
 * `Observable.autorun(reader -> ...)`, `Observable.transaction(tx -> ...)`.
 *
 * Not ported: the logger, the debug names of owners and functions
 * (`DebugNameData`), lazy observable values, the observables of promises,
 * `waitForState`, `mapObservableArrayCached` and the other helpers of
 * utils.ts not listed here.
 */
class Observable {

    public static inline function observableValue<T>(debugName:String, initialValue:T):ISettableObservable<T> {
        return Base.observableValue(debugName, initialValue);
    }

    public static inline function observableValueOpts<T>(debugName:String, equalsFn:EqualityComparer<T>, initialValue:T):ISettableObservable<T> {
        return Base.observableValueOpts(debugName, equalsFn, initialValue);
    }

    public static inline function disposableObservableValue<T:IDisposable>(debugName:String, initialValue:Null<T>):DisposableObservableValue<T> {
        return Base.disposableObservableValue(debugName, initialValue);
    }

    public static inline function transaction(fn:(tx:ITransaction) -> Void):Void {
        Base.transaction(fn);
    }

    public static inline function subtransaction(tx:Null<ITransaction>, fn:(tx:ITransaction) -> Void):Void {
        Base.subtransaction(tx, fn);
    }

    public static inline function derived<T>(computeFn:(reader:IReader) -> T, ?debugName:String):IObservable<T> {
        return Derived.derived(computeFn, debugName);
    }

    public static inline function derivedOpts<T>(options:{?debugName:String, ?equalsFn:EqualityComparer<T>, ?onLastObserverRemoved:() -> Void}, computeFn:(reader:IReader) -> T):IObservable<T> {
        return Derived.derivedOpts(options, computeFn);
    }

    public static inline function derivedHandleChanges<T, TChangeSummary>(
        options:{
            ?debugName:String,
            createEmptyChangeSummary:() -> TChangeSummary,
            handleChange:(context:IChangeContext, changeSummary:TChangeSummary) -> Bool,
            ?equalityComparer:EqualityComparer<T>
        },
        computeFn:(reader:IReader, changeSummary:TChangeSummary) -> T
    ):IObservable<T> {
        return Derived.derivedHandleChanges(options, computeFn);
    }

    public static inline function derivedDisposable<T:IDisposable>(computeFn:(reader:IReader) -> Null<T>, ?debugName:String):IObservable<Null<T>> {
        return Derived.derivedDisposable(computeFn, debugName);
    }

    public static inline function autorun(fn:(reader:IReader) -> Void):IDisposable {
        return Autorun.autorun(fn);
    }

    public static inline function autorunHandleChanges<TChangeSummary>(
        options:{
            ?createEmptyChangeSummary:() -> TChangeSummary,
            handleChange:(context:IChangeContext, changeSummary:TChangeSummary) -> Bool
        },
        fn:(reader:IReader, changeSummary:TChangeSummary) -> Void
    ):IDisposable {
        return Autorun.autorunHandleChanges(options, fn);
    }

    public static inline function autorunWithStore(fn:(reader:IReader, store:DisposableStore) -> Void):IDisposable {
        return Autorun.autorunWithStore(fn);
    }

    public static inline function constObservable<T>(value:T):IObservable<T> {
        return Utils.constObservable(value);
    }

    public static inline function observableFromEvent<T>(subscribe:(handler:() -> Void) -> IDisposable, getValue:() -> T, ?equalsFn:EqualityComparer<T>):IObservable<T> {
        return Utils.observableFromEvent(subscribe, getValue, equalsFn);
    }

    public static inline function observableSignal(debugName:String):ObservableSignal {
        return Utils.observableSignal(debugName);
    }

    public static inline function observableSignalFromEvent(debugName:String, subscribe:(handler:() -> Void) -> IDisposable):IObservable<Any> {
        return Utils.observableSignalFromEvent(debugName, subscribe);
    }

    public static inline function keepObserved<T>(observable:IObservable<T>):IDisposable {
        return Utils.keepObserved(observable);
    }

    public static inline function recomputeInitiallyAndOnChange<T>(observable:IObservable<T>, ?handleValue:(value:T) -> Void):IDisposable {
        return Utils.recomputeInitiallyAndOnChange(observable, handleValue);
    }

    public static inline function derivedObservableWithCache<T>(computeFn:(reader:IReader, lastValue:Null<T>) -> T):IObservable<T> {
        return Utils.derivedObservableWithCache(computeFn);
    }

}
