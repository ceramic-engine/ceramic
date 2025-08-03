package unityengine;

/**
 * Represents the loading state of an AudioClip's audio data.
 * Used to track asynchronous loading progress and handle loading failures.
 * 
 * This is particularly important when AudioClip.loadInBackground is true,
 * as you need to check the state before attempting playback.
 * 
 * @example Checking if audio is ready:
 * ```haxe
 * if (audioClip.loadState == AudioDataLoadState.Loaded) {
 *     // Safe to play the audio
 * }
 * ```
 * 
 * @see AudioClip
 */
@:native('UnityEngine.AudioDataLoadState')
extern class AudioDataLoadState {

    /**
     * Audio data has not been loaded yet.
     * 
     * This is the initial state for:
     * - Streaming AudioClips before first play
     * - Background-loaded clips before loading starts
     * - Clips that have been explicitly unloaded
     */
    static var Unloaded:AudioDataLoadState;

    /**
     * Audio data is currently being loaded.
     * 
     * Occurs when:
     * - Background loading is in progress
     * - Streaming clip is buffering initial data
     * 
     * Playback attempts during this state may fail or wait.
     */
    static var Loading:AudioDataLoadState;

    /**
     * Audio data is fully loaded and ready for playback.
     * 
     * This state indicates:
     * - All audio samples are available in memory
     * - The clip can be played without delay
     * - Multiple simultaneous playbacks are possible (non-streaming)
     */
    static var Loaded:AudioDataLoadState;

    /**
     * Audio data loading has failed.
     * 
     * Common failure reasons:
     * - File not found or corrupted
     * - Unsupported audio format
     * - Insufficient memory
     * - Disk read error (for streaming clips)
     * 
     * Clips in this state cannot be played.
     */
    static var Failed:AudioDataLoadState;

}