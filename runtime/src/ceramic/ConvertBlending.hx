package ceramic;

import ceramic.Shortcuts.*;

/**
 * Converter between the basic value of a blending in fragment data and
 * `Blending`.
 *
 * `Blending` is an enum abstract over `Int`: unlike a regular enum, its
 * values cannot be found by name at runtime without this converter.
 * A blending is written by its name (`"ADD"`, in any case), which stays
 * readable and does not depend on the numbers behind the names. A number
 * is accepted as well.
 */
class ConvertBlending implements ConvertField<Any,Blending> {

    public function new() {}

    public function basicToField(instance:Entity, field:String, assets:Assets, basic:Any, done:Blending->Void):Void {

        if (basic == null) {
            done(Blending.AUTO);
        }
        else if (basic is String) {
            var name:String = basic;
            var blending:Blending = Blending.AUTO;
            try {
                blending = Blending.fromString(name.toUpperCase());
            }
            catch (e:Dynamic) {
                log.warning('Unknown blending: ' + name + ' (using AUTO)');
            }
            done(blending);
        }
        else {
            var value:Int = Std.int(basic);
            done(value);
        }

    }

    public function fieldToBasic(instance:Entity, field:String, value:Blending):Any {

        return value.toString();

    }

}
