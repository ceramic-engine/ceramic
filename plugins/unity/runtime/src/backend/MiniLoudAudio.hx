package backend;

import backend.Float32Array;

#if !no_backend_docs
/**
 * External interface to the MiniLoud audio engine.
 * 
 * MiniLoud is a lightweight audio processing library that provides
 * advanced features beyond Unity's built-in audio system, including:
 * - Direct sample-level audio manipulation
 * - Custom DSP effects and filters
 * - Low-latency audio processing
 * - Precise playback control
 * 
 * This is used for audio buses that have filters applied, as Unity's
 * AudioSource doesn't provide sufficient control for real-time DSP.
 * 
 * @see backend.Audio Uses MiniLoud for filtered audio playback
 * @see backend.AudioSources Creates MiniLoud components per bus
 */
#end
@:native('MiniLoud.MiniLoudAudio')
extern class MiniLoudAudio {

    #if !no_backend_docs
    /**
     * Creates a new MiniLoud audio engine instance.
     * 
     * @param sampleRate The audio sample rate (e.g., 44100, 48000)
     * @param channels Number of audio channels (1=mono, 2=stereo)
     */
    #end
    function new(sampleRate:Int, channels:Int);

    #if !no_backend_docs
    /**
     * Creates an audio resource from raw sample data.
     * 
     * @param data Raw audio samples as 32-bit floats
     * @param channels Number of channels in the data
     * @param sampleRate Sample rate of the audio data
     * @return A new audio resource ready for playback
     */
    #end
    static function CreateFromData(data:Float32Array, channels:Int, sampleRate:Single):MiniLoudAudioResource;

    #if !no_backend_docs
    /**
     * Gets the duration of an audio resource in seconds.
     * 
     * @param audio The audio resource
     * @return Duration in seconds
     */
    #end
    function GetDuration(audio:MiniLoudAudioResource):Single;

    #if !no_backend_docs
    /**
     * Destroys this MiniLoud instance and releases resources.
     */
    #end
    function Destroy():Void;

    #if !no_backend_docs
    /**
     * Creates a muted audio handle for an audio resource.
     * Used for tracking without actually playing audio.
     * 
     * @param audio The audio resource to track
     * @return A handle for the muted audio
     */
    #end
    function Mute(audio:MiniLoudAudioResource):MiniLoudAudioHandle;

    #if !no_backend_docs
    /**
     * Plays an audio resource with full control over playback parameters.
     * 
     * @param audio The audio resource to play
     * @param volume Playback volume (0.0 to 1.0)
     * @param pan Stereo panning (-1.0 = left, 0.0 = center, 1.0 = right)
     * @param pitch Playback speed/pitch multiplier (1.0 = normal)
     * @param position Starting position in seconds
     * @param loop Whether to loop playback
     * @return A handle for controlling the playing audio
     */
    #end
    function Play(audio:MiniLoudAudioResource, volume:Single, pan:Single, pitch:Single, position:Single, loop:Bool):MiniLoudAudioHandle;

    #if !no_backend_docs
    /**
     * Pauses audio playback.
     * @param handle The audio handle to pause
     */
    #end
    function Pause(handle:MiniLoudAudioHandle):Void;

    #if !no_backend_docs
    /**
     * Resumes paused audio playback.
     * @param handle The audio handle to resume
     */
    #end
    function Resume(handle:MiniLoudAudioHandle):Void;

    #if !no_backend_docs
    /**
     * Stops audio playback and invalidates the handle.
     * @param handle The audio handle to stop
     */
    #end
    function Stop(handle:MiniLoudAudioHandle):Void;

    #if !no_backend_docs
    /**
     * Gets the current volume.
     * @param handle The audio handle
     * @return Volume level (0.0 to 1.0)
     */
    #end
    function GetVolume(handle:MiniLoudAudioHandle):Single;

    #if !no_backend_docs
    /**
     * Sets the volume.
     * @param handle The audio handle
     * @param volume New volume level (0.0 to 1.0)
     */
    #end
    function SetVolume(handle:MiniLoudAudioHandle, volume:Single):Void;

    #if !no_backend_docs
    /**
     * Gets the current stereo pan.
     * @param handle The audio handle
     * @return Pan value (-1.0 = left, 0.0 = center, 1.0 = right)
     */
    #end
    function GetPan(handle:MiniLoudAudioHandle):Single;

    #if !no_backend_docs
    /**
     * Sets the stereo pan.
     * @param handle The audio handle
     * @param pan New pan value (-1.0 = left, 0.0 = center, 1.0 = right)
     */
    #end
    function SetPan(handle:MiniLoudAudioHandle, pan:Single):Void;

    #if !no_backend_docs
    /**
     * Gets the current pitch/speed multiplier.
     * @param handle The audio handle
     * @return Pitch multiplier (1.0 = normal)
     */
    #end
    function GetPitch(handle:MiniLoudAudioHandle):Single;

    #if !no_backend_docs
    /**
     * Sets the pitch/speed multiplier.
     * @param handle The audio handle
     * @param pitch New pitch multiplier (1.0 = normal)
     */
    #end
    function SetPitch(handle:MiniLoudAudioHandle, pitch:Single):Void;

    #if !no_backend_docs
    /**
     * Gets the current playback position.
     * @param handle The audio handle
     * @return Position in seconds
     */
    #end
    function GetPosition(handle:MiniLoudAudioHandle):Single;

    #if !no_backend_docs
    /**
     * Sets the playback position.
     * @param handle The audio handle
     * @param position New position in seconds
     */
    #end
    function SetPosition(handle:MiniLoudAudioHandle, position:Single):Void;

    #if !no_backend_docs
    /**
     * Processes audio data through MiniLoud's mixing engine.
     * Called by Unity's audio thread to fill audio buffers.
     * 
     * @param data Buffer to fill with audio samples
     * @param channels Number of channels to process
     */
    #end
    function ProcessAudio(data:Float32Array, channels:Int):Void;

}

#if !no_backend_docs
/**
 * Represents an audio resource in MiniLoud.
 * Contains the raw audio data and metadata needed for playback.
 */
#end
@:native('MiniLoud.AudioResource')
extern class MiniLoudAudioResource {

    #if !no_backend_docs
    /**
     * Raw audio sample data as 32-bit floats.
     */
    #end
    var audioData:Float32Array;

    #if !no_backend_docs
    /**
     * Number of audio channels (1=mono, 2=stereo).
     */
    #end
    var channels:Int;

    #if !no_backend_docs
    /**
     * Sample rate in Hz (e.g., 44100, 48000).
     */
    #end
    var sampleRate:Single;

    #if !no_backend_docs
    /**
     * Duration of the audio in seconds.
     */
    #end
    var duration:Single;

}

#if !no_backend_docs
/**
 * Handle for controlling a playing audio instance in MiniLoud.
 */
#end
@:native('MiniLoud.AudioHandle')
extern class MiniLoudAudioHandle {

    #if !no_backend_docs
    /**
     * Internal handle ID used by MiniLoud.
     */
    #end
    var internalHandle:Int;

    #if !no_backend_docs
    /**
     * Whether this handle is still valid and playing.
     */
    #end
    var isValid:Bool;

}
