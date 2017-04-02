package ceramic;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/** Lazy allows to mark any property as lazy.
    Lazy properties are initialized only at first access. */
#if !macro
@:autoBuild(ceramic.LazyMacro.build())
#end
interface Lazy {}

class LazyMacro {
#if macro

    macro static public function build():Array<Field> {
        var fields = Context.getBuildFields();

        // Check class fields
        var fieldsByName = new Map<String,Bool>();
        for (field in fields) {
            fieldsByName.set(field.name, true);
        }

        // Also check parent fields
        var parentHold = Context.getLocalClass().get().superClass;
        var parent = parentHold != null ? parentHold.t : null;
        while (parent != null) {

            for (field in parent.get().fields.get()) {
                fieldsByName.set(field.name, true);
            }

            parentHold = parent.get().superClass;
            parent = parentHold != null ? parentHold.t : null;
        }
        
        //

        return fields;

    } //build

#end
}
