package ceramic.ui;

/** View size helpers */
class ViewSize {

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

    inline public static function auto():Float {

        return -2;

    } //auto

    inline public static function isAuto(encodedSize:Float):Bool {

        return encodedSize == -2;

    } //isAuto

/// None

    inline public static function none():Float {

        return -1;

    } //none

    inline public static function isNone(encodedSize:Float):Bool {

        return encodedSize == -1;

    } //isNone

/// Compute

    inline public static function computeWithParentSize(encoded:Float, parent:Float):Float {

        return encoded == 0
                ? 0
                : (isPercent(encoded)
                    ? percentToFloat(encoded) * parent
                    : (isAuto(encoded)
                        ? parent
                        : encoded
                    )
                );

    } //computeWithParentSize

} //ViewSize
