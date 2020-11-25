package backend;

import unityengine.AudioClip;

class AudioResourceImpl {

    public var path:String;

    public var unityResource:AudioClip;

    public function new(path:String, unityResource:AudioClip) {

        this.path = path;
        this.unityResource = unityResource;

    }

}
