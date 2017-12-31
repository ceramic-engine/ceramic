package ceramic;

import haxe.DynamicAccess;

class ConvertMap<T> implements ConvertField<DynamicAccess<T>,Map<String,T>> {

    public function new() {}

    public function basicToField(assets:Assets, basic:DynamicAccess<T>, done:Map<String,T>->Void):Void {

        if (basic == null) {
            done(null);
            return;
        }

        var value = new Map<String,T>();

        for (key in basic.keys()) {
            value.set(key, basic.get(key));
        }

        done(value);

    } //basicToField

    public function fieldToBasic(value:Map<String,T>):DynamicAccess<T> {

        if (value == null) return null;

        var basic:DynamicAccess<T> = {};

        for (key in value.keys()) {
            basic.set(key, value.get(key));
        }

        return basic;

    } //fieldToBasic

} //ConvertMap
