package unityengine;

/**
 * Unity Vector3 struct extern binding for Ceramic.
 * Represents 3D vectors and points with x, y, and z components.
 * 
 * Used throughout Unity for 3D positions, directions, scales,
 * and other spatial data. This minimal binding provides the
 * properties and constructor needed by the Ceramic backend.
 */
@:native('UnityEngine.Vector3')
extern class Vector3 {

    /**
     * The x component of the vector.
     * Typically represents left/right in world space.
     * Read-only in this binding.
     */
    var x(default, null):Single;

    /**
     * The y component of the vector.
     * Typically represents up/down in world space.
     * Read-only in this binding.
     */
    var y(default, null):Single;

    /**
     * The z component of the vector.
     * Typically represents forward/backward in world space.
     * Read-only in this binding.
     */
    var z(default, null):Single;

    /**
     * Creates a new Vector3 with the given x, y, and z components.
     * 
     * @param x The x component
     * @param y The y component
     * @param z The z component
     */
    function new(x:Single, y:Single, z:Single);

}
