package unityengine;

/**
 * Unity Rect struct extern binding for Ceramic.
 * Represents a 2D rectangle defined by position and size.
 * 
 * Used throughout Unity for GUI positioning, texture coordinates,
 * viewport definitions, and other 2D spatial data. The rectangle
 * is defined by its bottom-left corner (x,y) and dimensions.
 */
@:native('UnityEngine.Rect')
extern class Rect {

    /**
     * Creates a new Rect with the specified position and dimensions.
     * 
     * @param x The x coordinate of the rectangle's bottom-left corner
     * @param y The y coordinate of the rectangle's bottom-left corner
     * @param width The width of the rectangle
     * @param height The height of the rectangle
     */
    function new(x:Single, y:Single, width:Single, height:Single);

    /**
     * The x coordinate of the rectangle's bottom-left corner.
     * In screen space, this is typically pixels from the left edge.
     */
    var x:Single;

    /**
     * The y coordinate of the rectangle's bottom-left corner.
     * In screen space, this is typically pixels from the bottom edge.
     */
    var y:Single;

    /**
     * The width of the rectangle in the same units as x.
     * Must be positive for a valid rectangle.
     */
    var width:Single;

    /**
     * The height of the rectangle in the same units as y.
     * Must be positive for a valid rectangle.
     */
    var height:Single;

}
