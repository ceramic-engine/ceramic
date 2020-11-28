package unityengine;

@:native('UnityEngine.AudioDataLoadState')
extern class AudioDataLoadState {

    static var Unloaded:AudioDataLoadState;

    static var Loading:AudioDataLoadState;

    static var Loaded:AudioDataLoadState;

    static var Failed:AudioDataLoadState;

}