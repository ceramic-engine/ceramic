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

    var useMiniLoud:Bool = false;

    var miniLoudHandle:MiniLoudAudio.MiniLoudAudioHandle = null;

    var length:Float = 0;

    var busIndex:Int = 0;

    var paused:Bool = false;

    public function new(resource:AudioResourceImpl, busIndex:Int) {

        this.resource = resource;
        this.busIndex = busIndex;
        length = resource.unityResource.length;

        useMiniLoud = #if ceramic_unity_no_miniloud false #else true #end; // Could be per-bus later, or not if miniloud works perfectly fine

        if (_audioSources == null) {
            _audioSources = AudioSources.shared;
        }

    }

    static function _checkHandleAudioSources(delta:Float):Void {

        // Check every handle with audio source to see if
        // it still needs it. If not, recycle the audio source
        // so that it can be used with another handle
        for (i in 0..._handlesWithAudioSource.length) {
            var handle = _handlesWithAudioSource.unsafeGet(i);
            if (handle != null) {
                if (!handle.useMiniLoud) {
                    if (handle.audioSource == null) {
                        // Can happen if destroyed after switching from play mode to edit mode
                        _handlesWithAudioSource.unsafeSet(i, null);
                    }
                    else {
                        handle.updateAudioSourceOnSetPosition = false;
                        handle.position = handle.audioSource.time;
                        handle.updateAudioSourceOnSetPosition = true;
                        if (!handle.paused && !handle.audioSource.isPlaying) {
                            _handlesWithAudioSource.unsafeSet(i, null);
                            handle.recycleAudioSource();
                        }
                    }
                }
            }
        }

    }

    inline function syncAudioSource():Void {

        if (!useMiniLoud) {
            if (audioSource == null) {
                audioSource = _audioSources.get();

                addHandleInCheckedList();

                audioSource.clip = resource.unityResource;
                audioSource.time = position;
                audioSource.panStereo = pan;
                audioSource.pitch = pitch;
                audioSource.volume = volume;
                audioSource.loop = loop;

                final bus = _audioSources.bus(busIndex);
                if (bus != null) {
                    audioSource.outputAudioMixerGroup = bus.mixerGroup;
                }
            }
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

        paused = false;
        if (!useMiniLoud) {
            syncAudioSource();
            audioSource.Play();
        }
        else {
            miniLoudHandle = _audioSources.miniLoudObject(busIndex).miniLoudAudio.Play(
                resource.miniLoudAudioResource,
                volume,
                pan,
                pitch,
                position,
                loop
            );
        }

    }

    public function pause():Void {

        paused = true;
        if (!useMiniLoud) {
            if (audioSource != null) {
                audioSource.Pause();
            }
        }
        else {
            if (miniLoudHandle != null) {
                _audioSources.miniLoudObject(busIndex).miniLoudAudio.Pause(miniLoudHandle);
            }
        }

    }

    public function resume():Void {

        paused = false;
        if (!useMiniLoud) {
            syncAudioSource();
            audioSource.UnPause();
        }
        else {
            if (miniLoudHandle != null) {
                _audioSources.miniLoudObject(busIndex).miniLoudAudio.Resume(miniLoudHandle);
            }
        }

    }

    public function stop():Void {

        paused = false;
        position = 0;
        if (!useMiniLoud) {
            if (audioSource != null) {
                audioSource.Stop();
            }
        }
        else {
            if (miniLoudHandle != null) {
                _audioSources.miniLoudObject(busIndex).miniLoudAudio.Stop(miniLoudHandle);
            }
        }

    }

}
