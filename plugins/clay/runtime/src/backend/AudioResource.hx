package backend;

/**
 * Represents loaded audio data in the Clay backend audio system.
 * 
 * An AudioResource contains the decoded audio data that can be played back
 * multiple times. It serves as the source data for audio playback and is
 * typically loaded from audio files (WAV, OGG, MP3, etc.).
 * 
 * Key characteristics:
 * - Immutable after loading - the audio data doesn't change
 * - Can be played multiple times simultaneously
 * - Manages memory efficiently with reference counting
 * - Supports both streaming and preloaded audio data
 * 
 * AudioResource instances are created by the backend when loading audio
 * assets and are managed by the Ceramic Assets system.
 * 
 * @see Audio.play() To play an AudioResource
 * @see AudioHandle For controlling individual playback instances
 * @see SoundAsset For the high-level audio asset interface
 */
#if documentation

typedef AudioResource = clay.audio.AudioSource;

#else

abstract AudioResource(clay.audio.AudioSource) from clay.audio.AudioSource to clay.audio.AudioSource {}

#end
