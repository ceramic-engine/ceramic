package unityengine;

/**
 * Determines how audio data is loaded and stored in memory.
 * This affects memory usage, loading time, and CPU usage during playback.
 * 
 * The load type is typically set during audio import in Unity, but
 * understanding these modes helps optimize audio performance in Ceramic.
 * 
 * @see AudioClip
 */
@:native('UnityEngine.AudioClipLoadType')
extern class AudioClipLoadType {

    /**
     * Audio is decompressed completely when loaded.
     * 
     * Characteristics:
     * - Highest memory usage (stores uncompressed PCM data)
     * - Fastest playback performance (no runtime decompression)
     * - Longer initial load time
     * - Best for: Short, frequently-played sounds (SFX, UI sounds)
     * 
     * Memory usage: ~10MB per minute of stereo audio at 44.1kHz
     */
    static var DecompressOnLoad:AudioClipLoadType;

    /**
     * Audio remains compressed in memory and decompresses during playback.
     * 
     * Characteristics:
     * - Moderate memory usage (stores compressed data)
     * - Slight CPU overhead during playback for decompression
     * - Faster loading than DecompressOnLoad
     * - Best for: Medium-length sounds, ambient audio
     * 
     * Uses Vorbis compression on most platforms.
     */
    static var CompressedInMemory:AudioClipLoadType;

    /**
     * Audio streams from disk during playback.
     * 
     * Characteristics:
     * - Minimal memory usage (small buffer only)
     * - Continuous disk access during playback
     * - Cannot be played multiple times simultaneously
     * - Slight playback latency when starting
     * - Best for: Long music tracks, background ambience
     * 
     * Note: Requires reliable disk/storage access speed.
     */
    static var Streaming:AudioClipLoadType;

}