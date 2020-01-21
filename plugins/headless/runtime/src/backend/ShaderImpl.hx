package backend;

class ShaderImpl {
    public var customAttributes:ceramic.ImmutableArray<ceramic.ShaderAttribute> = null;
    public function new(?customAttributes:ceramic.ImmutableArray<ceramic.ShaderAttribute>) {
        this.customAttributes = customAttributes;
    }
}
