package ceramic;

import ceramic.Assert.assert;

using ceramic.Extensions;

class KeyBindings extends Entity {

/// Internal properties

    var bindings:Array<KeyBinding> = [];

/// Lifecycle

    public function new() {

    } //new

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

    } //bind

} //KeyBindings
