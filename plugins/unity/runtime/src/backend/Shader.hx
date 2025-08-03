package backend;

#if !no_backend_docs
/**
 * Abstract type representing a Unity shader program.
 * Wraps the concrete ShaderImpl implementation to provide type safety.
 * Used by the rendering system to apply GPU effects during drawing.
 * 
 * @see ShaderImpl for the concrete implementation
 * @see Shaders for shader management
 */
#end
abstract Shader(ShaderImpl) from ShaderImpl to ShaderImpl {}
