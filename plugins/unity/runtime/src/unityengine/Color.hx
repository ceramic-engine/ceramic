package unityengine;

/**
 * Unity Color struct extern binding for Ceramic.
 * Represents RGBA color values with components in the 0-1 range.
 * 
 * Unity uses floating-point color values where each component
 * (red, green, blue, alpha) ranges from 0.0 to 1.0.
 * This binding provides the constructor needed by the Ceramic backend.
 */
@:native('UnityEngine.Color')
extern class Color {

    /**
     * Creates a new Color with the specified RGBA values.
     * All components should be in the range 0.0 to 1.0.
     * Values outside this range are allowed but may produce
     * unexpected results in rendering.
     * 
     * @param r Red component (0.0 = no red, 1.0 = full red)
     * @param g Green component (0.0 = no green, 1.0 = full green)
     * @param b Blue component (0.0 = no blue, 1.0 = full blue)
     * @param a Alpha component (0.0 = transparent, 1.0 = opaque)
     */
    function new(r:Single, g:Single, b:Single, a:Single);

}
