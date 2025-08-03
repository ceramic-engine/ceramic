package backend;

/**
 * Audio resource type definition for the headless backend.
 * 
 * This provides a type-safe wrapper around AudioResourceImpl.
 * Audio resources represent loaded audio data that can be
 * played multiple times through audio handles.
 * 
 * In headless mode, these resources don't contain actual
 * audio data but maintain the same interface for API
 * compatibility.
 */
#if documentation

typedef AudioResource = AudioResourceImpl;

#else

abstract AudioResource(AudioResourceImpl) from AudioResourceImpl to AudioResourceImpl {}

#end
