package ceramic;

/**
 * View size helpers
 */
abstract ViewSize(Float) from Float to Float {

    inline public function new(value:Float) {
        this = value;
    }

    inline public function toFloat():Float {
        return this;
    }

    inline public static function isStandard(encoded:Float):Bool {

        return encoded > -39999.9;

    }

/// Percent

    inline public static function percent(value:Float):ViewSize {

        return -50000.0 + (value < -10000.0 ? -10000.0 : (value > 10000.0 ? 10000.0 : value));

    }

    inline public static function isPercent(encoded:Float):Bool {

        // Slightly extend range to ensure float precision doesn't create surprises
        return encoded < -39999.9 && encoded > -60000.1;

    }

    inline public static function percentToFloat(encoded:Float):Float {

        return (encoded + 50000.0) * 0.01;

    }

/// Auto

    inline public static function fill():ViewSize {

        return -60002.0;

    }

    inline public static function isFill(encodedSize:Float):Bool {

        // Slightly extend range to ensure float precision doesn't create surprises
        return encodedSize > -60002.1 && encodedSize < -60001.9;

    }

/// None

    inline public static function auto():ViewSize {

        return -60001.0;

    }

    inline public static function isAuto(encodedSize:Float):Bool {

        // Slightly extend range to ensure float precision doesn't create surprises
        return encodedSize > -60001.1 && encodedSize < -60000.9;

    }

/// Compute

    inline public static function computeWithParentSize(encoded:Float, parent:Float):Float {

        return encoded == 0
                ? 0.0
                : (isPercent(encoded)
                    ? percentToFloat(encoded) * parent
                    : (isFill(encoded)
                        ? parent
                        : encoded
                    )
                );

    }

/// Print

    public function toString() {

        if (ViewSize.isPercent(this)) return Math.round(ViewSize.percentToFloat(this) * 100) + '%';
        if (ViewSize.isAuto(this)) return 'auto';
        if (ViewSize.isFill(this)) return 'fill';
        return '' + this;

    }

}
