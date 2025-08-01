package ceramic;

import ceramic.Assert.assert;

using ceramic.Extensions;

/**
 * Manages a collection of keyboard shortcut bindings.
 * 
 * KeyBindings provides a convenient way to define and manage multiple
 * keyboard shortcuts in your application. It can be used standalone
 * or as a component attached to other entities.
 * 
 * Features:
 * - Create keyboard shortcuts with modifier keys
 * - Automatically handle platform differences (Cmd vs Ctrl)
 * - Component interface for easy attachment to entities
 * - Global key state reset functionality
 * 
 * Example usage:
 * ```haxe
 * var bindings = new KeyBindings();
 * 
 * // Bind Ctrl+S (or Cmd+S on macOS)
 * bindings.bind([CMD_OR_CTRL, KEY(KeyCode.KEY_S)], () -> {
 *     saveDocument();
 * });
 * 
 * // Bind Shift+Delete
 * bindings.bind([SHIFT, KEY(KeyCode.DELETE)], () -> {
 *     permanentDelete();
 * });
 * 
 * // Attach as component
 * myEntity.component(new KeyBindings());
 * ```
 * 
 * @see KeyBinding
 * @see KeyAcceleratorItem
 */
class KeyBindings extends Entity implements Component {

    /**
     * Tracks all active KeyBindings instances.
     * Used for global operations like forceKeysUp().
     */
    static var instances:Array<KeyBindings> = [];

/// Internal properties

    /**
     * Array of KeyBinding instances managed by this KeyBindings.
     */
    var bindings:Array<KeyBinding> = [];

/// Lifecycle

    /**
     * Component interface implementation.
     * Called when this KeyBindings is attached to an entity as a component.
     */
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

    /**
     * Creates a new keyboard shortcut binding.
     * 
     * @param accelerator Array of keys that must be pressed together.
     *                    Order doesn't matter for modifier keys.
     * @param callback Optional callback function to execute when triggered.
     *                 Can also be attached later using binding.onTrigger().
     * @return The created KeyBinding instance
     */
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

    /**
     * Forces all keys to be considered released across all KeyBindings instances.
     * Useful when the application loses focus or when switching contexts.
     * This prevents "stuck" keys when key up events are missed.
     */
    @:noCompletion public static function forceKeysUp() {

        for (instance in instances) {
            for (bind in instance.bindings) {
                bind.forceKeysUp();
            }
        }

    }

}
