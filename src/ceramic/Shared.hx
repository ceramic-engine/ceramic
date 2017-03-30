package ceramic;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/** Shared adds a static `shared` property to get
    or create an instance of the target class. */
#if !macro
@:autoBuild(ceramic.SharedMacro.build())
#end
interface Shared {}

class SharedMacro {
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

        var newFields = [];
        
        //

        return newFields;

    } //build

#end
}
