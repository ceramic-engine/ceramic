package backend;

/**
 * Shader type definition for the headless backend.
 * 
 * This provides a type-safe wrapper around ShaderImpl.
 * Shaders define how vertices are processed and pixels are colored
 * during rendering. In headless mode, shaders maintain their
 * attribute definitions and interface for API compatibility
 * but don't perform actual GPU compilation or rendering.
 */
abstract Shader(ShaderImpl) from ShaderImpl to ShaderImpl {}
