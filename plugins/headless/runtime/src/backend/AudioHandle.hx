package backend;

/**
 * Audio handle type definition for the headless backend.
 * 
 * This provides a type-safe wrapper around AudioHandleImpl.
 * Audio handles represent individual instances of playing
 * audio and maintain playback state like volume, pan, pitch,
 * and position.
 * 
 * In headless mode, these handles maintain all the same
 * properties as other backends but don't produce actual sound.
 */
#if documentation

typedef AudioHandle = AudioHandleImpl;

#else

abstract AudioHandle(AudioHandleImpl) from AudioHandleImpl to AudioHandleImpl {}

#end
