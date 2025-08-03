package unityengine;

/**
 * Unity Vector4 struct extern binding for Ceramic.
 * Represents 4D vectors with x, y, z, and w components.
 * 
 * Commonly used for shader parameters, homogeneous coordinates,
 * and RGBA color values in certain contexts. This minimal binding
 * provides the properties and constructor used by Ceramic.
 */
@:native('UnityEngine.Vector4')
extern class Vector4 {

    /**
     * The x component of the vector.
     * First component in the 4D vector.
     * Read-only in this binding.
     */
    var x(default, null):Single;

    /**
     * The y component of the vector.
     * Second component in the 4D vector.
     * Read-only in this binding.
     */
    var y(default, null):Single;

    /**
     * The z component of the vector.
     * Third component in the 4D vector.
     * Read-only in this binding.
     */
    var z(default, null):Single;

    /**
     * The w component of the vector.
     * Fourth component, often used for homogeneous coordinates
     * or alpha channel in color representations.
     * Read-only in this binding.
     */
    var w(default, null):Single;

    /**
     * Creates a new Vector4 with the given components.
     * 
     * @param x The x component
     * @param y The y component
     * @param z The z component
     * @param w The w component
     */
    function new(x:Single, y:Single, z:Single, w:Single);

}
