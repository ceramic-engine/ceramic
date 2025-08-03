package ceramic;

/**
 * Utility class for extracting color information from Spine animation slots.
 * 
 * Spine animations can have color tinting applied to individual slots (the containers
 * that hold attachments like images). This class provides methods to efficiently
 * extract these color values from multiple slots at once, which is useful for
 * analyzing or replicating the visual state of a Spine animation.
 * 
 * The extraction process uses Spine's slot update callback system to capture
 * color data during a forced render pass, ensuring accurate color values.
 */
class SpineColors {

    /**
     * Extracts the current color values from specified slots in a Spine animation.
     * 
     * This method retrieves the primary color tint applied to each slot. The colors
     * are extracted by temporarily attaching update listeners to the slots, forcing
     * a render update, and then cleaning up the listeners.
     * 
     * @param spine The Spine instance to extract colors from
     * @param slots Array of slot names to extract colors from
     * @param result Optional array to store results in. If provided, it will be reused; otherwise a new array is created
     * @return Array of Color values corresponding to each slot. Slots that don't exist or have no color will have Color.NONE
     * 
     * @example
     * ```haxe
     * var spine = new Spine();
     * spine.load(spineData);
     * 
     * // Extract colors from specific slots
     * var slotNames = ["head", "body", "weapon"];
     * var colors = SpineColors.extractColors(spine, slotNames);
     * 
     * for (i in 0...slotNames.length) {
     *     trace('${slotNames[i]} color: ${colors[i].toHex()}');
     * }
     * ```
     */
    public static function extractColors(spine:Spine, slots:Array<String>, ?result:Array<Color>):Array<Color> {

        if (result == null) {
            result = [];
        }

        var funcs = [];

        for (i in 0...slots.length) {
            result[i] = Color.NONE;
            (i -> {

                funcs.push(info -> {
                    result[i] = Color.fromRGBFloat(
                        info.slot.color.r,
                        info.slot.color.g,
                        info.slot.color.b
                    );
                });

                var slot = slots[i];
                spine.onUpdateSlotWithName(null, slot, funcs[i]);

            })(i);
        }

        spine.forceRender();

        for (i in 0...funcs.length) {
            spine.offUpdateSlotWithName(slots[i], funcs[i]);
        }

        return result;

    }

    /**
     * Extracts the dark color values from specified slots in a Spine animation.
     * 
     * Dark colors in Spine are used for two-color tinting, which allows for more
     * complex shading effects. This is particularly useful for creating rim lighting,
     * shadowing, or other advanced visual effects. Not all Spine animations use
     * dark colors - they must be specifically enabled in the Spine editor.
     * 
     * Like extractColors, this method uses temporary slot listeners and a forced
     * render pass to capture accurate color data.
     * 
     * @param spine The Spine instance to extract dark colors from
     * @param slots Array of slot names to extract dark colors from
     * @param result Optional array to store results in. If provided, it will be reused; otherwise a new array is created
     * @return Array of Color values corresponding to each slot's dark color. Slots without dark colors will have Color.NONE
     * 
     * @example
     * ```haxe
     * var spine = new Spine();
     * spine.load(spineData);
     * 
     * // Extract both regular and dark colors for advanced rendering
     * var slotNames = ["head", "body", "weapon"];
     * var colors = SpineColors.extractColors(spine, slotNames);
     * var darkColors = SpineColors.extractDarkColors(spine, slotNames);
     * 
     * for (i in 0...slotNames.length) {
     *     trace('${slotNames[i]} - Color: ${colors[i].toHex()}, Dark: ${darkColors[i].toHex()}');
     * }
     * ```
     */
    public static function extractDarkColors(spine:Spine, slots:Array<String>, ?result:Array<Color>):Array<Color> {

        if (result == null) {
            result = [];
        }

        var funcs = [];

        for (i in 0...slots.length) {
            result[i] = Color.NONE;
            (i -> {

                funcs.push(info -> {
                    result[i] = Color.fromRGBFloat(
                        info.slot.darkColor.r,
                        info.slot.darkColor.g,
                        info.slot.darkColor.b
                    );
                });

                var slot = slots[i];
                spine.onUpdateSlotWithName(null, slot, funcs[i]);

            })(i);
        }

        spine.forceRender();

        for (i in 0...funcs.length) {
            spine.offUpdateSlotWithName(slots[i], funcs[i]);
        }

        return result;

    }

}
