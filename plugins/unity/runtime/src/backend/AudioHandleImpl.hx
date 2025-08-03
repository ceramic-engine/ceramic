package backend;

import unityengine.AudioSource;

using ceramic.Extensions;

#if !no_backend_docs
/**
 * Unity-specific implementation of an audio playback handle.
 * 
 * This class manages an individual audio playback instance, wrapping either:
 * - Unity's AudioSource component for standard playback
 * - MiniLoud audio system for buses with audio filters
 * 
 * The handle provides real-time control over playback parameters and manages
 * the lifecycle of Unity AudioSource components through an object pool to
 * minimize allocations and garbage collection.
 * 
 * Key features:
 * - Lazy AudioSource allocation (only when play() is called)
 * - Automatic AudioSource recycling when playback completes
 * - Support for audio bus routing with effects
 * - Alternative MiniLoud backend for filtered audio
 * 
 * @see backend.Audio The main audio backend that creates handles
 * @see AudioSources The AudioSource pool manager
 * @see MiniLoudAudio Alternative audio system for filtered playback
 */
#end
class AudioHandleImpl {

    #if !no_backend_docs
    /** Shared AudioSources pool manager */
    #end
    static var _audioSources:AudioSources = null;

    #if !no_backend_docs
    /** Active handles that have AudioSource components allocated */
    #end
    static var _handlesWithAudioSource:Array<AudioHandleImpl> = [];

    #if !no_backend_docs
    /**
     * Audio volume level (0.0 to 1.0).
     * Changes are immediately applied to the active AudioSource.
     * Default: 0.5
     */
    #end
    public var volume(default, set):Float = 0.5;
    function set_volume(volume:Float):Float {
        if (this.volume != volume) {
            this.volume = volume;
            if (audioSource != null)
                audioSource.volume = volume;
        }
        return volume;
    }

    #if !no_backend_docs
    /**
     * Stereo pan position (-1.0 = left, 0.0 = center, 1.0 = right).
     * Changes are immediately applied to the active AudioSource.
     * Default: 0.0 (center)
     */
    #end
    public var pan(default, set):Float = 0;
    function set_pan(pan:Float):Float {
        if (this.pan != pan) {
            this.pan = pan;
            if (audioSource != null)
                audioSource.panStereo = pan;
        }
        return pan;
    }

    #if !no_backend_docs
    /**
     * Pitch multiplier for playback speed (0.5 = half speed, 2.0 = double speed).
     * Also affects the pitch of the audio. Values below 0 play audio backwards.
     * Default: 1.0 (normal speed)
     */
    #end
    public var pitch(default, set):Float = 1;
    function set_pitch(pitch:Float):Float {
        if (this.pitch != pitch) {
            this.pitch = pitch;
            if (audioSource != null)
                audioSource.pitch = pitch;
        }
        return pitch;
    }

    #if !no_backend_docs
    /** Flag to prevent recursive updates when syncing position */
    #end
    var updateAudioSourceOnSetPosition:Bool = true;

    #if !no_backend_docs
    /**
     * Current playback position in seconds.
     * Can be set to seek to a specific time.
     * Clamped to prevent Unity errors at exact end position.
     */
    #end
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

    #if !no_backend_docs
    /**
     * Whether to loop playback when reaching the end.
     * Default: false
     */
    #end
    public var loop:Bool = false;

    #if !no_backend_docs
    /** The audio resource being played */
    #end
    public var resource:AudioResourceImpl = null;

    #if !no_backend_docs
    /** Unity AudioSource component (null until play() is called) */
    #end
    var audioSource:AudioSource = null;

    #if !no_backend_docs
    /** Whether to use MiniLoud instead of Unity AudioSource (for filtered buses) */
    #end
    var useMiniLoud:Bool = false;

    #if !no_backend_docs
    /** Handle for MiniLoud playback (when useMiniLoud is true) */
    #end
    var miniLoudHandle:MiniLoudAudio.MiniLoudAudioHandle = null;

    #if !no_backend_docs
    /** Cached audio length in seconds */
    #end
    var length:Float = 0;

    #if !no_backend_docs
    /** Audio bus index for routing */
    #end
    var busIndex:Int = 0;

    #if !no_backend_docs
    /** Current pause state */
    #end
    var paused:Bool = false;

    #if !no_backend_docs
    /**
     * Create a new audio handle for the given resource.
     * @param resource The audio resource to play
     * @param busIndex The audio bus for routing (0 = default)
     * @param useMiniLoud Whether to use MiniLoud backend (for filtered buses)
     */
    #end
    public function new(resource:AudioResourceImpl, busIndex:Int, useMiniLoud:Bool) {

        this.resource = resource;
        this.busIndex = busIndex;
        this.length = resource.unityResource.length;

        this.useMiniLoud = useMiniLoud;

        if (_audioSources == null) {
            _audioSources = AudioSources.shared;
        }

    }

    #if !no_backend_docs
    /**
     * Called each frame to check if audio sources can be recycled.
     * This is registered with the app update loop by AudioSources.
     * Completed playbacks have their AudioSource components returned to the pool.
     * @param delta Time since last frame (unused)
     */
    #end
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

    #if !no_backend_docs
    /**
     * Ensure an AudioSource is allocated and synchronized with current parameters.
     * Called before playback operations to lazily allocate from the pool.
     */
    #end
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

    #if !no_backend_docs
    /**
     * Return the AudioSource to the pool for reuse.
     * Called when playback completes or is stopped.
     */
    #end
    function recycleAudioSource():Void {

        var _source = audioSource;
        audioSource = null;
        _audioSources.recycle(_source);

    }

    #if !no_backend_docs
    /**
     * Add this handle to the list of active handles.
     * These are checked each frame to detect playback completion.
     * Reuses null slots in the array to minimize allocations.
     */
    #end
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

    #if !no_backend_docs
    /**
     * Start or restart audio playback.
     * Allocates an AudioSource from the pool if needed.
     * For filtered buses, uses MiniLoud instead of Unity AudioSource.
     */
    #end
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

    #if !no_backend_docs
    /**
     * Pause audio playback.
     * The AudioSource is kept allocated to preserve position.
     */
    #end
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

    #if !no_backend_docs
    /**
     * Resume paused audio playback.
     * Ensures AudioSource is allocated if it was recycled.
     */
    #end
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

    #if !no_backend_docs
    /**
     * Stop audio playback and reset position to beginning.
     * The AudioSource will be recycled on the next frame.
     */
    #end
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
