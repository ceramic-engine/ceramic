package ceramic;

using StringTools;

class Model extends Entity implements Observable {

    public function new() {

    } //new

    public function deserialize(data:String):Void {

        // TODO

    } //deserialize

    public function serialize():String {

        return null; // TODO

    } //serialize

/// Print

    function toString():String {

        var result:Dynamic = {};

        for (key in Reflect.fields(this)) {

            if (key.startsWith('__')) continue;

            var displayKey = key;
            if (displayKey.startsWith('unobserved')) {
                displayKey = displayKey.charAt(10).toLowerCase() + displayKey.substring(11);
            }

            Reflect.setField(result, displayKey, Reflect.field(this, key));

        }

        return '' + result;

    } //toString

} //Model
