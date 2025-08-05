package unityengine;

/**
 * A texture that can be rendered to by cameras or used as a render target.
 * RenderTextures enable off-screen rendering for post-processing effects,
 * mirrors, minimaps, and render-to-texture operations.
 * 
 * In Ceramic's Unity backend, RenderTextures are used for:
 * - Implementing render-to-texture functionality
 * - Creating dynamic textures at runtime
 * - Post-processing effects and filters
 * - Capturing screen content
 * 
 * Key features:
 * - GPU-based rendering target
 * - Multiple format support (color, depth, stencil)
 * - Can be used as regular textures after rendering
 * - Supports anti-aliasing and HDR
 * 
 * Basic usage:
 * ```haxe
 * // RenderTextures are typically created and managed
 * // by Ceramic's backend for filters and effects
 * RenderTexture.active = myRenderTexture;
 * // Render operations here...
 * RenderTexture.active = null;
 * ```
 * 
 * @see Texture
 * @see Camera
 */
@:native('UnityEngine.RenderTexture')
extern class RenderTexture extends Texture {

    /**
     * The currently active render texture for drawing operations.
     * All rendering commands target this texture until changed.
     * 
     * Set to a RenderTexture before rendering to draw into it.
     * Set to null to render to screen/framebuffer.
     * 
     * Critical for render-to-texture operations:
     * ```haxe
     * var previous = RenderTexture.active;
     * RenderTexture.active = myRT;
     * // Render here
     * RenderTexture.active = previous; // Restore
     * ```
     */
    static var active:RenderTexture;

    /**
     * Width of the render texture in pixels.
     * Read-only after creation.
     * 
     * Should match the aspect ratio and resolution needs
     * of your rendering use case.
     */
    var width:Int;

    /**
     * Height of the render texture in pixels.
     * Read-only after creation.
     * 
     * Common sizes:
     * - Power of 2 for older hardware compatibility
     * - Screen resolution for full-screen effects
     * - Smaller for performance (e.g., 256x256 for minimaps)
     */
    var height:Int;

    /**
     * Texture filtering mode when sampling.
     * Affects visual quality when texture is scaled.
     * 
     * - Point: Pixelated/nearest neighbor (retro look)
     * - Bilinear: Smooth interpolation (default)
     * - Trilinear: Smooth with mipmaps
     * 
     * For pixel-perfect rendering, use Point filtering.
     * 
     * @see FilterMode
     */
    var filterMode:FilterMode;

}
