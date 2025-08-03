package backend;

import unityengine.AudioClip;

#if !no_backend_docs
/**
 * Unity-specific implementation of an audio resource.
 * 
 * This class wraps Unity's AudioClip along with additional metadata needed
 * for Ceramic's audio system. It maintains references to both Unity's native
 * audio format and MiniLoud's format for compatibility with different playback
 * systems (standard Unity AudioSource vs filtered MiniLoud playback).
 * 
 * Audio resources are cached and reference-counted by the Audio backend to
 * avoid loading the same audio file multiple times. The path is used as the
 * cache key to identify resources.
 * 
 * @see backend.Audio Manages the lifecycle of audio resources
 * @see AudioHandleImpl Uses these resources for playback
 * @see MiniLoudAudio Alternative audio system for filtered playback
 */
#end
class AudioResourceImpl {

    #if !no_backend_docs
    /**
     * The path or identifier for this audio resource.
     * Used as a cache key to avoid duplicate loading.
     * For file-based resources, this is the file path.
     * For generated resources, this is a unique identifier.
     */
    #end
    public var path:String;

    #if !no_backend_docs
    /**
     * The Unity AudioClip containing the actual audio data.
     * This is used for standard Unity AudioSource playback.
     */
    #end
    public var unityResource:AudioClip;

    #if !no_backend_docs
    /**
     * MiniLoud-compatible version of the audio resource.
     * Created automatically from the AudioClip for buses that use filters.
     * MiniLoud provides more advanced DSP capabilities than Unity's built-in audio.
     */
    #end
    public var miniLoudAudioResource:MiniLoudAudio.MiniLoudAudioResource;

    #if !no_backend_docs
    /**
     * Create a new audio resource wrapping a Unity AudioClip.
     * Automatically creates the MiniLoud-compatible version.
     * 
     * @param path The path or identifier for this resource
     * @param unityResource The loaded Unity AudioClip
     */
    #end
    public function new(path:String, unityResource:AudioClip) {

        this.path = path;
        this.unityResource = unityResource;
        this.miniLoudAudioResource = MiniLoudUnity.AudioResourceFromAudioClip(unityResource);

    }

}
