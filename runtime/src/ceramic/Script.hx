package ceramic;

import hscript.Parser;
import hscript.Expr;

import ceramic.AllApi;
import ceramic.Shortcuts.*;

class Script extends Entity implements Component {

    public static var errorHandlers:Array<(error:String,line:Int,char:Int)->Void> = [];

    static var parser:Parser = null;

    public var content(default, null):String;

    public var program(default, null):Expr;

    public var interp(default, null):Interp;

    public var module(default, null):ScriptModule;

    var ready:Bool = false;

    var running:Bool = false;

    var broken:Bool = false;

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
            if (Std.is(entity, Visual)) {
                interp.variables.set('visual', entity);
            }

            run();
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
                initCb();
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

}

class Interp extends hscript.Interp {

    var owner:Script;

    public function new(owner:Script) {

        super();

        this.owner = owner;

    }

    override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic {

        if (o != null && Std.is(o, ScriptModule)) {
            var module:ScriptModule = cast o;
            return module.owner.call(f, args);
        }
        else {
            return call(o, get(o, f), args);
        }

    }

    override function cnew(cl:String, args:Array<Dynamic>):Dynamic {

        if (owner == null)
            return null;

        var instance = super.cnew(cl, args);

        // When creating an entity from script, tie it to the script
        // so that when the script is destroyed, related entities are destroyed too.
        if (Std.is(instance, Entity)) {
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
            @:privateAccess owner.broken = true;
            log.error('Error when running script function: $e');
            for (handler in Script.errorHandlers) {
                handler('Error when running script function: $e', -1, -1);
            }
            owner.destroy();
            owner = null;
        }
        return null;

    }

}
