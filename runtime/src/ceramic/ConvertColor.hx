package ceramic;

import ceramic.Shortcuts.*;

class ConvertColor implements ConvertField<Any,Color> {

    public var preferStringBasic:Bool = false;

    public function new() {}

    public function basicToField(instance:Entity, field:String, assets:Assets, basic:Any, done:Color->Void):Void {

        if (basic != null) {
            if (basic is String) {
                done(Color.fromString(basic));
            }
            else {
                done(Std.int(basic));
            }
        }
        else {
            done(Color.BLACK);
        }

    }

    public function fieldToBasic(instance:Entity, field:String, value:Color):Any {

        return preferStringBasic ? value.toWebString() : value;

    }

}
