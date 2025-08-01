package ceramic;

/**
 * Texture filtering modes that control how pixels are sampled when textures are scaled.
 * 
 * Texture filtering determines how the GPU interpolates pixel values when a texture
 * is displayed at a different size than its original resolution.
 * 
 * @see Texture.filter
 * @see RenderTexture.textureFilter
 */
enum TextureFilter {

    /**
     * Linear filtering (bilinear interpolation).
     * 
     * Smoothly blends between adjacent pixels when scaling.
     * Best for:
     * - Photographs and realistic textures
     * - Smooth gradients
     * - UI elements that need to scale smoothly
     * - General purpose textures
     * 
     * Produces smooth but potentially blurry results when upscaling.
     */
    LINEAR;

    /**
     * Nearest neighbor filtering (point sampling).
     * 
     * Uses the color of the nearest pixel without blending.
     * Best for:
     * - Pixel art that needs to stay crisp
     * - Retro/8-bit style graphics
     * - Text rendered to texture
     * - Any art where pixel-perfect accuracy is important
     * 
     * Produces sharp but potentially pixelated results when scaling.
     */
    NEAREST;

}
