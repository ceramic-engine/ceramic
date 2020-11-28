package backend;

import unityengine.AudioSource;

using ceramic.Extensions;

class AudioHandleImpl {

    static var _audioSources:AudioSources = null;

    static var _handlesWithAudioSource:Array<AudioHandleImpl> = [];

    public var volume:Float = 0.5;

    public var pan:Float = 0;

    public var pitch:Float = 1;

    public var position:Float = 0;

    public var loop:Bool = false;

    public var resource:AudioResourceImpl = null;

    var audioSource:AudioSource = null;

    public function new(resource:AudioResourceImpl) {
        
        this.resource = resource;

        if (_audioSources == null) {
            _audioSources = new AudioSources(Main.monoBehaviour.gameObject);
            ceramic.App.app.onPostUpdate(null, _checkHandleAudioSources);
        }

    }

    static function _checkHandleAudioSources(delta:Float):Void {

        // Check every handle with audio source to see if
        // it still needs it. If not, recycle the audio source
        // so that it can be used with another handle
        for (i in 0..._handlesWithAudioSource.length) {
            var handle = _handlesWithAudioSource.unsafeGet(i);
            if (handle != null) {
                if (!handle.audioSource.isPlaying) {
                    _handlesWithAudioSource.unsafeSet(i, null);
                    handle.recycleAudioSource();
                }
            }
        }

    }

    inline function syncAudioSource():Void {

        if (audioSource == null) {
            audioSource = _audioSources.get();

            addHandleInCheckedList();

            audioSource.clip = resource.unityResource;
            audioSource.time = position;
            audioSource.panStereo = pan;
            audioSource.pitch = pitch;
            audioSource.volume = volume;
            audioSource.loop = loop;
        }

    }

    function recycleAudioSource():Void {

        var _source = audioSource;
        audioSource = null;
        _audioSources.recycle(_source);

    }

    inline function addHandleInCheckedList():Void {

        var didAddHandle = false;
        for (i in 0..._handlesWithAudioSource.length) {
            if (_handlesWithAudioSource.unsafeGet(i) == null) {
                _handlesWithAudioSource.unsafeSet(i, this);
                didAddHandle = true;
                break;
            }
        }
        if (!didAddHandle) {
            _handlesWithAudioSource.push(this);
        }

    }

/// Public API

    public function play():Void {

        syncAudioSource();
        audioSource.Play();

    }

    public function pause():Void {

        if (audioSource != null) {
            audioSource.Pause();
        }

    }

    public function resume():Void {

        syncAudioSource();
        audioSource.UnPause();

    }

    public function stop():Void {

        audioSource.Stop();

    }

}
