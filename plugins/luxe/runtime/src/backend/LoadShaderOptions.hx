package backend;

typedef LoadShaderOptions = {
    var fragId: String;
    var vertId: String;
    @:optional var noDefaultUniforms: Bool;
}
