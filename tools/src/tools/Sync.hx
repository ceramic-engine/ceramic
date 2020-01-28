package tools;

import npm.Future;

/** Helper class to run asynchronous function pseudo-synchronously using fibers. */
class Sync {

    /** Runs the given asynchronous function pseudo-synchronously using fibers.
        It will block the current fiber until the done() callback is called.

        @param    fn          The asynchronous function
        @param    simplify    If set to true, the resulting payload will only be a single value.

        @return   payload     The arguments returned by the asyncronous function callback
        */
    public static function run(fn:Dynamic->Void, simplify:Bool = false):Dynamic {

        // Initialize values
        var future = new Future();
        var sent = false;
        var payload:Dynamic = null;
        var resultError = null;

        // Create callback function
        var callback = function() {
            var args:Array<Dynamic> = untyped __js__('Array.prototype.slice.call(arguments)');
            if (!sent) {
                if (simplify) {
                    payload = args[0];
                    if (Std.is(payload, InternalError)) {
                        resultError = payload.err;
                    }
                } else {
                    payload = args;
                }
                future.ret();
            }
        }

        // Run asynchronous function
        js.Node.setImmediate(function() {
            fn(callback);
        });

        // Wait until function has finished
        future.wait();
        sent = true;

        // Throw error if any
        if (resultError != null) {
            throw resultError;
        }

        return payload;

    }

}

@:allow(tools.Sync)
private class InternalError {

    public var err(default,null):Dynamic;

    public function new(err:Dynamic) {
        this.err = err;
    }

}
