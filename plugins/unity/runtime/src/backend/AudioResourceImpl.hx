package backend;

import unityengine.AudioClip;

class AudioResourceImpl {

    public var path:String;

    public var unityResource:AudioClip;

    public var miniLoudAudioResource:MiniLoudAudio.MiniLoudAudioResource;

    public function new(path:String, unityResource:AudioClip) {

        this.path = path;
        this.unityResource = unityResource;
        this.miniLoudAudioResource = MiniLoudUnity.AudioResourceFromAudioClip(unityResource);

    }

}
