package ceramic.ui;

/** View size helpers */
class ViewSize {

    inline public static function isStandard(encoded:Float):Bool {

        return encoded >= 0;

    } //isStandard

/// Percent

    inline public static function percent(value:Float):Float {

        return -100.0 - (value < 0.0 ? 0.0 : (value > 100.0 ? 1.0 : value * 0.01));

    } //percent

    inline public static function isPercent(encoded:Float):Bool {

        return encoded <= -100 && encoded >= -101;

    } //isPercent

    inline public static function percentToFloat(encoded:Float):Float {

        return -(encoded + 100.0);

    } //percentToFloat

/// Auto

    inline public static function fill():Float {

        return -2;

    } //auto

    inline public static function isFill(encodedSize:Float):Bool {

        return encodedSize == -2;

    } //isFill

/// None

    inline public static function auto():Float {

        return -1;

    } //auto

    inline public static function isAuto(encodedSize:Float):Bool {

        return encodedSize == -1;

    } //isAuto

/// Compute

    inline public static function computeWithParentSize(encoded:Float, parent:Float):Float {

        return encoded == 0
                ? 0
                : (isPercent(encoded)
                    ? percentToFloat(encoded) * parent
                    : (isFill(encoded)
                        ? parent
                        : encoded
                    )
                );

    } //computeWithParentSize

/// Print

    public static function toString(encodedSize:Float) {

        if (ViewSize.isPercent(encodedSize)) return Math.round(ViewSize.percentToFloat(encodedSize) * 100) + '%';
        if (ViewSize.isAuto(encodedSize)) return 'auto';
        if (ViewSize.isFill(encodedSize)) return 'fill';
        return '' + encodedSize;

    } //toString

} //ViewSize
