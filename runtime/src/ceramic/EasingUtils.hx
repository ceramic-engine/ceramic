package ceramic;

/**
 * Utility functions for converting between Easing enum values and strings.
 * 
 * This class provides serialization support for easing functions, allowing
 * them to be stored in configuration files, transmitted over networks, or
 * used in any context requiring string representation.
 * 
 * ## Usage Example
 * 
 * ```haxe
 * // Convert easing to string for storage
 * var easing = Easing.QUAD_EASE_OUT;
 * var str = EasingUtils.easingToString(easing); // "QUAD_EASE_OUT"
 * 
 * // Restore easing from string
 * var restored = EasingUtils.easingFromString("QUAD_EASE_OUT");
 * 
 * // Use with configuration
 * config.animationEasing = EasingUtils.easingToString(myEasing);
 * var loadedEasing = EasingUtils.easingFromString(config.animationEasing);
 * ```
 * 
 * ## Limitations
 * 
 * - BEZIER and CUSTOM easings are not yet supported for serialization
 * - Invalid string names will throw an exception
 * 
 * @see ceramic.Easing For the easing enumeration
 */
class EasingUtils {

    /**
     * Empty array used for enum construction without parameters.
     * Cached to avoid repeated allocations.
     */
    static var _emptyArray:Array<Dynamic> = [];

    /**
     * Converts a string representation to an Easing enum value.
     * 
     * The string must exactly match an Easing enum constructor name
     * (e.g., "LINEAR", "QUAD_EASE_IN_OUT", etc.).
     * 
     * @param str The string name of the easing function
     * @return The corresponding Easing enum value
     * @throws String If the string doesn't match any Easing constructor
     * 
     * @example
     * ```haxe
     * var easing1 = EasingUtils.easingFromString("LINEAR");
     * var easing2 = EasingUtils.easingFromString("BOUNCE_EASE_OUT");
     * 
     * // These will throw:
     * // EasingUtils.easingFromString("linear"); // Wrong case
     * // EasingUtils.easingFromString("INVALID"); // Doesn't exist
     * ```
     * 
     * TODO: Add support for BEZIER easing serialization
     */
    public static function easingFromString(str:String):Easing {

        // TODO BEZIER

        return Type.createEnum(Easing, str, _emptyArray);

    }

    /**
     * Converts an Easing enum value to its string representation.
     * 
     * Returns the exact constructor name of the enum value, which can
     * be used with easingFromString() to recreate the easing.
     * 
     * @param easing The Easing enum value to convert
     * @return The string name of the easing constructor
     * 
     * @example
     * ```haxe
     * var str1 = EasingUtils.easingToString(Easing.LINEAR); // "LINEAR"
     * var str2 = EasingUtils.easingToString(Easing.ELASTIC_EASE_IN); // "ELASTIC_EASE_IN"
     * 
     * // Round-trip conversion
     * var original = Easing.SINE_EASE_OUT;
     * var str = EasingUtils.easingToString(original);
     * var restored = EasingUtils.easingFromString(str);
     * // original == restored
     * ```
     * 
     * TODO: Add support for BEZIER easing serialization
     */
    public static function easingToString(easing:Easing):String {

        // TODO BEZIER

        return easing.getName();

    }

}
