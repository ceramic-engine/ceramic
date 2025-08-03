package unityengine;

/**
 * Unity TextureWrapMode enum extern binding for Ceramic.
 * Controls how texture coordinates outside the 0-1 range are handled.
 * 
 * This determines the behavior when UV coordinates exceed the
 * texture boundaries, enabling effects like tiling, clamping,
 * or mirroring.
 */
@:native('UnityEngine.TextureWrapMode')
extern class TextureWrapMode {

    /**
     * Tiles the texture, repeating it continuously.
     * UV coordinates wrap around: 1.5 becomes 0.5, 2.0 becomes 0.0, etc.
     * Most common mode for tiling textures like floors or walls.
     */
    static var Repeat:TextureWrapMode;

    /**
     * Clamps texture coordinates to the 0-1 range.
     * Pixels outside this range use the edge pixel color.
     * Useful for UI elements or when you want to avoid texture bleeding.
     */
    static var Clamp:TextureWrapMode;

    /**
     * Tiles the texture with mirroring on each repetition.
     * Creates a seamless pattern by flipping alternating tiles.
     * UV 0-1 normal, 1-2 mirrored, 2-3 normal, etc.
     */
    static var Mirror:TextureWrapMode;

    /**
     * Mirrors the texture once, then clamps.
     * UV 0-1 shows normal texture, 1+ shows mirrored edge pixels.
     * Useful for symmetric effects without full tiling.
     */
    static var MirrorOnce:TextureWrapMode;

}