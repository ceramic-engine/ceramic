package ceramic;

import ceramic.Shortcuts.*;

import haxe.DynamicAccess;

class ConvertComponentMap implements ConvertField<DynamicAccess<String>,Map<String,Component>> {

    public function new() {}

    public function basicToField(assets:Assets, basic:DynamicAccess<String>, done:Map<String,Component>->Void):Void {

        if (basic == null) {
            done(null);
            return;
        }

        var value = new Map<String,Component>();

        for (name in basic.keys()) {
            // TODO extract arguments from value instead of treating it as initializer name directly
            var initializerName = basic.get(name);

            if (app.componentInitializers.exists(initializerName)) {
                var component = app.componentInitializers.get(initializerName)([]);
                if (component != null) {
                    @:privateAccess component.initializerName = initializerName;
                    value.set(name, component);
                }
            }
            #if debug
            else {
                warning('Missing component initializer: ' + initializerName);
            }
            #end
        }

        done(value);

    } //basicToField

    public function fieldToBasic(value:Map<String,Component>):DynamicAccess<String> {

        if (value == null) return null;

        var basic:DynamicAccess<String> = {};

        for (name in value.keys()) {
            var component = value.get(name);
            if (component != null && component.initializerName != null) {
                basic.set(name, component.initializerName);
            }
        }

        return basic;

    } //fieldToBasic

} //ConvertComponentMap
