package spec;

import backend.AudioHandle;
import backend.AudioResource;
import backend.Float32Array;
import backend.LoadAudioOptions;

/**
 * Backend interface for audio operations.
 * 
 * This interface defines the contract that all backend implementations (Clay, Unity, Headless, Web)
 * must fulfill to provide audio functionality in Ceramic. It handles loading, playback control,
 * real-time effects, and bus management.
 * 
 * The audio system uses a bus-based architecture where sounds can be routed to different buses
 * (0-7) for group control and effects processing.
 */
interface Audio {

    /**
     * Loads an audio file from the specified path.
     * @param path The path to the audio file (relative to assets directory)
     * @param options Optional loading configuration (streaming, format hints, etc.)
     * @param done Callback invoked with the loaded AudioResource or null on failure
     */
    function load(path:String, ?options:LoadAudioOptions, done:AudioResource->Void):Void;

    /**
     * Creates an audio resource from raw PCM sample data.
     * @param buffer The raw audio sample data as 32-bit floats (-1.0 to 1.0 range)
     * @param samples The total number of samples in the buffer
     * @param channels The number of audio channels (1 for mono, 2 for stereo)
     * @param sampleRate The sample rate in Hz (e.g., 44100, 48000)
     * @param interleaved Whether samples are interleaved (L,R,L,R) or planar (L,L,L...,R,R,R)
     * @return A new AudioResource containing the audio data
     */
    function createFromSamplesBuffer(buffer:Float32Array, samples:Int, channels:Int, sampleRate:Float, interleaved:Bool):AudioResource;

    /**
     * Checks if the backend supports hot-reloading of audio files.
     * When true, the audio system can detect file changes and reload automatically.
     * @return True if hot-reload is supported, false otherwise
     */
    function supportsHotReloadPath():Bool;

    /**
     * Gets the duration of an audio resource in seconds.
     * @param audio The audio resource to query
     * @return The duration in seconds, or -1 if unknown (e.g., for streams)
     */
    function getDuration(audio:AudioResource):Float;

    /**
     * Resumes the audio context after user interaction.
     * This is required on web platforms where audio contexts start suspended
     * until user interaction occurs (click, touch, etc.).
     * @param done Callback invoked with true on success, false on failure
     */
    function resumeAudioContext(done:Bool->Void):Void;

    /**
     * Destroys an audio resource and frees its memory.
     * After calling this, the AudioResource should not be used.
     * @param audio The audio resource to destroy
     */
    function destroy(audio:AudioResource):Void;

    /**
     * Creates a muted audio handle without actually playing the sound.
     * Useful for pre-allocating handles or silent placeholders.
     * @param audio The audio resource to create a handle for
     * @return A muted AudioHandle that can be controlled like a playing sound
     */
    function mute(audio:AudioResource):AudioHandle;

    /**
     * Plays an audio resource with the specified parameters.
     * @param audio The audio resource to play
     * @param volume The playback volume (0.0 to 1.0, default 0.5)
     * @param pan The stereo panning (-1.0 for left, 0.0 for center, 1.0 for right)
     * @param pitch The playback pitch/speed multiplier (1.0 is normal speed)
     * @param position The starting position in seconds
     * @param loop Whether to loop playback when reaching the end
     * @param bus The audio bus to route this sound through (0-7)
     * @return An AudioHandle for controlling the playing sound
     */
    function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false, bus:Int = 0):AudioHandle;

    /**
     * Pauses playback of an audio handle.
     * The sound can be resumed from the same position with resume().
     * @param handle The audio handle to pause
     */
    function pause(handle:AudioHandle):Void;

    /**
     * Resumes playback of a paused audio handle.
     * Playback continues from where it was paused.
     * @param handle The audio handle to resume
     */
    function resume(handle:AudioHandle):Void;

    /**
     * Stops playback of an audio handle.
     * Unlike pause, this cannot be resumed - the handle becomes invalid.
     * @param handle The audio handle to stop
     */
    function stop(handle:AudioHandle):Void;

    /**
     * Gets the current volume of an audio handle.
     * @param handle The audio handle to query
     * @return The current volume (0.0 to 1.0)
     */
    function getVolume(handle:AudioHandle):Float;

    /**
     * Sets the volume of an audio handle.
     * @param handle The audio handle to modify
     * @param volume The new volume (0.0 to 1.0)
     */
    function setVolume(handle:AudioHandle, volume:Float):Void;

    /**
     * Gets the current stereo panning of an audio handle.
     * @param handle The audio handle to query
     * @return The current pan value (-1.0 for left, 0.0 for center, 1.0 for right)
     */
    function getPan(handle:AudioHandle):Float;

    /**
     * Sets the stereo panning of an audio handle.
     * @param handle The audio handle to modify
     * @param pan The new pan value (-1.0 for left, 0.0 for center, 1.0 for right)
     */
    function setPan(handle:AudioHandle, pan:Float):Void;

    /**
     * Gets the current pitch/speed multiplier of an audio handle.
     * @param handle The audio handle to query
     * @return The current pitch multiplier (1.0 is normal speed)
     */
    function getPitch(handle:AudioHandle):Float;

    /**
     * Sets the pitch/speed multiplier of an audio handle.
     * This affects both pitch and playback speed proportionally.
     * @param handle The audio handle to modify
     * @param pitch The new pitch multiplier (0.5 = half speed/octave down, 2.0 = double speed/octave up)
     */
    function setPitch(handle:AudioHandle, pitch:Float):Void;

    /**
     * Gets the current playback position of an audio handle.
     * @param handle The audio handle to query
     * @return The current position in seconds
     */
    function getPosition(handle:AudioHandle):Float;

    /**
     * Sets the playback position of an audio handle.
     * @param handle The audio handle to modify
     * @param position The new position in seconds
     */
    function setPosition(handle:AudioHandle, position:Float):Void;

    /**
     * Adds an audio filter to a bus for real-time effects processing.
     * Filters are processed in the order they are added.
     * @param bus The audio bus number (0-7) to add the filter to
     * @param filter The AudioFilter instance to add (e.g., LowPassFilter, HighPassFilter)
     * @param onReady Callback invoked when the filter is ready to process audio
     */
    function addFilter(bus:Int, filter:ceramic.AudioFilter, onReady:(bus:Int)->Void):Void;

    /**
     * Removes an audio filter from a bus.
     * @param bus The audio bus number (0-7) to remove the filter from
     * @param filterId The ID of the filter to remove (from AudioFilter.id)
     */
    function removeFilter(bus:Int, filterId:Int):Void;

    /**
     * Notifies the backend that a filter's parameters have changed.
     * This allows the backend to update real-time processing accordingly.
     * @param bus The audio bus number (0-7) containing the filter
     * @param filterId The ID of the filter whose parameters changed
     */
    function filterParamsChanged(bus:Int, filterId:Int):Void;

}
