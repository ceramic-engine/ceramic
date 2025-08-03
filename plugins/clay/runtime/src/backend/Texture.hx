package backend;

/**
 * Represents a GPU texture resource in the Clay backend.
 * 
 * Textures are image data stored in GPU memory that can be used for:
 * - Rendering sprites and visual elements
 * - Texture mapping on 3D models
 * - Render targets for off-screen rendering
 * - Post-processing effects
 * 
 * This type wraps Clay's internal texture representation and provides
 * implicit conversions for seamless integration. The actual texture
 * format and capabilities depend on the graphics API (OpenGL/WebGL).
 * 
 * Textures are managed by the backend and automatically cleaned up
 * when no longer referenced.
 * 
 * @see ceramic.Texture For the high-level texture API
 * @see Textures For the texture loading subsystem
 */
#if documentation

typedef Texture = clay.graphics.Texture;

#else

abstract Texture(clay.graphics.Texture) from clay.graphics.Texture to clay.graphics.Texture {}

#end
