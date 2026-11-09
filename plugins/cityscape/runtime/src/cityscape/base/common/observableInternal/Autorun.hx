// Ported from vscode src/vs/base/common/observableInternal/autorun.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common.observableInternal;

import cityscape.base.common.Lifecycle;
import cityscape.base.common.observableInternal.Base;

/**
 * Module functions of autorun.ts.
 */
class Autorun {

    /**
     * Runs immediately and whenever a transaction ends and an observed observable changed.
     */
    public static function autorun(fn:(reader:IReader) -> Void):IDisposable {
        return new AutorunObserver<Any>((reader, _) -> fn(reader), null, null);
    }

    /**
     * Runs immediately and whenever a transaction ends and an observed observable changed.
     *
     * Use `createEmptyChangeSummary` to create a "change summary" that can collect the changes.
     * Use `handleChange` to add a reported change to the change summary.
     * The run function is given the last change summary.
     * The change summary is discarded after the run function was called.
     */
    public static function autorunHandleChanges<TChangeSummary>(
        options:{
            ?createEmptyChangeSummary:() -> TChangeSummary,
            handleChange:(context:IChangeContext, changeSummary:TChangeSummary) -> Bool
        },
        fn:(reader:IReader, changeSummary:TChangeSummary) -> Void
    ):IDisposable {
        return new AutorunObserver<TChangeSummary>(fn, options.createEmptyChangeSummary, options.handleChange);
    }

    /**
     * `autorun` with a disposable store that is cleared before the next run or on dispose.
     */
    public static function autorunWithStore(fn:(reader:IReader, store:DisposableStore) -> Void):IDisposable {
        final store = new DisposableStore();
        final disposable = autorun(reader -> {
            store.clear();
            fn(reader, store);
        });
        return Lifecycle.toDisposable(() -> {
            disposable.dispose();
            store.dispose();
        });
    }

}

enum abstract AutorunState(Int) {
    /**
     * A dependency could have changed.
     * We need to explicitly ask them if at least one dependency changed.
     */
    var dependenciesMightHaveChanged = 1;

    /**
     * A dependency changed and we need to recompute.
     */
    var stale = 2;
    var upToDate = 3;
}

class AutorunObserver<TChangeSummary> implements IObserver implements IReader implements IDisposable {

    var state:AutorunState = AutorunState.stale;
    var updateCount:Int = 0;
    var disposed:Bool = false;
    var dependencies:Array<IObservableBase> = [];
    var dependenciesToBeRemoved:Array<IObservableBase> = [];
    var changeSummary:Null<TChangeSummary> = null;
    final changeContext = new ChangeContext();

    public final _runFn:(reader:IReader, changeSummary:TChangeSummary) -> Void;
    final createChangeSummary:Null<() -> TChangeSummary>;
    final _handleChange:Null<(context:IChangeContext, summary:TChangeSummary) -> Bool>;

    public function new(
        runFn:(reader:IReader, changeSummary:TChangeSummary) -> Void,
        createChangeSummary:Null<() -> TChangeSummary>,
        handleChange:Null<(context:IChangeContext, summary:TChangeSummary) -> Bool>
    ) {
        this._runFn = runFn;
        this.createChangeSummary = createChangeSummary;
        this._handleChange = handleChange;
        this.changeSummary = createChangeSummary != null ? createChangeSummary() : null;
        this._runIfNeeded();
    }

    public function dispose():Void {
        this.disposed = true;
        for (o in this.dependencies) {
            o.removeObserver(this);
        }
        this.dependencies.resize(0);
    }

    function _runIfNeeded():Void {
        if (this.state == AutorunState.upToDate) {
            return;
        }

        final emptySet = this.dependenciesToBeRemoved;
        this.dependenciesToBeRemoved = this.dependencies;
        this.dependencies = emptySet;

        this.state = AutorunState.upToDate;

        final isDisposed = this.disposed;
        var error:Null<haxe.Exception> = null;
        try {
            if (!isDisposed) {
                final changeSummary = this.changeSummary;
                this.changeSummary = this.createChangeSummary != null ? this.createChangeSummary() : null;
                this._runFn(this, changeSummary);
            }
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
    }

    public function toString():String {
        return 'Autorun';
    }

    // IObserver implementation
    public function beginUpdate(_observable:IObservableBase):Void {
        if (this.state == AutorunState.upToDate) {
            this.state = AutorunState.dependenciesMightHaveChanged;
        }
        this.updateCount++;
    }

    public function endUpdate(_observable:IObservableBase):Void {
        if (this.updateCount == 1) {
            do {
                if (this.state == AutorunState.dependenciesMightHaveChanged) {
                    this.state = AutorunState.upToDate;
                    var i = 0;
                    while (i < this.dependencies.length) {
                        this.dependencies[i].reportChanges();
                        if (this.state == AutorunState.stale) {
                            // The other dependencies will refresh on demand
                            break;
                        }
                        i++;
                    }
                }

                this._runIfNeeded();
            } while (this.state != AutorunState.upToDate);
        }
        this.updateCount--;
    }

    public function handlePossibleChange(observable:IObservableBase):Void {
        if (this.state == AutorunState.upToDate && this.dependencies.indexOf(observable) != -1 && this.dependenciesToBeRemoved.indexOf(observable) == -1) {
            this.state = AutorunState.dependenciesMightHaveChanged;
        }
    }

    public function handleChange(observable:IObservableBase, change:Any):Void {
        if (this.dependencies.indexOf(observable) != -1 && this.dependenciesToBeRemoved.indexOf(observable) == -1) {
            final shouldReact = this._handleChange != null ? this._handleChange(this.changeContext.reset(observable, change), this.changeSummary) : true;
            if (shouldReact) {
                this.state = AutorunState.stale;
            }
        }
    }

    // IReader implementation
    public function readObservable<T>(observable:IObservable<T>):T {
        // In case the run action disposes the autorun
        if (this.disposed) {
            return observable.get();
        }

        observable.addObserver(this);
        final value = observable.get();
        if (this.dependencies.indexOf(observable) == -1) {
            this.dependencies.push(observable);
        }
        this.dependenciesToBeRemoved.remove(observable);
        return value;
    }

}
