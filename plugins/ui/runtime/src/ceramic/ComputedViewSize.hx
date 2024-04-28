package ceramic;

@:structInit
class ComputedViewSize {

    public static final NO_SIZE:Float = -2147483640;

    static var _pool:Pool<ComputedViewSize> = new Pool();

    public var parentLayoutMask:ViewLayoutMask = ViewLayoutMask.FLEXIBLE;

    public var parentWidth:Float = NO_SIZE;

    public var parentHeight:Float = NO_SIZE;

    public var computedWidth:Float = NO_SIZE;

    public var computedHeight:Float = NO_SIZE;

    /**
     * Used for specific cases like `TextView`
     */
    public var computedFitWidth:Float = NO_SIZE;

    public function recycle() {
        _pool.recycle(this);
    }

    public static function get():ComputedViewSize {
        if (_pool == null) {
            _pool = new Pool();
        }
        var item:ComputedViewSize = _pool.get();
        if (item == null) {
            item = {};
        }

        item.parentLayoutMask = ViewLayoutMask.FLEXIBLE;
        item.parentWidth = NO_SIZE;
        item.parentHeight = NO_SIZE;
        item.computedWidth = NO_SIZE;
        item.computedHeight = NO_SIZE;
        item.computedFitWidth = NO_SIZE;

        return item;
    }

}
