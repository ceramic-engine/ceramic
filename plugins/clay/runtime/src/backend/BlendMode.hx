package backend;

/**
 * Type alias for the Clay engine's blend mode enumeration.
 * 
 * Blend modes determine how pixels are combined when drawing one visual
 * on top of another. This typedef maps to Clay's internal BlendMode type
 * which provides standard blending operations like:
 * - Normal (alpha blending)
 * - Add (additive blending)
 * - Multiply (multiplicative blending)
 * - Screen
 * - And other Photoshop-style blend modes
 * 
 * The actual blend mode implementation uses OpenGL/WebGL blend functions
 * to achieve the desired pixel combination effects.
 * 
 * @see ceramic.Blending For the high-level blending API
 * @see Draw.setBlendMode() For applying blend modes during rendering
 */
typedef BlendMode = clay.Types.BlendMode;
