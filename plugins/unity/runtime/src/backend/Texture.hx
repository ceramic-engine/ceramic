package backend;

#if !no_backend_docs
/**
 * Abstract type representing a Unity texture.
 * Wraps the concrete TextureImpl implementation to provide type safety.
 * Used throughout the rendering system for GPU texture resources.
 * 
 * @see TextureImpl for the concrete implementation
 * @see Textures for texture management
 */
#end
#if documentation

typedef Texture = TextureImpl;

#else

abstract Texture(TextureImpl) from TextureImpl to TextureImpl {}

#end
