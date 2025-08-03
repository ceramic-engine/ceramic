package backend;

#if !no_backend_docs
/**
 * Abstract type representing an audio playback handle in the Unity backend.
 * 
 * AudioHandle provides a type-safe wrapper around AudioHandleImpl, which
 * controls an individual audio playback instance. This abstraction ensures
 * that the backend implementation details are hidden from the public API.
 * 
 * Through an AudioHandle, you can:
 * - Control playback (play, pause, stop)
 * - Adjust volume, pitch, and stereo pan
 * - Seek to different positions
 * - Monitor playback status
 * 
 * Handles are created when playing audio via the Audio backend and should
 * be retained as long as you need to control the playback. Once playback
 * is stopped or the handle is no longer referenced, resources are cleaned up.
 * 
 * @see AudioHandleImpl The concrete implementation
 * @see backend.Audio.play() Creates audio handles
 */
#end
#if documentation

typedef AudioHandle = AudioHandleImpl;

#else

abstract AudioHandle(AudioHandleImpl) from AudioHandleImpl to AudioHandleImpl {}

#end
