package ceramic;

import ceramic.Assert.assert;

using ceramic.Extensions;

class KeyBindings extends Entity {

    static var instances:Array<KeyBindings> = [];

/// Internal properties

    var bindings:Array<KeyBinding> = [];

/// Lifecycle

    public function new() {

        super();

        instances.push(this);

    }

    override function destroy() {

        super.destroy();

        instances.splice(instances.indexOf(this), 1);

    }

/// Public API

    public function bind(accelerator:Array<KeyAcceleratorItem>, ?callback:Void->Void):KeyBinding {

        assert(accelerator != null, 'accelerator should not be null');
        assert(accelerator.length > 0, 'accelerator should have at least one item');

        var binding = new KeyBinding(accelerator);
        bindings.push(binding);

        if (callback != null) {
            binding.onTrigger(this, callback);
        }

        return binding;

    }

    @:noCompletion public static function forceKeysUp() {

        for (instance in instances) {
            for (bind in instance.bindings) {
                bind.forceKeysUp();
            }
        }

    }

}
