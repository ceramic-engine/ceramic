// Ported from vscode src/vs/base/common/observableInternal/derived.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common.observableInternal;

import cityscape.base.common.Lifecycle;
import cityscape.base.common.observableInternal.Base;

/**
 * Module functions of derived.ts. The debug names of Monaco
 * (`DebugNameData`, the owner) are reduced to an optional name.
 */
class Derived {

    /**
     * Creates an observable that is derived from other observables.
     * The value is only recomputed when absolutely needed.
     */
    public static function derived<T>(computeFn:(reader:IReader) -> T, ?debugName:String):IObservable<T> {
        return new DerivedObservable<T, Any>(debugName, (reader, _) -> computeFn(reader), null, null, null, Base.strictEquals);
    }

    /**
     * Monaco's `derivedOpts` (`equalsFn`, `onLastObserverRemoved`).
     */
    public static function derivedOpts<T>(options:{?debugName:String, ?equalsFn:EqualityComparer<T>, ?onLastObserverRemoved:() -> Void}, computeFn:(reader:IReader) -> T):IObservable<T> {
        return new DerivedObservable<T, Any>(
            options.debugName,
            (reader, _) -> computeFn(reader),
            null,
            null,
            options.onLastObserverRemoved,
            options.equalsFn != null ? options.equalsFn : Base.strictEquals
        );
    }

    /**
     * Represents an observable that is derived from other observables.
     * The value is only recomputed when absolutely needed.
     *
     * Use `createEmptyChangeSummary` to create a "change summary" that can collect the changes.
     * Use `handleChange` to add a reported change to the change summary.
     * The compute function is given the last change summary.
     * The change summary is discarded after the compute function was called.
     */
    public static function derivedHandleChanges<T, TChangeSummary>(
        options:{
            ?debugName:String,
            createEmptyChangeSummary:() -> TChangeSummary,
            handleChange:(context:IChangeContext, changeSummary:TChangeSummary) -> Bool,
            ?equalityComparer:EqualityComparer<T>
        },
        computeFn:(reader:IReader, changeSummary:TChangeSummary) -> T
    ):IObservable<T> {
        return new DerivedObservable<T, TChangeSummary>(
            options.debugName,
            computeFn,
            options.createEmptyChangeSummary,
            options.handleChange,
            null,
            options.equalityComparer != null ? options.equalityComparer : Base.strictEquals
        );
    }

    /**
     * A derived whose value is disposed when it is recomputed or when the
     * derived is no longer observed.
     */
    public static function derivedDisposable<T:IDisposable>(computeFn:(reader:IReader) -> Null<T>, ?debugName:String):IObservable<Null<T>> {
        var store:Null<DisposableStore> = null;
        return new DerivedObservable<Null<T>, Any>(
            debugName,
            (r, _) -> {
                if (store == null) {
                    store = new DisposableStore();
                }
                else {
                    store.clear();
                }
                final result = computeFn(r);
                if (result != null) {
                    store.add(result);
                }
                return result;
            },
            null,
            null,
            () -> {
                if (store != null) {
                    store.dispose();
                    store = null;
                }
            },
            Base.strictEquals
        );
    }

}

enum abstract DerivedState(Int) {
    /** Initial state, no previous value, recomputation needed */
    var initial = 0;

    /**
     * A dependency could have changed.
     * We need to explicitly ask them if at least one dependency changed.
     */
    var dependenciesMightHaveChanged = 1;

    /**
     * A dependency changed and we need to recompute.
     * After recomputation, we need to check the previous value to see if we changed as well.
     */
    var stale = 2;

    /**
     * No change reported, our cached value is up to date.
     */
    var upToDate = 3;
}

/**
 * Monaco's `Derived` class (named `DerivedObservable` here: the module
 * functions of derived.ts take the name `Derived`). Its sets of
 * dependencies are arrays in insertion order.
 */
class DerivedObservable<T, TChangeSummary> extends BaseObservable<T> implements IReader implements IObserver {

    var state:DerivedState = DerivedState.initial;
    var value:Null<T> = null;
    var updateCount:Int = 0;
    var dependencies:Array<IObservableBase> = [];
    var dependenciesToBeRemoved:Array<IObservableBase> = [];
    var changeSummary:Null<TChangeSummary> = null;
    final changeContext = new ChangeContext();

    final _debugName:Null<String>;
    public final _computeFn:(reader:IReader, changeSummary:TChangeSummary) -> T;
    final createChangeSummary:Null<() -> TChangeSummary>;
    final _handleChange:Null<(context:IChangeContext, summary:TChangeSummary) -> Bool>;
    final _handleLastObserverRemoved:Null<() -> Void>;
    final _equalityComparator:EqualityComparer<T>;

    override function get_debugName():String {
        return _debugName != null ? _debugName : '(anonymous)';
    }

    public function new(
        debugName:Null<String>,
        computeFn:(reader:IReader, changeSummary:TChangeSummary) -> T,
        createChangeSummary:Null<() -> TChangeSummary>,
        handleChange:Null<(context:IChangeContext, summary:TChangeSummary) -> Bool>,
        handleLastObserverRemoved:Null<() -> Void>,
        equalityComparator:EqualityComparer<T>
    ) {
        super();
        this._debugName = debugName;
        this._computeFn = computeFn;
        this.createChangeSummary = createChangeSummary;
        this._handleChange = handleChange;
        this._handleLastObserverRemoved = handleLastObserverRemoved;
        this._equalityComparator = equalityComparator;
        this.changeSummary = createChangeSummary != null ? createChangeSummary() : null;
    }

    override function onLastObserverRemoved():Void {
        /**
         * We are not tracking changes anymore, thus we have to assume
         * that our cache is invalid.
         */
        this.state = DerivedState.initial;
        this.value = null;
        for (d in this.dependencies) {
            d.removeObserver(this);
        }
        this.dependencies.resize(0);

        if (this._handleLastObserverRemoved != null) {
            this._handleLastObserverRemoved();
        }
    }

    override public function get():T {
        if (this.observers.length == 0) {
            // Without observers, we don't know when to clean up stuff.
            // Thus, we don't cache anything to prevent memory leaks.
            final result = this._computeFn(this, this.createChangeSummary != null ? this.createChangeSummary() : null);
            // Clear new dependencies
            this.onLastObserverRemoved();
            return result;
        }
        else {
            do {
                // We might not get a notification for a dependency that changed while it is updating,
                // thus we also have to ask all our depedencies if they changed in this case.
                if (this.state == DerivedState.dependenciesMightHaveChanged) {
                    var i = 0;
                    while (i < this.dependencies.length) {
                        /** might call `handleChange` indirectly, which could make us stale */
                        this.dependencies[i].reportChanges();

                        if (this.state == DerivedState.stale) {
                            // The other dependencies will refresh on demand, so early break
                            break;
                        }
                        i++;
                    }
                }

                // We called report changes of all dependencies.
                // If we are still not stale, we can assume to be up to date again.
                if (this.state == DerivedState.dependenciesMightHaveChanged) {
                    this.state = DerivedState.upToDate;
                }

                this._recomputeIfNeeded();
                // In case recomputation changed one of our dependencies, we need to recompute again.
            } while (this.state != DerivedState.upToDate);
            return this.value;
        }
    }

    function _recomputeIfNeeded():Void {
        if (this.state == DerivedState.upToDate) {
            return;
        }
        final emptySet = this.dependenciesToBeRemoved;
        this.dependenciesToBeRemoved = this.dependencies;
        this.dependencies = emptySet;

        final hadValue = this.state != DerivedState.initial;
        final oldValue = this.value;
        this.state = DerivedState.upToDate;

        final changeSummary = this.changeSummary;
        this.changeSummary = this.createChangeSummary != null ? this.createChangeSummary() : null;
        var error:Null<haxe.Exception> = null;
        try {
            /** might call `handleChange` indirectly, which could invalidate us */
            this.value = this._computeFn(this, changeSummary);
        }
        catch (e:haxe.Exception) {
            error = e;
        }
        // We don't want our observed observables to think that they are (not even temporarily) not being observed.
        // Thus, we only unsubscribe from observables that are definitely not read anymore.
        for (o in this.dependenciesToBeRemoved) {
            o.removeObserver(this);
        }
        this.dependenciesToBeRemoved.resize(0);
        if (error != null) {
            throw error;
        }

        final didChange = hadValue && !(this._equalityComparator(oldValue, this.value));

        if (didChange) {
            var i = 0;
            while (i < this.observers.length) {
                this.observers[i].handleChange(this, null);
                i++;
            }
        }
    }

    public function toString():String {
        return 'LazyDerived<' + this.debugName + '>';
    }

    // IObserver Implementation
    public function beginUpdate(_observable:IObservableBase):Void {
        this.updateCount++;
        final propagateBeginUpdate = this.updateCount == 1;
        if (this.state == DerivedState.upToDate) {
            this.state = DerivedState.dependenciesMightHaveChanged;
            // If we propagate begin update, that will already signal a possible change.
            if (!propagateBeginUpdate) {
                var i = 0;
                while (i < this.observers.length) {
                    this.observers[i].handlePossibleChange(this);
                    i++;
                }
            }
        }
        if (propagateBeginUpdate) {
            var i = 0;
            while (i < this.observers.length) {
                this.observers[i].beginUpdate(this); // This signals a possible change
                i++;
            }
        }
    }

    public function endUpdate(_observable:IObservableBase):Void {
        this.updateCount--;
        if (this.updateCount == 0) {
            // End update could change the observer list.
            final observers = this.observers.copy();
            for (r in observers) {
                r.endUpdate(this);
            }
        }
    }

    public function handlePossibleChange(observable:IObservableBase):Void {
        // In all other states, observers already know that we might have changed.
        if (this.state == DerivedState.upToDate && this.dependencies.indexOf(observable) != -1 && this.dependenciesToBeRemoved.indexOf(observable) == -1) {
            this.state = DerivedState.dependenciesMightHaveChanged;
            var i = 0;
            while (i < this.observers.length) {
                this.observers[i].handlePossibleChange(this);
                i++;
            }
        }
    }

    public function handleChange(observable:IObservableBase, change:Any):Void {
        if (this.dependencies.indexOf(observable) != -1 && this.dependenciesToBeRemoved.indexOf(observable) == -1) {
            final shouldReact = this._handleChange != null ? this._handleChange(this.changeContext.reset(observable, change), this.changeSummary) : true;
            final wasUpToDate = this.state == DerivedState.upToDate;
            if (shouldReact && (this.state == DerivedState.dependenciesMightHaveChanged || wasUpToDate)) {
                this.state = DerivedState.stale;
                if (wasUpToDate) {
                    var i = 0;
                    while (i < this.observers.length) {
                        this.observers[i].handlePossibleChange(this);
                        i++;
                    }
                }
            }
        }
    }

    // IReader Implementation
    public function readObservable<V>(observable:IObservable<V>):V {
        // Subscribe before getting the value to enable caching
        observable.addObserver(this);
        /** This might call `handleChange` indirectly, which could invalidate us */
        final value = observable.get();
        // Which is why we only add the observable to the dependencies now.
        if (this.dependencies.indexOf(observable) == -1) {
            this.dependencies.push(observable);
        }
        this.dependenciesToBeRemoved.remove(observable);
        return value;
    }

    override public function addObserver(observer:IObserver):Void {
        final shouldCallBeginUpdate = !this.hasObserver(observer) && this.updateCount > 0;
        super.addObserver(observer);

        if (shouldCallBeginUpdate) {
            observer.beginUpdate(this);
        }
    }

    override public function removeObserver(observer:IObserver):Void {
        final shouldCallEndUpdate = this.hasObserver(observer) && this.updateCount > 0;
        super.removeObserver(observer);

        if (shouldCallEndUpdate) {
            // Calling end update after removing the observer makes sure endUpdate cannot be called twice here.
            observer.endUpdate(this);
        }
    }

}
