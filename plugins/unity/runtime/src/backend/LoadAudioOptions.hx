package backend;

typedef LoadAudioOptions = {

    @:optional var immediate:ceramic.Immediate;

    @:optional var loadMethod:ceramic.AssetsLoadMethod;

    @:optional var stream:Bool;

}
