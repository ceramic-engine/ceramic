package backend;

import unityengine.AudioSource;

using ceramic.Extensions;

class AudioHandleImpl {

    static var _audioSources:AudioSources = null;

    static var _handlesWithAudioSource:Array<AudioHandleImpl> = [];

    public var volume(default, set):Float = 0.5;
    function set_volume(volume:Float):Float {
        if (this.volume != volume) {
            this.volume = volume;
            if (audioSource != null)
                audioSource.volume = volume;
        }
        return volume;
    }

    public var pan(default, set):Float = 0;
    function set_pan(pan:Float):Float {
        if (this.pan != pan) {
            this.pan = pan;
            if (audioSource != null)
                audioSource.panStereo = pan;
        }
        return pan;
    }

    public var pitch(default, set):Float = 1;
    function set_pitch(pitch:Float):Float {
        if (this.pitch != pitch) {
            this.pitch = pitch;
            if (audioSource != null)
                audioSource.pitch = pitch;
        }
        return pitch;
    }

    var updateAudioSourceOnSetPosition:Bool = true;

    public var position(default, set):Float = 0;
    function set_position(position:Float):Float {
        if (this.position != position) {
            position = Math.min(position, length - 0.00001); // Never set exactly to "length" because Unity doesn't like it
            this.position = position;
            if (updateAudioSourceOnSetPosition && audioSource != null) {
                audioSource.time = position;
            }
        }
        return position;
    }

    public var loop:Bool = false;

    public var resource:AudioResourceImpl = null;

    var audioSource:AudioSource = null;

    var length:Float = 0;

    public function new(resource:AudioResourceImpl) {
        
        this.resource = resource;
        length = resource.unityResource.length;

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
                handle.updateAudioSourceOnSetPosition = false;
                handle.position = handle.audioSource.time;
                handle.updateAudioSourceOnSetPosition = true;
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

        position = 0;
        if (audioSource != null) {
            audioSource.Stop();
        }

    }

}
