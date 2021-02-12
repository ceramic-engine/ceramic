package ceramic;

/**
 * A `System` is an object assigned to app lifecycle and used to
 * do some work such as dispatching events or manipulating entities.
 * Systems can be ordered with `order` properties
 */
@:access(ceramic.Systems)
@:allow(ceramic.Systems)
class System extends Entity {

    @event function beginEarlyUpdate(delta:Float);

    @event function endEarlyUpdate(delta:Float);

    @event function beginLateUpdate(delta:Float);

    @event function endLateUpdate(delta:Float);

    /**
     * System name.
     * Useful to retrieve a system afterwards
     */
    public var name:String = null;

    /** When set to `true` (default). This system will be updated automatically.
        If `false`, you'll need to call `earlyUpdate()` and `lateUpdate()` manually. */
    public var autoUpdate:Bool = true;

    /**
     * Order of earlyUpdate execution.
     * Given two systems, a system with a lower `earlyUpdateOrder` value will have
     * it's `earlyUpdate()` method called before another system's `earlyUpdate()`
     * method with a higher `order` value.
     */
    public var earlyUpdateOrder(default, set):Float = 0;
    function set_earlyUpdateOrder(earlyUpdateOrder:Float):Float {
        if (this.earlyUpdateOrder != earlyUpdateOrder) {
            this.earlyUpdateOrder = earlyUpdateOrder;
            ceramic.App.app.systems.earlyUpdateOrderDirty = true;
        }
        return earlyUpdateOrder;
    }

    /**
     * Order of lateUpdate execution.
     * Given two systems, a system with a lower `lateUpdateOrder` value will have
     * it's `lateUpdate()` method called before another system's `lateUpdate()`
     * method with a higher `order` value.
     */
    public var lateUpdateOrder(default, set):Float = 0;
    function set_lateUpdateOrder(lateUpdateOrder:Float):Float {
        if (this.lateUpdateOrder != lateUpdateOrder) {
            this.lateUpdateOrder = lateUpdateOrder;
            ceramic.App.app.systems.lateUpdateOrderDirty = true;
        }
        return lateUpdateOrder;
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
    function earlyUpdate(delta:Float):Void {

    }

    /**
     * Method automatically called right before app's right after `update` event
     * @param delta 
     */
    function lateUpdate(delta:Float):Void {

    }

}
