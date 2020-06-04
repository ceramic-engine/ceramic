package ceramic;

import hscript.Parser;
import hscript.Expr;

import ceramic.AllApi;
import ceramic.Shortcuts.*;

class Script extends Entity implements Component {

    public static var errorHandlers:Array<(error:String,line:Int,char:Int)->Void> = [];

    static var parser:Parser = null;

    public var content(default, null):String;

    var program:Expr;

    var interp:Interp;

    var ready:Bool = false;

    var running:Bool = false;

    public function new(content:String) {

        super();

        this.content = content;

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
            log.error('Failed to parse script: $e');
            for (handler in errorHandlers) {
                handler('Failed to parse script: $e', -1, -1);
            }
        }

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
        }
        catch (e:Dynamic) {
            log.error('Failed to run script: $e');
            for (handler in errorHandlers) {
                handler('Failed to run script: ' + e, -1, -1);
            }
        }

    }

}

class Interp extends hscript.Interp {

    var owner:Script;

    public function new(owner:Script) {

        super();

        this.owner = owner;

    }

	override function cnew( cl : String, args : Array<Dynamic> ) : Dynamic {
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

	override function exprReturn(e) : Dynamic {
        // Catch any error thrown from a function call in order to prevent
        // crashing the whole app when a script is failing
		try {
			return super.exprReturn(e);
		} catch( e : Dynamic ) {
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
