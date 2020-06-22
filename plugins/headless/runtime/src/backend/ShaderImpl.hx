package backend;

class ShaderImpl {
    public var customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute> = null;
    public function new(?customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>) {
        this.customAttributes = customAttributes;
    }
}
