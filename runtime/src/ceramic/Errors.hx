package ceramic;

import haxe.CallStack;

import ceramic.Shortcuts.*;

// Some snippets from https://github.com/larsiusprime/crashdumper/blob/24e28e8fd664de922bd480502efe596665d905b8/crashdumper/CrashDumper.hx

class Errors {

/// Uncaught errors

    static function handleUncaughtError(e:Dynamic):Void {

        inline function print(data:Dynamic) {
            #if sys
            Sys.println(''+data);
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
