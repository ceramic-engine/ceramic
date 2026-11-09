// New code for Cityscape (not a port): a small promise for the ported code
// that awaits language feature providers (Monaco's `async` functions and
// `Promise.all`).
package cityscape.base.common;

/**
 * The error a cancelled operation rejects with (Monaco's `CancellationError`).
 */
class CancellationError extends haxe.Exception {

    public function new() {
        super('Canceled');
    }

    /**
     * Monaco's `isCancellationError`.
     */
    public static function isCancellationError(error:Any):Bool {
        return Std.isOfType(error, CancellationError);
    }

}

private enum abstract PromiseState(Int) {
    var Pending = 0;
    var Resolved = 1;
    var Rejected = 2;
}

/**
 * A promise settled once with a value or an error, for the ported code that
 * awaits providers. Unlike JavaScript's promises, the reactions run
 * synchronously: a reaction added to a settled promise runs at once, and
 * settling a promise runs its reactions before `resolve` returns. Providers
 * answer through callbacks (`Promise.fromCallback`); a provider that
 * answers at once gives a result at once, which keeps tests and keystrokes
 * free of extra frames.
 */
class Promise<T> {

    var state:PromiseState = Pending;
    var value:Null<T> = null;
    var error:Any = null;
    var reactions:Null<Array<() -> Void>> = null;

    /**
     * `executor` gets the functions settling the promise (the first call
     * wins). An exception thrown by the executor rejects the promise.
     */
    public function new(executor:(resolve:(value:Null<T>) -> Void, reject:(error:Any) -> Void) -> Void) {
        try {
            executor(_resolve, _reject);
        }
        catch (e:Any) {
            _reject(e);
        }
    }

    /**
     * A promise resolved with `value`.
     */
    public static function resolve<T>(?value:T):Promise<T> {
        final p = new Promise<T>(null_executor);
        p._resolve(value);
        return p;
    }

    /**
     * A promise rejected with `error`.
     */
    public static function reject<T>(error:Any):Promise<T> {
        final p = new Promise<T>(null_executor);
        p._reject(error);
        return p;
    }

    static function null_executor<T>(resolve:(value:Null<T>) -> Void, reject:(error:Any) -> Void):Void {}

    /**
     * A promise settled by a callback style function: `fn` gets the function
     * to call with the result (once).
     */
    public static function fromCallback<T>(fn:(done:(value:Null<T>) -> Void) -> Void):Promise<T> {
        return new Promise<T>((resolve, reject) -> fn(resolve));
    }

    /**
     * Resolves with the values of all the promises, in order, once all are
     * resolved; rejects with the first error (JavaScript's `Promise.all`).
     */
    public static function all<T>(promises:Array<Promise<T>>):Promise<Array<Null<T>>> {
        return new Promise<Array<Null<T>>>((resolve, reject) -> {
            final count = promises.length;
            final results:Array<Null<T>> = [for (_ in 0...count) null];
            if (count == 0) {
                resolve(results);
                return;
            }
            var remaining = count;
            var failed = false;
            for (i in 0...count) {
                final index = i;
                promises[i].then(v -> {
                    results[index] = v;
                    remaining--;
                    if (remaining == 0 && !failed) {
                        resolve(results);
                    }
                    return null;
                }, e -> {
                    if (!failed) {
                        failed = true;
                        reject(e);
                    }
                    return null;
                });
            }
        });
    }

    /**
     * Resolves once all the promises are settled, with nothing (the values
     * are read from the promises by the caller); JavaScript's
     * `Promise.allSettled` without the result array.
     */
    public static function allSettled<T>(promises:Array<Promise<T>>):Promise<Any> {
        return new Promise<Any>((resolve, reject) -> {
            var remaining = promises.length;
            if (remaining == 0) {
                resolve(null);
                return;
            }
            for (p in promises) {
                p.finally(() -> {
                    remaining--;
                    if (remaining == 0) {
                        resolve(null);
                    }
                });
            }
        });
    }

    public var isSettled(get, never):Bool;
    inline function get_isSettled():Bool {
        return state != Pending;
    }

    public var isResolved(get, never):Bool;
    inline function get_isResolved():Bool {
        return state == Resolved;
    }

    public var isRejected(get, never):Bool;
    inline function get_isRejected():Bool {
        return state == Rejected;
    }

    /**
     * The value of a resolved promise (null otherwise).
     */
    public function getValue():Null<T> {
        return value;
    }

    /**
     * The error of a rejected promise (null otherwise).
     */
    public function getError():Any {
        return error;
    }

    function _resolve(v:Null<T>):Void {
        if (state != Pending) {
            return;
        }
        value = v;
        state = Resolved;
        _flush();
    }

    function _reject(e:Any):Void {
        if (state != Pending) {
            return;
        }
        error = e;
        state = Rejected;
        _flush();
    }

    function _flush():Void {
        final list = reactions;
        reactions = null;
        if (list != null) {
            for (r in list) {
                r();
            }
        }
    }

    function _react(reaction:() -> Void):Void {
        if (state != Pending) {
            reaction();
        }
        else {
            if (reactions == null) {
                reactions = [];
            }
            reactions.push(reaction);
        }
    }

    /**
     * The promise of what `onResolve` returns (or of what `onReject`
     * returns for an error; without `onReject` the error goes on).
     */
    public function then<U>(onResolve:(value:Null<T>) -> Null<U>, ?onReject:(error:Any) -> Null<U>):Promise<U> {
        return new Promise<U>((resolve, reject) -> {
            _react(() -> {
                if (state == Resolved) {
                    try {
                        resolve(onResolve(value));
                    }
                    catch (e:Any) {
                        reject(e);
                    }
                }
                else if (onReject != null) {
                    try {
                        resolve(onReject(error));
                    }
                    catch (e:Any) {
                        reject(e);
                    }
                }
                else {
                    reject(error);
                }
            });
        });
    }

    /**
     * The promise of the promise `onResolve` returns (JavaScript's `then`
     * with a promise returned).
     */
    public function thenPromise<U>(onResolve:(value:Null<T>) -> Promise<U>, ?onReject:(error:Any) -> Promise<U>):Promise<U> {
        return new Promise<U>((resolve, reject) -> {
            _react(() -> {
                var next:Null<Promise<U>> = null;
                try {
                    if (state == Resolved) {
                        next = onResolve(value);
                    }
                    else if (onReject != null) {
                        next = onReject(error);
                    }
                    else {
                        reject(error);
                        return;
                    }
                }
                catch (e:Any) {
                    reject(e);
                    return;
                }
                if (next == null) {
                    resolve(null);
                }
                else {
                    next._react(() -> {
                        if (next.state == Resolved) {
                            resolve(next.value);
                        }
                        else {
                            reject(next.error);
                        }
                    });
                }
            });
        });
    }

    /**
     * Handles an error (JavaScript's `catch`).
     */
    public function catchError(onReject:(error:Any) -> Null<T>):Promise<T> {
        return then(v -> v, onReject);
    }

    /**
     * Runs `fn` once settled; the promise returned settles like this one.
     */
    public function finally(fn:() -> Void):Promise<T> {
        return new Promise<T>((resolve, reject) -> {
            _react(() -> {
                fn();
                if (state == Resolved) {
                    resolve(value);
                }
                else {
                    reject(error);
                }
            });
        });
    }

    /**
     * Calls `fn` with the value once resolved (nothing on error): the
     * callback style end of a chain.
     */
    public function done(fn:(value:Null<T>) -> Void, ?onError:(error:Any) -> Void):Void {
        _react(() -> {
            if (state == Resolved) {
                fn(value);
            }
            else if (onError != null) {
                onError(error);
            }
        });
    }

}
