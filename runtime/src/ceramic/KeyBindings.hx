package ceramic;

import ceramic.Assert.assert;

using ceramic.Extensions;

class KeyBindings extends Entity implements Component {

    static var instances:Array<KeyBindings> = [];

/// Internal properties

    var bindings:Array<KeyBinding> = [];

/// Lifecycle

    function bindAsComponent() {

        // Nothing to do

    }

    public function new() {

        super();

        instances.push(this);

    }

    override function destroy() {

        super.destroy();

        if (bindings != null) {
            while (bindings.length > 0) {
                bindings.pop().destroy();
            }
            bindings = null;
        }

        instances.splice(instances.indexOf(this), 1);

    }

/// Public API

    public function bind(accelerator:Array<KeyAcceleratorItem>, ?callback:Void->Void):KeyBinding {

        assert(accelerator != null, 'accelerator should not be null');
        assert(accelerator.length > 0, 'accelerator should have at least one item');

        var binding = new KeyBinding(accelerator, this);
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
