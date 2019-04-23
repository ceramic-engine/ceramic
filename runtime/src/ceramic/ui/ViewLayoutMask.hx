package ceramic.ui;

abstract ViewLayoutMask(Int) from Int to Int {

    inline public function new(value:Int) {
        this = value;
    }

    inline public static var INCREASE_WIDTH = new ViewLayoutMask(1 << 0);

    inline public static var DECREASE_WIDTH = new ViewLayoutMask(1 << 1);

    inline public static var INCREASE_HEIGHT = new ViewLayoutMask(1 << 2);

    inline public static var DECREASE_HEIGHT = new ViewLayoutMask(1 << 3);

    inline public static var FIXED = new ViewLayoutMask(0);

    inline public static var FLEXIBLE_WIDTH = new ViewLayoutMask(INCREASE_WIDTH | DECREASE_WIDTH);

    inline public static var FLEXIBLE_HEIGHT = new ViewLayoutMask(INCREASE_HEIGHT | DECREASE_HEIGHT);

    inline public static var FLEXIBLE = new ViewLayoutMask(FLEXIBLE_WIDTH | FLEXIBLE_HEIGHT);

    inline public static var INCREASE = new ViewLayoutMask(INCREASE_WIDTH | INCREASE_HEIGHT);

    inline public static var DECREASE = new ViewLayoutMask(DECREASE_WIDTH | DECREASE_HEIGHT);

/// Layout helpers

    inline public function canIncreaseWidth(?value:Bool) {
        if (value == null) {
            return (this & INCREASE_WIDTH) == INCREASE_WIDTH;
        } else {
            this = value ? this | INCREASE_WIDTH : this & ~(INCREASE_WIDTH);
            return value;
        }
    }

    inline public function canDecreaseWidth(?value:Bool) {
        if (value == null) {
            return (this & DECREASE_WIDTH) == DECREASE_WIDTH;
        } else {
            this = value ? this | DECREASE_WIDTH : this & ~(DECREASE_WIDTH);
            return value;
        }
    }

    inline public function canIncreaseHeight(?value:Bool) {
        if (value == null) {
            return (this & INCREASE_HEIGHT) == INCREASE_HEIGHT;
        } else {
            this = value ? this | INCREASE_HEIGHT : this & ~(INCREASE_HEIGHT);
            return value;
        }
    }

    inline public function canDecreaseHeight(?value:Bool) {
        if (value == null) {
            return (this & DECREASE_HEIGHT) == DECREASE_HEIGHT;
        } else {
            this = value ? this | DECREASE_HEIGHT : this & ~(DECREASE_HEIGHT);
            return value;
        }
    }

/// Print

    function toString():String {

        if (this == INCREASE_WIDTH) return 'INCREASE_WIDTH';
        if (this == DECREASE_WIDTH) return 'DECREASE_WIDTH';
        if (this == INCREASE_HEIGHT) return 'INCREASE_HEIGHT';
        if (this == DECREASE_HEIGHT) return 'DECREASE_HEIGHT';
        if (this == FIXED) return 'FIXED';
        if (this == FLEXIBLE_WIDTH) return 'FLEXIBLE_WIDTH';
        if (this == FLEXIBLE_HEIGHT) return 'FLEXIBLE_HEIGHT';
        if (this == FLEXIBLE) return 'FLEXIBLE';
        if (this == INCREASE) return 'INCREASE';
        if (this == DECREASE) return 'DECREASE';
        return ''+this;

    } //toString

} //ViewLayoutMask
