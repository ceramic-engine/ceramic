package ceramic;

/**
 * Type-safe representation of view sizing modes.
 * 
 * ViewSize uses encoded float values to represent different sizing modes:
 * - Fixed sizes: Regular positive float values (e.g., 100.0 = 100 pixels)
 * - Percentage: Encoded values between -60000 and -40000
 * - Fill: Special value around -60002
 * - Auto: Special value around -60001
 * 
 * This encoding allows ViewSize to be used directly as a Float while
 * maintaining type safety and avoiding object allocations.
 * 
 * ```haxe
 * // Fixed size
 * view.viewWidth = 200; // 200 pixels
 * 
 * // Percentage
 * view.viewWidth = ViewSize.percent(50); // 50% of parent
 * 
 * // Fill available space
 * view.viewWidth = ViewSize.fill();
 * 
 * // Size based on content
 * view.viewHeight = ViewSize.auto();
 * ```
 * 
 * @see View For usage in the layout system
 */
abstract ViewSize(Float) from Float to Float {

    inline public function new(value:Float) {
        this = value;
    }

    /**
     * Convert this ViewSize to its raw float value.
     * @return The underlying encoded float value
     */
    inline public function toFloat():Float {
        return this;
    }

    /**
     * Check if the value represents a standard (fixed) size.
     * Standard sizes are regular positive float values that represent
     * pixel dimensions directly.
     * @param encoded The encoded size value to check
     * @return true if this is a fixed pixel size
     */
    inline public static function isStandard(encoded:Float):Bool {

        return encoded > -39999.9;

    }

/// Percent

    /**
     * Create a percentage-based size value.
     * The percentage is relative to the parent container's size.
     * Values are clamped to [-10000, 10000] to prevent overflow.
     * 
     * @param value Percentage value (0-100 typical, negative values allowed)
     * @return Encoded percentage size
     * 
     * ```haxe
     * view.viewWidth = ViewSize.percent(50);  // 50% of parent width
     * view.viewHeight = ViewSize.percent(25); // 25% of parent height
     * ```
     */
    inline public static function percent(value:Float):ViewSize {

        return -50000.0 + (value < -10000.0 ? -10000.0 : (value > 10000.0 ? 10000.0 : value));

    }

    /**
     * Check if the value represents a percentage size.
     * @param encoded The encoded size value to check
     * @return true if this is a percentage-based size
     */
    inline public static function isPercent(encoded:Float):Bool {

        // Slightly extend range to ensure float precision doesn't create surprises
        return encoded < -39999.9 && encoded > -60000.1;

    }

    /**
     * Convert an encoded percentage value back to its percentage (0-100 scale).
     * @param encoded The encoded percentage value
     * @return The percentage as a multiplier (e.g., 0.5 for 50%)
     */
    inline public static function percentToFloat(encoded:Float):Float {

        return (encoded + 50000.0) * 0.01;

    }

/// Fill

    /**
     * Create a fill size value.
     * Fill means the view should expand to use all available space
     * in the parent container.
     * @return Encoded fill size value
     * 
     * ```haxe
     * view.viewWidth = ViewSize.fill();  // Use all available width
     * view.viewHeight = ViewSize.fill(); // Use all available height
     * ```
     */
    inline public static function fill():ViewSize {

        return -60002.0;

    }

    /**
     * Check if the value represents a fill size.
     * @param encodedSize The encoded size value to check
     * @return true if this is a fill size
     */
    inline public static function isFill(encodedSize:Float):Bool {

        // Slightly extend range to ensure float precision doesn't create surprises
        return encodedSize > -60002.1 && encodedSize < -60001.9;

    }

/// Auto

    /**
     * Create an auto size value.
     * Auto means the view should size itself based on its content.
     * The exact behavior depends on the view type and layout context.
     * @return Encoded auto size value
     * 
     * ```haxe
     * // Text view that sizes to fit its content
     * textView.viewWidth = ViewSize.auto();
     * textView.viewHeight = ViewSize.auto();
     * ```
     */
    inline public static function auto():ViewSize {

        return -60001.0;

    }

    /**
     * Check if the value represents an auto size.
     * @param encodedSize The encoded size value to check
     * @return true if this is an auto size
     */
    inline public static function isAuto(encodedSize:Float):Bool {

        // Slightly extend range to ensure float precision doesn't create surprises
        return encodedSize > -60001.1 && encodedSize < -60000.9;

    }

/// Compute

    /**
     * Compute the actual pixel size from an encoded value and parent size.
     * This method handles all size modes:
     * - Fixed sizes: Returns the value as-is
     * - Percentage: Calculates percentage of parent size
     * - Fill: Returns the full parent size
     * - Auto: Returns the encoded value (handled elsewhere)
     * 
     * @param encoded The encoded size value
     * @param parent The parent container's size in pixels
     * @return The computed size in pixels
     * 
     * ```haxe
     * var width = ViewSize.computeWithParentSize(viewWidth, parentWidth);
     * ```
     */
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

    /**
     * Convert this ViewSize to a human-readable string.
     * @return String representation (e.g., "100", "50%", "auto", "fill")
     */
    public function toString() {

        if (ViewSize.isPercent(this)) return Math.round(ViewSize.percentToFloat(this) * 100) + '%';
        if (ViewSize.isAuto(this)) return 'auto';
        if (ViewSize.isFill(this)) return 'fill';
        return '' + this;

    }

}
