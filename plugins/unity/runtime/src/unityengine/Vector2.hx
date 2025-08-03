package unityengine;

/**
 * Unity Vector2 struct extern binding for Ceramic.
 * Represents 2D vectors and points with x and y components.
 * 
 * Commonly used for 2D positions, directions, velocities,
 * and texture coordinates in Unity. This minimal binding
 * provides the properties and constructor used by Ceramic.
 */
@:native('UnityEngine.Vector2')
extern class Vector2 {

    /**
     * The x component of the vector.
     * Read-only in this binding.
     */
    var x(default, null):Single;

    /**
     * The y component of the vector.
     * Read-only in this binding.
     */
    var y(default, null):Single;

    /**
     * Creates a new Vector2 with the given x and y components.
     * 
     * @param x The x component
     * @param y The y component
     */
    function new(x:Single, y:Single);

}
