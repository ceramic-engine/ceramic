package backend;

#if !no_backend_docs
/**
 * Abstract type representing an audio resource in the Unity backend.
 * 
 * AudioResource provides a type-safe wrapper around AudioResourceImpl, which
 * contains the actual Unity AudioClip and related data. This abstraction
 * ensures that backend implementation details are hidden from the public API.
 * 
 * Audio resources represent loaded audio data that can be played multiple times.
 * They are managed with reference counting to ensure efficient memory usage -
 * the same audio file loaded multiple times will share the same resource.
 * 
 * Resources can be created by:
 * - Loading from files via Audio.load()
 * - Creating from raw sample data via Audio.createFromSamplesBuffer()
 * 
 * @see AudioResourceImpl The concrete implementation
 * @see backend.Audio.load() Loads audio resources
 * @see backend.Audio.destroy() Releases audio resources
 */
#end
#if documentation

typedef AudioResource = AudioResourceImpl;

#else

abstract AudioResource(AudioResourceImpl) from AudioResourceImpl to AudioResourceImpl {}

#end
