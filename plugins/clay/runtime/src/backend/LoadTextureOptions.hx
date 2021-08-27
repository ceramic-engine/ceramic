package backend;

typedef LoadTextureOptions = {

    @:optional var loadMethod:ceramic.AssetsLoadMethod;

    @:optional var immediate:ceramic.Immediate;

    @:optional var premultiplyAlpha:Bool;

}
