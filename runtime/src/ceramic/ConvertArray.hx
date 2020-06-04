package ceramic;

import haxe.DynamicAccess;

class ConvertArray<T> implements ConvertField<Array<T>,Array<T>> {

    public function new() {}

    public function basicToField(assets:Assets, basic:Array<T>, done:Array<T>->Void):Void {

        if (basic == null) {
            done(null);
            return;
        }

        var value:Array<T> = [];
        value = value.concat(basic);

        done(basic);

    }

    public function fieldToBasic(value:Array<T>):Array<T> {

        if (value == null) return null;

        var basic:Array<T> = [];
        basic = basic.concat(value);

        return value;

    }

}
