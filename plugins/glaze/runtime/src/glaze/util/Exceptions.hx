package glaze.util;

/**
 * Rethrowing a caught exception without losing where it was thrown.
 */
class Exceptions {

    /**
     * Rethrows `e`, an exception caught by the calling `catch`, keeping its
     * original frames in the exception stack of hxcpp (and the .NET stack trace on C#).
     *
     * A plain `throw e` starts a new exception stack at the rethrow site, so
     * a crash report (`ceramic.Errors`, `CallStack.exceptionStack()`) would
     * show the `catch` that cleaned up instead of the code that failed.
     * `cpp.Lib.rethrow` appends to the current exception stack instead.
     *
     * Use as `throw Exceptions.rethrow(e);`: on hxcpp and C# the call never returns,
     * on the other targets it returns `e` for the `throw`, and the `throw`
     * keyword tells the compiler that the `catch` does not fall through.
     */
    public static extern inline function rethrow<T>(e:T):T {
        #if cpp
        cpp.Lib.rethrow(e);
        #elseif cs
        // `throw;`: .NET keeps the stack trace of the original exception
        cs.Lib.rethrow(e);
        #end
        return e;
    }

}
