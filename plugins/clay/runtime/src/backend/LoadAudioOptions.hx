package backend;

typedef LoadAudioOptions = {

    @:optional var loadMethod:ceramic.AssetsLoadMethod;

    @:optional var immediate:ceramic.Immediate;

    @:optional var stream:Bool;

}
