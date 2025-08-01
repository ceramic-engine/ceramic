package ceramic;

import ceramic.Shortcuts.*;
import haxe.CallStack;

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
     * 2. Captures and reverses the exception stack trace
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
        var stack = CallStack.exceptionStack();

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

}
