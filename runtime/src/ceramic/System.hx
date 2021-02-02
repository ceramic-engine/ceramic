package ceramic;

/**
 * A `System` is an object assigned to app lifecycle and used to
 * do some work such as dispatching events or manipulating entities.
 * Systems can be ordered with `order` properties
 */
@:access(ceramic.Systems)
class System extends Entity {

    /**
     * System name.
     * Useful to retrieve a system afterwards
     */
    public var name:String = null;

    /**
     * Order of preUpdate execution.
     * Given two systems, a system with a lower `preUpdateOrder` value will have
     * it's `preUpdate()` method called before another system's `preUpdate()`
     * method with a higher `order` value.
     */
    public var preUpdateOrder(default, set):Float = 0;
    function set_preUpdateOrder(preUpdateOrder:Float):Float {
        if (this.preUpdateOrder != preUpdateOrder) {
            this.preUpdateOrder = preUpdateOrder;
            ceramic.App.app.systems.preUpdateOrderDirty = true;
        }
        return preUpdateOrder;
    }

    /**
     * Order of postUpdate execution.
     * Given two systems, a system with a lower `postUpdateOrder` value will have
     * it's `postUpdate()` method called before another system's `postUpdate()`
     * method with a higher `order` value.
     */
    public var postUpdateOrder(default, set):Float = 0;
    function set_postUpdateOrder(postUpdateOrder:Float):Float {
        if (this.postUpdateOrder != postUpdateOrder) {
            this.postUpdateOrder = postUpdateOrder;
            ceramic.App.app.systems.postUpdateOrderDirty = true;
        }
        return postUpdateOrder;
    }

    public function new() {

        super();

        ceramic.App.app.systems.addSystem(this);

    }

    override function destroy() {

        super.destroy();

        ceramic.App.app.systems.removeSystem(this);

    }

    /**
     * Method automatically called right before app's `update` event
     * @param delta 
     */
    public function preUpdate(delta:Float):Void {

    }

    /**
     * Method automatically called right before app's right after `update` event
     * @param delta 
     */
    public function postUpdate(delta:Float):Void {

    }

}
