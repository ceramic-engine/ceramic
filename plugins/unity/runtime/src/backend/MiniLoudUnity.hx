package backend;

import unityengine.AudioClip;
import unityengine.AudioSource;
import unityengine.MonoBehaviour;

#if !no_backend_docs
/**
 * Unity MonoBehaviour component that bridges MiniLoud with Unity's audio system.
 * 
 * This component is attached to GameObjects that need MiniLoud audio processing.
 * It provides the integration between Unity's audio pipeline and MiniLoud's
 * advanced audio features, enabling real-time DSP effects on audio buses.
 * 
 * The component:
 * - Creates and manages a MiniLoud audio instance
 * - Provides an AudioSource for Unity integration
 * - Handles audio format conversion between Unity and MiniLoud
 * - Processes audio callbacks from Unity's audio thread
 * 
 * @see backend.AudioSources Creates these components for filtered buses
 * @see MiniLoudAudio The audio engine this component wraps
 */
#end
@:native('MiniLoudUnity')
extern class MiniLoudUnity extends MonoBehaviour {

    #if !no_backend_docs
    /**
     * The MiniLoud audio engine instance managed by this component.
     * Handles all audio processing and mixing operations.
     */
    #end
    var miniLoudAudio:MiniLoudAudio;

    #if !no_backend_docs
    /**
     * Unity AudioSource component used for audio output.
     * Routes MiniLoud's processed audio to Unity's audio mixer.
     */
    #end
    var audioSource:AudioSource;

    #if !no_backend_docs
    /**
     * Number of audio channels (1=mono, 2=stereo).
     * Must match the audio format used by the bus.
     */
    #end
    var channels:Int;

    #if !no_backend_docs
    /**
     * Audio sample rate in Hz (e.g., 44100, 48000).
     * Must match Unity's audio settings for proper playback.
     */
    #end
    var sampleRate:Int;

    #if !no_backend_docs
    /**
     * Converts a Unity AudioClip to a MiniLoud audio resource.
     * Extracts the raw sample data from the AudioClip for use
     * with MiniLoud's audio processing pipeline.
     * 
     * @param clip The Unity AudioClip to convert
     * @return A MiniLoud audio resource containing the clip's data
     */
    #end
    static function AudioResourceFromAudioClip(clip:AudioClip):MiniLoudAudio.MiniLoudAudioResource;

}
