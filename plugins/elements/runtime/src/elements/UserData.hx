package elements;

import ceramic.Color;
import ceramic.ReadOnlyArray;
import ceramic.ReadOnlyMap;
import ceramic.Shortcuts.*;
import tracker.Model;

/**
 * Persistent user data model for storing application-specific user preferences and state.
 * 
 * This class extends Model to provide serializable storage for user settings,
 * window configurations, and other persistent application data. It manages
 * window positioning/sizing data and color palette preferences with built-in
 * methods for manipulation.
 * 
 * ## Features
 * 
 * - Persistent window data storage with automatic serialization
 * - Color palette management with add/remove/move operations
 * - Color picker mode preferences (HSLuv vs HSB)
 * - Automatic duplicate prevention for palette colors
 * 
 * ## Usage Examples
 * 
 * ```haxe
 * // Create or load user data
 * var userData = new UserData();
 * 
 * // Add colors to palette
 * userData.addPaletteColor(Color.RED);
 * userData.addPaletteColor(Color.BLUE, false); // Allow duplicates
 * 
 * // Manage color palette
 * userData.movePaletteColor(0, 2); // Move first color to third position
 * userData.removePaletteColor(1);  // Remove color at index 1
 * 
 * // Configure color picker
 * userData.colorPickerHsluv = true; // Use HSLuv color space
 * ```
 * 
 * @see Model
 * @see WindowData
 * @see Color
 */
class UserData extends Model {

    /**
     * Creates a new UserData instance.
     * Initializes the model with default values for all properties.
     */
    public function new() {

        super();

    }

/// Windows data

    /**
     * Storage for window-specific data mapped by window identifiers.
     * 
     * Each window can have its own persistent data including position, size,
     * visibility state, and other window-specific preferences. The data is
     * automatically serialized and restored between application sessions.
     * 
     * @see WindowData
     */
    @serialize public var windowsData:ReadOnlyMap<String,WindowData> = new Map();

/// Colors

    /**
     * Whether to use HSLuv color space in color pickers.
     * 
     * When true, color pickers will use the HSLuv color space which provides
     * perceptually uniform lightness. When false, traditional HSB/HSV color
     * space is used. This preference affects the behavior of color selection
     * interfaces throughout the application.
     * 
     * @default false
     */
    @serialize public var colorPickerHsluv:Bool = false;

    /**
     * Array of colors in the user's custom color palette.
     * 
     * This palette allows users to save frequently used colors for quick access
     * in color pickers and other color selection interfaces. Colors can be added,
     * removed, and reordered using the provided methods.
     * 
     * @see addPaletteColor
     * @see removePaletteColor
     * @see movePaletteColor
     */
    @serialize public var paletteColors:ReadOnlyArray<Color> = [];

    /**
     * Adds a color to the user's palette.
     * 
     * Appends the specified color to the end of the palette array. By default,
     * duplicate colors are not allowed and will be rejected with a warning.
     * 
     * @param color The color to add to the palette
     * @param forbidDuplicate Whether to prevent adding duplicate colors (default: true)
     * 
     * ## Examples
     * ```haxe
     * // Add a unique color (default behavior)
     * userData.addPaletteColor(Color.RED);
     * 
     * // Allow duplicate colors
     * userData.addPaletteColor(Color.RED, false);
     * ```
     */
    public function addPaletteColor(color:Color, forbidDuplicate:Bool = true):Void {

        var prevPaletteColors = this.paletteColors;

        // Ensure the color is not already listed if needed
        if (forbidDuplicate) {
            for (i in 0...prevPaletteColors.length) {
                if (color == prevPaletteColors[i]) {
                    log.warning('Cannot add color $color in palette because it already exists. Ignoring.');
                    return;
                }
            }
        }

        // Add color
        var paletteColors = [].concat(prevPaletteColors.original);
        paletteColors.push(color);
        this.paletteColors = cast paletteColors;

    }

    /**
     * Moves a color from one position to another in the palette.
     * 
     * Reorders the palette by moving the color at the specified source index
     * to the target index. All other colors shift positions accordingly.
     * 
     * @param fromIndex The current index of the color to move
     * @param toIndex The target index where the color should be moved
     * 
     * ## Examples
     * ```haxe
     * // Move the first color to the third position
     * userData.movePaletteColor(0, 2);
     * 
     * // Move the last color to the beginning
     * var lastIndex = userData.paletteColors.length - 1;
     * userData.movePaletteColor(lastIndex, 0);
     * ```
     */
    public function movePaletteColor(fromIndex:Int, toIndex:Int):Void {

        var paletteColors = [].concat(this.paletteColors.original);

        var colorToMove = paletteColors[fromIndex];

        paletteColors.splice(fromIndex, 1);
        paletteColors.insert(toIndex, colorToMove);

        this.paletteColors = cast paletteColors;

    }

    /**
     * Removes a color from the palette at the specified index.
     * 
     * Deletes the color at the given index from the palette array.
     * All subsequent colors shift down by one position.
     * 
     * @param index The index of the color to remove
     * 
     * ## Examples
     * ```haxe
     * // Remove the first color
     * userData.removePaletteColor(0);
     * 
     * // Remove the last color
     * var lastIndex = userData.paletteColors.length - 1;
     * userData.removePaletteColor(lastIndex);
     * ```
     */
    public function removePaletteColor(index:Int):Void {

        var paletteColors = [].concat(this.paletteColors.original);

        paletteColors.splice(index, 1);

        this.paletteColors = cast paletteColors;

    }


}
