package ceramic;

import hscript.Parser;
import hscript.Expr;

import ceramic.AllApi;
import ceramic.Shortcuts.*;

class Script extends Entity implements Component {

    static var MAX_LOOP_ITERATIONS:Int = 1999999;

    public static var errorHandlers:Array<(error:String,line:Int,char:Int)->Void> = [];

    public static var traceHandlers:Array<(v:Dynamic,?pos:haxe.PosInfos)->Void> = [];

    public static var log(default, null):Logger = new Logger();

    static var parser:Parser = null;

    public var content(default, null):String;

    public var program(default, null):Expr;

    public var interp(default, null):Interp;

    public var module(default, null):ScriptModule;

    var ready:Bool = false;

    var running:Bool = false;

    var broken:Bool = false;

    var loopStates:IntIntMap = null;

    public function new(content:String) {

        super();

        this.content = content;
        this.module = new ScriptModule(this);

        if (parser == null) {
            parser = new Parser();
            parser.allowJSON = true;
            parser.allowTypes = true;
            parser.allowMetadata = true;
        }

        try {
            content = ScriptUtils.toHscript(content);
            program = parser.parseString(content);
            interp = new Interp(this);
    
            AllApi.configureHscript(interp);

            interp.variables.set('this', this);
            interp.variables.set('self', this);

            interp.variables.set('_checkLoop', checkLoop);

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

    function bindAsComponent():Void {

        if (ready && !running) {
            
            interp.variables.set('entity', entity);
            if (Std.isOfType(entity, Visual)) {
                interp.variables.set('visual', entity);
            }

            interp.variables.set('get', getEntity);
            interp.variables.set('module', getModule);

            app.onceImmediate(run);
        }

    }

    public function run():Void {

        if (!ready || running) {
            return;
        }

        running = true;

        try {
            interp.execute(program);

            var initCb = interp.variables.get('init');
            if (initCb != null && Reflect.isFunction(initCb)) {
                app.oncePostFlushImmediate(initCb);
            }

            var updateCb = interp.variables.get('update');
            if (updateCb != null && Reflect.isFunction(updateCb)) {
                app.onUpdate(this, updateCb);
            }

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

    public function getEntity(itemId:String):Entity {

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

    public function getModule(itemId:String):ScriptModule {

        #if plugin_script
        var entity = getEntity(itemId);

        if (entity != null) {
            var script = entity.script;
            if (script != null) {
                return script.module;
            }
        }
        #end
        
        return null;
        
    }

    public function get(name:String):Dynamic {
        
        return interp != null && interp.variables.get(name);

    }

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

    function resetCheckLoop(_) {

        loopStates.clear();

    }

}

class Interp extends hscript.Interp {

    var owner:Script;

    public function new(owner:Script) {

        super();

        this.owner = owner;

    }

    override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic {

        if (o != null && Std.isOfType(o, ScriptModule)) {
            var module:ScriptModule = cast o;
            return module.owner.call(f, args);
        }
        else {
            return call(o, get(o, f), args);
        }

    }

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
