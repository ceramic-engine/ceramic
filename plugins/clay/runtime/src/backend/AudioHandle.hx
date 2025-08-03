package backend;

/**
 * Handle to an individual audio playback instance in the Clay audio system.
 * 
 * An AudioHandle represents a playing or paused sound instance that can be
 * controlled independently. Each handle allows you to:
 * - Control playback (play, pause, stop)
 * - Adjust volume and pitch
 * - Query playback position and state
 * - Apply real-time effects
 * 
 * Handles are obtained when playing a sound through the Audio system and
 * remain valid until the sound completes or is explicitly stopped. The
 * handle becomes invalid after the sound finishes playing.
 * 
 * @see Audio.play() To obtain an AudioHandle
 * @see AudioResource For the underlying audio data
 */
#if documentation

typedef AudioHandle = clay.audio.AudioHandle;

#else

abstract AudioHandle(clay.audio.AudioHandle) from clay.audio.AudioHandle to clay.audio.AudioHandle {

    /**
     * String representation for debugging purposes.
     * @return A string in the format "AudioHandle(handle_value)"
     */
    inline function toString() {

        return 'AudioHandle($this)';

    }

}

#end
