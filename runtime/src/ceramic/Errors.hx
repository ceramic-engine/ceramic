package ceramic;

import ceramic.Shortcuts.*;
import haxe.CallStack;
import haxe.CallStack.StackItem;

// Some snippets from https://github.com/larsiusprime/crashdumper/blob/24e28e8fd664de922bd480502efe596665d905b8/crashdumper/CrashDumper.hx

/**
 * Global error handling utilities for the Ceramic engine.
 * 
 * This class provides centralized error handling for uncaught exceptions,
 * ensuring proper error reporting, stack trace capture, and graceful
 * application shutdown when critical errors occur.
 * 
 * ## Features
 * 
 * - **Stack Trace Capture**: Automatically captures and formats stack traces
 * - **Custom Error Handlers**: Apps can listen for critical errors
 * - **Cross-platform Output**: Adapts output method to platform capabilities
 * - **Graceful Shutdown**: Exits cleanly on system targets
 * 
 * ## Error Flow
 * 
 * 1. Uncaught exception occurs
 * 2. Stack trace is captured and reversed
 * 3. App's criticalError event is emitted
 * 4. Stack trace and error are printed
 * 5. Application exits (if no custom handler)
 * 
 * ## Usage Example
 * 
 * ```haxe
 * // Listen for critical errors in your app
 * app.onCriticalError(this, (error, stack) -> {
 *     // Log to crash reporting service
 *     crashReporter.logError(error, stack);
 *     
 *     // Show user-friendly error dialog
 *     showErrorDialog("An error occurred: " + error);
 * });
 * ```
 * 
 * @see ceramic.App#onCriticalError For handling errors in your app
 * @see ceramic.Utils#stackItemToString For stack trace formatting
 */
class Errors {

/// Uncaught errors

    /**
     * Handles uncaught errors by capturing stack traces and notifying the app.
     * 
     * This method is called internally by the engine when an uncaught exception
     * occurs. It performs the following steps:
     * 
     * 1. Checks if app has custom error handlers
     * 2. Captures and reverses the exception stack trace (see `uncaughtErrorStack()`)
     * 3. Emits criticalError event on the app
     * 4. Prints formatted stack trace to console/output
     * 5. Exits application if no custom handler exists
     * 
     * @param e The uncaught error/exception object
     */
    static function handleUncaughtError(e:Dynamic):Void {

        /**
         * Platform-specific print function for error output.
         * Uses the most appropriate output method for each target.
         */
        inline function print(data:Dynamic) {
            #if sys
            Sys.println(''+data);
            #elseif js
            js.Syntax.code('console.log({0})', ''+data);
            #else
            trace(data);
            #end
        }

        // Check if we have custom handler
        var hasCustomHandler = app.listensCriticalError();

        // Get stack trace
        var stack = uncaughtErrorStack(e);

        // Reverse stack
        var reverseStack = [].concat(stack);
        reverseStack.reverse();

        // Emit critical error event
        @:privateAccess app.emitCriticalError(e, reverseStack);

        // Print stack trace and error
        for (item in reverseStack) {
            print(Utils.stackItemToString(item));
        }
        print('[error] ' + e);

#if sys
        if (!hasCustomHandler) Sys.exit(1);
#end

    }

    /**
     * The stack of an uncaught error, innermost call first.
     *
     * The global `CallStack.exceptionStack()` only goes back to the last
     * `throw`: when the error was caught then thrown again with a plain
     * `throw e`, it starts at that rethrow site and the frames where the
     * error really happened are lost. A `haxe.Exception` keeps them in its
     * own `stack` (recorded when it was created, or when it was first caught
     * for a wrapped value), so it is preferred when available:
     *
     * - when both stacks start with the same frames (nothing rethrown, or
     *   rethrown with `cpp.Lib.rethrow`), the global stack is right and is
     *   used, as before;
     * - when the exception's stack already covers the frame where the global
     *   stack starts (an exception created before being thrown records the
     *   whole call stack), the exception's stack is used;
     * - otherwise (a caught value rethrown with `throw e`) the exception's
     *   stack, from the original throw to its first catch, is followed by
     *   the global stack, from the rethrow site to here.
     *
     * @param e The uncaught error/exception object
     * @return The stack items, innermost call first
     */
    static function uncaughtErrorStack(e:Dynamic):Array<StackItem> {

        var global:Array<StackItem> = CallStack.exceptionStack();
        if (global == null) global = [];

        final exception:Null<haxe.Exception> = Std.downcast(e, haxe.Exception);
        if (exception == null) {
            return global;
        }

        var own:Array<StackItem> = null;
        try {
            final stack:CallStack = exception.stack;
            own = cast stack; // CallStack is an abstract over Array<StackItem>
        }
        catch (_:Dynamic) {}
        if (own == null || own.length == 0) {
            return global;
        }
        if (global.length == 0) {
            return [].concat(own);
        }

        // Both stacks start with the same frames: nothing was rethrown with
        // a plain `throw`, the global stack is right
        var same = true;
        for (i in 0...(own.length < global.length ? own.length : global.length)) {
            if (stackItemKey(own[i], true) != stackItemKey(global[i], true)) {
                same = false;
                break;
            }
        }
        if (same) {
            return global;
        }

        // Exception's stack that already holds the frame where the global one starts
        var first = stackItemKey(global[0], false);
        for (item in own) {
            if (stackItemKey(item, false) == first) {
                return [].concat(own);
            }
        }

        return own.concat(global);

    }

    /**
     * A comparable key of a stack item (the function and file, with the line
     * when `withLine` is true).
     */
    static function stackItemKey(item:StackItem, withLine:Bool):String {

        return switch item {
            case null: 'null';
            case CFunction: 'cfunction';
            case Module(m): 'module ' + m;
            case FilePos(s, file, line, column):
                stackItemKey(s, false) + ' ' + file + (withLine ? ':' + line : '');
            case Method(className, method): className + '.' + method;
            case LocalFunction(v): 'local ' + v;
        }

    }

}
