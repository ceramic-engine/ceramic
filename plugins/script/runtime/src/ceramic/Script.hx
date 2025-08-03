package ceramic;

import ceramic.AllApi;
import ceramic.Shortcuts.*;
import hscript.Expr;
import hscript.Parser;

/**
 * Dynamic scripting component for runtime code execution.
 * 
 * Allows entities to have behavior defined through HScript code that can be
 * modified at runtime. Scripts have access to the full Ceramic API and can
 * define lifecycle methods (init, update, destroy).
 * 
 * Features:
 * - JavaScript/TypeScript-like syntax (arrow functions, for-of loops)
 * - Automatic entity lifecycle management
 * - Error handling and sandboxing
 * - Module system for inter-script communication
 * - Infinite loop protection
 * 
 * @example
 * ```haxe
 * // Create a script that moves an entity
 * var scriptCode = '
 * var speed = 100;
 * 
 * function update(delta) {
 *     entity.x += speed * delta;
 *     if (entity.x > screen.width) {
 *         entity.x = 0;
 *     }
 * }
 * ';
 * 
 * var entity = new Quad();
 * entity.size(50, 50);
 * entity.script = new Script(scriptCode);
 * ```
 */
class Script extends Entity implements Component {

    /** Maximum iterations allowed in loops to prevent infinite loops */
    static var MAX_LOOP_ITERATIONS:Int = 1999999;

    /**
     * Global error handlers called when scripts encounter errors.
     * Add handlers here to be notified of all script errors.
     */
    public static var errorHandlers:Array<(error:String,line:Int,char:Int)->Void> = [];

    /**
     * Global trace handlers called when scripts use trace().
     * Add handlers here to intercept script trace output.
     */
    public static var traceHandlers:Array<(v:Dynamic,?pos:haxe.PosInfos)->Void> = [];

    /** Logger instance for script-related messages */
    public static var log(default, null):Logger = new Logger();

    /** Shared HScript parser instance */
    static var parser:Parser = null;

    /**
     * The source code content of this script.
     * Preprocessed to convert JS/TS idioms to HScript.
     */
    public var content(default, null):String;

    /**
     * The parsed HScript AST (Abstract Syntax Tree).
     */
    public var program(default, null):Expr;

    /**
     * The HScript interpreter executing this script.
     * Provides access to variables and execution context.
     */
    public var interp(default, null):Interp;

    /**
     * Module interface for inter-script communication.
     * Other scripts can access this script's exports through this module.
     */
    public var module(default, null):ScriptModule;

    /** Whether the script has been successfully parsed and is ready to run */
    var ready:Bool = false;

    /** Whether the script is currently executing */
    var running:Bool = false;

    /** Whether the script has encountered a fatal error */
    var broken:Bool = false;

    /** Tracks loop iterations for infinite loop detection */
    var loopStates:IntIntMap = null;

    /**
     * Creates a new script with the given source code.
     * 
     * The script is parsed immediately. If parsing fails, the script
     * is marked as broken and scheduled for destruction.
     * 
     * @param content Source code in JavaScript/TypeScript-like syntax
     */
    public function new(content:String) {

        super();

        this.content = content;
        this.module = new ScriptModule(this);

        // Initialize shared parser
        if (parser == null) {
            parser = new Parser();
            parser.allowJSON = true;
            parser.allowTypes = true;
            parser.allowMetadata = true;
        }

        try {
            // Convert JS/TS syntax to HScript
            content = ScriptUtils.toHscript(content);
            program = parser.parseString(content);
            interp = new Interp(this);

            // Configure interpreter with Ceramic API
            AllApi.configureHscript(interp);

            // Set up built-in variables
            interp.variables.set('this', this);
            interp.variables.set('self', this);

            // Internal loop checker for infinite loop protection
            interp.variables.set('_checkLoop', checkLoop);

            // Custom trace function that calls handlers
            interp.variables.set('trace', function(v:Dynamic, ?pos:haxe.PosInfos) {
                if (traceHandlers != null) {
                    for (i in 0...traceHandlers.length) {
                        traceHandlers[i](v, pos);
                    }
                }
                haxe.Log.trace(v, pos);
            });
            interp.variables.set('log', Script.log);

            ready = true;
        }
        catch (e:Dynamic) {
            broken = true;
            log.error('Failed to parse script: $e');
            for (handler in errorHandlers) {
                handler('Failed to parse script: $e', -1, -1);
            }
            app.onceImmediate(destroy);
        }

    }

    override function destroy() {

        super.destroy();

    }

    /**
     * Called when script is attached to an entity as a component.
     * Sets up entity-specific variables and schedules execution.
     */
    function bindAsComponent():Void {

        if (ready && !running) {

            // Provide access to the owning entity
            interp.variables.set('entity', entity);
            if (Std.isOfType(entity, Visual)) {
                interp.variables.set('visual', entity);
            }

            // Helper functions for entity/module access
            interp.variables.set('get', getEntity);
            interp.variables.set('module', getModule);

            app.onceImmediate(run);
        }

    }

    /**
     * Executes the script and sets up lifecycle callbacks.
     * 
     * Looks for and binds these optional functions:
     * - `init()`: Called once after script execution
     * - `update(delta)`: Called every frame with time delta
     * - `destroy()`: Called when script is destroyed
     */
    public function run():Void {

        if (!ready || running) {
            return;
        }

        running = true;

        try {
            // Execute the script body
            interp.execute(program);

            // Set up init callback
            var initCb = interp.variables.get('init');
            if (initCb != null && Reflect.isFunction(initCb)) {
                app.oncePostFlushImmediate(initCb);
            }

            // Set up update callback
            var updateCb = interp.variables.get('update');
            if (updateCb != null && Reflect.isFunction(updateCb)) {
                app.onUpdate(this, updateCb);
            }

            // Set up destroy callback
            var destroyCb = interp.variables.get('destroy');
            if (destroyCb != null && Reflect.isFunction(destroyCb)) {
                onDestroy(this, _ -> {
                    destroyCb();
                });
            }
        }
        catch (e:Dynamic) {
            broken = true;
            log.error('Failed to run script: $e');
            for (handler in errorHandlers) {
                handler('Failed to run script: ' + e, -1, -1);
            }
            destroy();
        }

    }

    /**
     * Gets an entity by its ID from the script's context.
     * 
     * Searches for entities in:
     * 1. Parent Fragment if the script's entity is a Visual
     * 2. Fragment variable in the script's scope
     * 
     * @param itemId Entity ID to look up
     * @return Found entity or null
     */
    public function getEntityById(itemId:String):Entity {

        if (Std.isOfType(entity, Visual)) {
            // Try to get fragment from visual
            var visual:Visual = cast entity;
            var fragment = visual.firstParentWithClass(Fragment);
            if (fragment != null) {
                // Then get entity from fragment
                var item = fragment.get(itemId);
                return item;
            }
        }

        // Try to get fragment from variables
        if (interp != null) {
            var variables = interp.variables;
            if (variables != null) {
                var rawFragment = variables.get('fragment');
                if (rawFragment != null && Std.isOfType(rawFragment, Fragment)) {
                    var fragment:Fragment = rawFragment;
                    var item = fragment.get(itemId);
                    return item;
                }
            }
        }

        return null;

    }

    /**
     * Gets a script module by entity ID.
     * 
     * Allows scripts to access other scripts' exported functions
     * and variables through their module interface.
     * 
     * @param itemId ID of the entity whose script module to retrieve
     * @return Script module or null if entity has no script
     */
    public function getModule(itemId:String):ScriptModule {

        #if plugin_script
        var entity = getEntityById(itemId);

        if (entity != null) {
            var script = entity.script;
            if (script != null) {
                return script.module;
            }
        }
        #end

        return null;

    }

    /**
     * Gets a variable value from the script's scope.
     * 
     * @param name Variable name
     * @return Variable value or null if not found
     */
    public function get(name:String):Dynamic {

        return interp != null && interp.variables.get(name);

    }

    /**
     * Calls a function defined in the script.
     * 
     * @param name Function name
     * @param args Optional arguments to pass
     * @return Function return value
     */
    public function call(name:String, ?args:Array<Dynamic>):Dynamic {

        if (args == null) {
            return callScriptMethod(name, 0);
        }
        else {
            var numArgs = args.length;
            if (numArgs == 0) {
                return callScriptMethod(name, numArgs);
            }
            else if (numArgs == 1) {
                return callScriptMethod(name, numArgs, args[0]);
            }
            else if (numArgs == 2) {
                return callScriptMethod(name, numArgs, args[0], args[1]);
            }
            else if (numArgs == 3) {
                return callScriptMethod(name, numArgs, args[0], args[1], args[2]);
            }
            else {
                return callScriptMethod(name, numArgs, args);
            }
        }

    }

    /**
     * Internal method to call script functions with optimized argument passing.
     * 
     * @param name Function name
     * @param numArgs Number of arguments
     * @param arg1 First argument (or array of all arguments if numArgs > 3)
     * @param arg2 Second argument
     * @param arg3 Third argument
     * @return Function return value or null if function not found
     */
    public function callScriptMethod(name:String, numArgs:Int, ?arg1:Dynamic, ?arg2:Dynamic, ?arg3:Dynamic):Dynamic {

        var method:Dynamic = interp.variables.get(name);
        if (method != null) {
            if (numArgs == 0) {
                return method();
            }
            else if (numArgs == 1) {
                return method(arg1);
            }
            else if (numArgs == 2) {
                return method(arg1, arg2);
            }
            else if (numArgs == 3) {
                return method(arg1, arg2, arg3);
            }
            else {
                var args:Array<Dynamic> = arg1;
                return Reflect.callMethod(null, method, args);
            }
        }
        else {
            return null;
        }

    }

    /**
     * Checks for infinite loops by tracking iteration counts.
     * Called automatically in while loops.
     * 
     * @param index Unique index for each loop in the script
     * @return Always true unless max iterations exceeded
     * @throws String if loop exceeds MAX_LOOP_ITERATIONS
     */
    function checkLoop(index:Int):Bool {

        if (loopStates == null) {
            app.onUpdate(this, resetCheckLoop);
            loopStates = new IntIntMap();
        }

        var iterations = loopStates.get(index);
        if (iterations > MAX_LOOP_ITERATIONS) {
            throw 'Infinite loop!';
        }
        iterations++;
        loopStates.set(index, iterations);

        return true;

    }

    /**
     * Resets loop iteration counters each frame.
     * Prevents false positives from accumulated iterations.
     */
    function resetCheckLoop(_) {

        loopStates.clear();

    }

}

/**
 * Custom HScript interpreter with Ceramic-specific functionality.
 * 
 * Extends the base interpreter to:
 * - Support ScriptModule method calls
 * - Automatically destroy entities created by scripts
 * - Catch and handle runtime errors gracefully
 */
class Interp extends hscript.Interp {

    /** The Script instance that owns this interpreter */
    var owner:Script;

    /**
     * Creates a new interpreter for the given script.
     * 
     * @param owner Script that owns this interpreter
     */
    public function new(owner:Script) {

        super();

        this.owner = owner;

    }

    /**
     * Handles function calls on objects.
     * Special handling for ScriptModule to enable inter-script calls.
     * 
     * @param o Object to call method on
     * @param f Function name
     * @param args Function arguments
     * @return Function result
     */
    override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic {

        if (o != null && Std.isOfType(o, ScriptModule)) {
            var module:ScriptModule = cast o;
            return module.owner.call(f, args);
        }
        else {
            return call(o, get(o, f), args);
        }

    }

    /**
     * Gets a field value from an object.
     * Special handling for ScriptModule to access exported variables.
     * 
     * @param o Object to get field from
     * @param f Field name
     * @return Field value
     */
    override function get(o:Dynamic, f:String):Dynamic {
        if (o == null) error(EInvalidAccess(f));
        if (Std.isOfType(o, ScriptModule)) {
            var module:ScriptModule = cast o;
            return module.owner.get(f);
        }
        return {
            #if php
                // https://github.com/HaxeFoundation/haxe/issues/4915
                try {
                    Reflect.getProperty(o, f);
                } catch (e:Dynamic) {
                    Reflect.field(o, f);
                }
            #else
                Reflect.getProperty(o, f);
            #end
        }
    }

    /**
     * Creates a new instance of a class.
     * 
     * Entities created by scripts are automatically destroyed when
     * the script is destroyed, preventing memory leaks.
     * 
     * @param cl Class name
     * @param args Constructor arguments
     * @return New instance
     */
    override function cnew(cl:String, args:Array<Dynamic>):Dynamic {

        if (owner == null)
            return null;

        var instance = super.cnew(cl, args);

        // When creating an entity from script, tie it to the script
        // so that when the script is destroyed, related entities are destroyed too.
        if (Std.isOfType(instance, Entity)) {
            var entity:Entity = instance;
            owner.onDestroy(entity, _ -> {
                entity.destroy();
            });
        }

        return instance;
    }

    /**
     * Executes a return expression with error handling.
     * 
     * Catches runtime errors to prevent scripts from crashing the application.
     * Failed scripts are marked as broken and destroyed.
     * 
     * @param e Expression to evaluate
     * @return Expression result or null if error
     */
    override function exprReturn(e):Dynamic {

        // Catch any error thrown from a function call in order to prevent
        // crashing the whole app when a script is failing
        try {
            return super.exprReturn(e);
        } catch (e:Dynamic) {
            if (owner != null) {
                @:privateAccess owner.broken = true;
                log.error('Error when running script function: $e');
                for (handler in Script.errorHandlers) {
                    handler('Error when running script function: $e', -1, -1);
                }
                owner.destroy();
                owner = null;
            }
        }
        return null;

    }

}
