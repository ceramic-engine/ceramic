package backend;

/**
 * Abstract type representing a compiled GPU shader program in the Clay backend.
 * 
 * This is a lightweight wrapper around ShaderImpl that provides type safety
 * while allowing implicit conversions. Shaders contain compiled vertex and
 * fragment shader code that runs on the GPU to transform vertices and
 * calculate pixel colors.
 * 
 * In the Clay backend, shaders are managed by the Shaders subsystem and
 * cached to avoid recompilation. The actual shader implementation varies
 * by platform (OpenGL, WebGL, etc.).
 * 
 * @see ShaderImpl The underlying implementation class
 * @see Shaders The shader management subsystem
 * @see ceramic.Shader For the high-level shader API
 */
abstract Shader(ShaderImpl) from ShaderImpl to ShaderImpl {}
