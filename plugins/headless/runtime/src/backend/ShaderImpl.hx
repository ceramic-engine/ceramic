package backend;

/**
 * Shader implementation for the headless backend.
 * 
 * This class represents a compiled shader program in the headless environment.
 * Unlike other backends, this doesn't contain actual GPU shader code or
 * perform compilation. Instead, it maintains shader metadata like custom
 * attributes for API compatibility and vertex buffer calculations.
 * 
 * The shader implementation is used by the draw system to determine
 * vertex buffer layout and attribute sizing.
 */
class ShaderImpl {
    /**
     * Array of custom shader attributes defined by this shader.
     * These attributes affect vertex buffer layout and are used
     * to calculate buffer sizing even in headless mode.
     */
    public var customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute> = null;
    
    /**
     * Creates a new shader implementation.
     * 
     * @param customAttributes Optional array of custom shader attributes
     */
    public function new(?customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>) {
        this.customAttributes = customAttributes;
    }
}
