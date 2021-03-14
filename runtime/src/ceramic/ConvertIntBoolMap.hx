package ceramic;

import ceramic.Shortcuts.*;

class ConvertIntBoolMap implements ConvertField<Dynamic,IntBoolMap> {

    public function new() {}

    public function basicToField(instance:Entity, field:String, assets:Assets, basic:Dynamic, done:IntBoolMap->Void):Void {

        if (basic == null) {
            done(null);
            return;
        }

        var value = new IntBoolMap();
        
        #if plugin_spine
        // Specific case
        if (Std.is(instance, Spine) && field == 'hiddenSlots') {
            var spine:Spine = cast instance;
            for (key in Reflect.fields(basic)) {
                var boolVal:Bool = Reflect.field(basic, key);
                var slotIndex = Spine.globalSlotIndexForName(key);
                value.set(slotIndex, boolVal);
            }
            done(value);
            return;
        }
        #end
        
        for (key in Reflect.fields(basic)) {
            value.set(Std.parseInt(key), Reflect.field(basic, key));
        }

        done(value);

    }

    public function fieldToBasic(instance:Entity, field:String, value:IntBoolMap):Dynamic {

        if (value == null) return null;

        var basic:Dynamic = {};

        // TODO?
        log.warning('ConvertIntBoolMap.fieldToBasic() not implemented!');

        return basic;

    }

}
