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
 * Module functions of lifecycle.ts. Only what the frozen interfaces need so
 * far; the rest (`DisposableStore`, `Disposable`, `combinedDisposable`...)
 * comes with the first module that uses it.
 */
class Lifecycle {

    /**
     * Turns a function that cleans up into an `IDisposable`.
     */
    public static function toDisposable(fn:() -> Void):IDisposable {
        return new FunctionDisposable(fn);
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
