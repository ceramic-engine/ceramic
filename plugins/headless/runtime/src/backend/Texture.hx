package backend;

/**
 * Texture type definition for the headless backend.
 * 
 * This provides a type-safe wrapper around TextureImpl.
 * Textures represent 2D image data that can be used for
 * rendering sprites, UI elements, and other graphics.
 * 
 * In headless mode, textures maintain their dimensions
 * and properties but don't contain actual pixel data
 * since no rendering occurs.
 */
#if documentation

typedef Texture = TextureImpl;

#else

abstract Texture(TextureImpl) from TextureImpl to TextureImpl {}

#end
