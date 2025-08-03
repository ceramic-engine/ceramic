package unityengine;

/**
 * Unity Texture class extern binding for Ceramic.
 * Base class for all texture types in Unity (Texture2D, RenderTexture, etc).
 * 
 * This binding exposes the wrap mode properties that control how
 * textures behave when UV coordinates go outside the 0-1 range.
 * These are essential for controlling texture tiling and clamping.
 */
@:native('UnityEngine.Texture')
extern class Texture extends Object {

    /**
     * Texture wrap mode for the U coordinate (horizontal).
     * Controls behavior when texture coordinates exceed 0-1 range horizontally.
     * Common values: Repeat (tile), Clamp (stretch edge pixels), Mirror.
     */
    var wrapModeU:TextureWrapMode;

    /**
     * Texture wrap mode for the V coordinate (vertical).
     * Controls behavior when texture coordinates exceed 0-1 range vertically.
     * Common values: Repeat (tile), Clamp (stretch edge pixels), Mirror.
     */
    var wrapModeV:TextureWrapMode;

    /**
     * Texture wrap mode for the W coordinate (depth).
     * Only relevant for 3D textures. Controls behavior for the depth dimension.
     * For 2D textures, this setting has no effect.
     */
    var wrapModeW:TextureWrapMode;

}
