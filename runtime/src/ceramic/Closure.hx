package ceramic;

/**
 * A simple closure implementation for storing a function with pre-bound arguments.
 * 
 * This class provides a way to capture a function reference along with its
 * arguments, allowing for delayed execution. Useful for callbacks, event
 * handlers, and situations where you need to pass a pre-configured function.
 * 
 * ## Usage Example
 * 
 * ```haxe
 * // Store a function with arguments
 * function greet(name:String, age:Int) {
 *     trace('Hello $name, age $age');
 * }
 * 
 * var closure = new Closure(greet, ["Alice", 30]);
 * 
 * // Execute later
 * closure.call(); // Outputs: "Hello Alice, age 30"
 * 
 * // Can also store instance methods
 * var closure2 = new Closure(myObject.doSomething, [param1, param2]);
 * closure2.call();
 * ```
 * 
 * @see ceramic.Timer For delayed execution
 * @see ceramic.App#onceImmediate For deferred execution
 */
class Closure {

    /**
     * The function or method to be called.
     * Can be a static function, instance method, or any callable reference.
     */
    public var method:Any;

    /**
     * Arguments to pass to the method when called.
     * These are bound at construction time and passed during execution.
     */
    public var args:Array<Any>;

    /**
     * Creates a new closure with the specified method and arguments.
     * 
     * @param method The function or method to store. Can be any callable reference.
     * @param args Optional array of arguments to pass when the method is called.
     *             If not provided, an empty array is used.
     * 
     * @example
     * ```haxe
     * // Simple function
     * var c1 = new Closure(trace, ["Hello"]);
     * 
     * // Instance method
     * var c2 = new Closure(sprite.moveTo, [100, 200]);
     * 
     * // No arguments
     * var c3 = new Closure(doCleanup);
     * ```
     */
    public function new(method:Any, ?args:Array<Any>):Void {

        this.method = method;
        this.args = args != null ? args : [];

    }

    /**
     * Executes the stored method with the bound arguments.
     * 
     * Uses reflection to call the method, which allows it to work with
     * any type of function or method reference.
     * 
     * @return The return value from the called method, or null if the method returns Void
     * 
     * @example
     * ```haxe
     * var closure = new Closure(Math.max, [5, 10]);
     * var result = closure.call(); // Returns 10
     * ```
     */
    public function call():Dynamic {

        var method:Dynamic = this.method;
        var args:Array<Dynamic> = cast this.args;
        return Reflect.callMethod(null, method, args);

    }

}
