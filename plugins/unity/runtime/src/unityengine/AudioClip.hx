package unityengine;

/**
 * Represents audio data that can be played by AudioSource components.
 * AudioClips are imported audio files that contain audio data in various formats.
 * 
 * In Ceramic's Unity backend, AudioClips are used to store and play sound effects
 * and music. They can be loaded from Resources or created dynamically at runtime.
 * 
 * @example Loading and playing an AudioClip:
 * ```haxe
 * // AudioClips are typically loaded through Ceramic's asset system
 * // This is handled internally by the Unity backend
 * ```
 * 
 * @see AudioSource
 * @see AudioMixer
 */
@:native('UnityEngine.AudioClip')
extern class AudioClip extends Object {

    /**
     * Returns whether the AudioClip contains ambisonic audio (multi-channel surround).
     * Ambisonic audio captures full 360-degree sound fields.
     * 
     * Read-only property set during audio import.
     */
    var ambisonic(default, null):Bool;

    /**
     * The number of audio channels in the clip.
     * Common values:
     * - 1: Mono (single channel)
     * - 2: Stereo (left and right channels)
     * - 6: 5.1 surround sound
     * 
     * Read-only property determined by the source audio file.
     */
    var channels(default, null):Int;

    /**
     * The sample frequency of the clip in Hertz (samples per second).
     * Common values:
     * - 22050: Low quality
     * - 44100: CD quality
     * - 48000: Professional audio
     * 
     * Read-only property determined by the source audio file.
     */
    var frequency(default, null):Int;

    /**
     * The length of the audio clip in seconds.
     * Calculated as: total samples / frequency
     * 
     * Read-only property useful for determining playback duration.
     */
    var length(default, null):Single;

    /**
     * Whether to load the audio data in the background (non-blocking).
     * When true, audio loads asynchronously without freezing the main thread.
     * 
     * Should be set before the clip starts loading.
     * Check loadState to determine when loading is complete.
     */
    var loadInBackground:Bool;

    /**
     * The current loading state of the audio data.
     * Indicates whether the audio is loaded, loading, or failed.
     * 
     * Particularly useful when loadInBackground is true to check
     * if the audio is ready to play.
     * 
     * @see AudioDataLoadState
     */
    var loadState(default, null):AudioDataLoadState;

    /**
     * How the audio clip was loaded into memory.
     * Determines memory usage and performance characteristics:
     * - Decompress on load: Faster playback, uses more memory
     * - Compressed in memory: Balanced memory/CPU usage
     * - Streaming: Minimal memory, continuous disk access
     * 
     * Read-only property set during import.
     * 
     * @see AudioClipLoadType
     */
    var loadType(default, null):AudioClipLoadType;

    /**
     * Creates a new AudioClip programmatically.
     * Useful for generating audio at runtime or recording from microphone.
     * 
     * @param name Display name for the AudioClip
     * @param lengthSamples Total number of audio samples (length in seconds * frequency)
     * @param channels Number of audio channels (1 for mono, 2 for stereo)
     * @param frequency Sample rate in Hz (e.g., 44100)
     * @param stream Whether to create as streaming clip (true) or in-memory (false)
     * @return Newly created AudioClip ready for SetData() calls
     * 
     * @example Creating a 1-second sine wave:
     * ```haxe
     * var clip = AudioClip.Create("sine", 44100, 1, 44100, false);
     * // Then use SetData() to fill with audio samples
     * ```
     */
    static function Create(name:String, lengthSamples:Int, channels:Int, frequency:Int, stream:Bool):AudioClip;

    /**
     * Fills the AudioClip with audio sample data.
     * Must be called after Create() to populate a procedural AudioClip.
     * 
     * @param data Array of audio samples as floating-point values (-1.0 to 1.0)
     *             Interleaved for multi-channel (e.g., L,R,L,R for stereo)
     * @param offsetSamples Starting position in the clip to write data
     * @return True if data was successfully written, false otherwise
     * 
     * Note: The data array length must match the clip's channel count
     * and not exceed the remaining samples from offsetSamples.
     */
    function SetData(data:cs.NativeArray<Single>, offsetSamples:Int):Bool;

}
