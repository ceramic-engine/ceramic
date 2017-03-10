package backend;

typedef LoadAudioOptions = {

    @:optional var stream:Bool;

}

abstract AudioResource(luxe.resource.Resource.AudioResource) from luxe.resource.Resource.AudioResource to luxe.resource.Resource.AudioResource {}

abstract AudioHandle(luxe.Audio.AudioHandle) from luxe.Audio.AudioHandle to luxe.Audio.AudioHandle {}

class Audio implements spec.Audio {

    public function new() {}

    inline public function load(name:String, ?options:LoadAudioOptions, done:AudioResource->Void):Void {

        Luxe.resources.load_audio(name, {
            is_stream: options != null ? options.stream : false
        })
        .then(function(audio:AudioResource) {
            done(audio);
        },
        function(_) {
            done(null);
        });

    } //load

    inline public function destroy(audio:AudioResource):Void {

        function(audio:luxe.resource.Resource.AudioResource) {

            audio.destroy(true);

        }(audio);

    } //unload

    inline public function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false):AudioHandle {

        return function(audio:luxe.resource.Resource.AudioResource) {

            var handle:AudioHandle = null;
            if (loop) {
                handle = Luxe.audio.play(audio.source, volume, true);
            } else {
                handle = Luxe.audio.loop(audio.source, volume, true);
            }

            Luxe.audio.pan(handle, pan);
            Luxe.audio.pitch(handle, pitch);
            Luxe.audio.position(handle, position);

            Luxe.audio.unpause(handle);

            return handle;

        }(audio);

    } //play

    inline public function pause(handle:AudioHandle):Void {

        Luxe.audio.pause(handle);

    } //pause

    inline public function resume(handle:AudioHandle):Void {

        Luxe.audio.unpause(handle);

    } //resume

    inline public function stop(handle:AudioHandle):Void {

        Luxe.audio.stop(handle);

    } //stop

    inline public function setVolume(handle:AudioHandle, volume:Float):Void {

        Luxe.audio.volume(handle, volume);

    } //setVolume

    inline public function setPitch(handle:AudioHandle, pitch:Float):Void {

        Luxe.audio.pitch(handle, pitch);

    } //setPitch

    inline public function setPosition(handle:AudioHandle, position:Float):Void {

        Luxe.audio.position(handle, position);

    } //setPosition

} //Audio