package unityengine;

/**
 * Unity FilterMode enum extern binding for Ceramic.
 * Controls texture sampling quality when textures are scaled.
 * 
 * Filter mode determines how pixel colors are calculated when
 * a texture is displayed at a different size than its native
 * resolution, affecting both performance and visual quality.
 */
@:native('UnityEngine.FilterMode')
extern class FilterMode {

    /**
     * Point filtering (nearest-neighbor sampling).
     * Fastest but produces pixelated results when scaled.
     * Best for pixel art or when crisp pixels are desired.
     * No interpolation between pixels.
     */
    static var Point:FilterMode;

    /**
     * Bilinear filtering.
     * Smoothly interpolates between adjacent pixels.
     * Good balance of quality and performance for most textures.
     * Blends 4 nearest pixels for smooth scaling.
     */
    static var Bilinear:FilterMode;

    /**
     * Trilinear filtering.
     * Like bilinear but also blends between mipmap levels.
     * Best quality, especially for textures viewed at angles.
     * Slightly more expensive than bilinear filtering.
     */
    static var Trilinear:FilterMode;

}