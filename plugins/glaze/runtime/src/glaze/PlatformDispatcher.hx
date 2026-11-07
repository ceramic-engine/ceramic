// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Schedules work for the executors. Everything runs on the main thread
 * (Ceramic is single threaded from the point of view of GPUI code).
 *
 * Implementations: `CeramicDispatcher` (default, backed by `app.onceImmediate`
 * and `ceramic.Timer`) and `TestDispatcher` (manual clock for tests).
 */
interface PlatformDispatcher {

    /**
     * Runs `runnable` soon, on the main thread, outside of the current call stack.
     */
    function dispatch(runnable:() -> Void):Void;

    /**
     * Runs `runnable` after the given delay in seconds.
     * Returns a function that cancels it.
     */
    function dispatchAfter(seconds:Float, runnable:() -> Void):() -> Void;

    /**
     * Current time in seconds. Only differences between two values are meaningful.
     */
    function now():Float;

}
