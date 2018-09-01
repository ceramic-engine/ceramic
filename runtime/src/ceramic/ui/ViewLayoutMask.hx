package ceramic.ui;

@:enum abstract ViewLayoutMask(Int) from Int to Int {

    public var INCREASE_WIDTH = 1 << 0;

    public var DECREASE_WIDTH = 1 << 1;

    public var INCREASE_HEIGHT = 1 << 2;

    public var DECREASE_HEIGHT = 1 << 3;

    public var FIXED = 0;

    public var FLEXIBLE_WIDTH = INCREASE_WIDTH | DECREASE_WIDTH;

    public var FLEXIBLE_HEIGHT = INCREASE_HEIGHT | DECREASE_HEIGHT;

    public var FLEXIBLE = FLEXIBLE_WIDTH | FLEXIBLE_HEIGHT;

    public var INCREASE = INCREASE_WIDTH | INCREASE_HEIGHT;

    public var DECREASE = DECREASE_WIDTH | DECREASE_HEIGHT;

} //ViewLayoutMask
