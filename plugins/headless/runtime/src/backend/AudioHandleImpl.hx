package backend;

#if !no_backend_docs
/**
 * Implementation class for audio handles in the headless backend.
 * 
 * This class stores all the audio playback properties that would
 * normally control audio output. In headless mode, these properties
 * are maintained for API compatibility but don't affect any actual
 * audio playback since no sound is produced.
 * 
 * The audio handle maintains the following properties:
 * - Volume: 0.0 (silent) to 1.0 (full volume)
 * - Pan: -1.0 (left) to 1.0 (right)
 * - Pitch: Playback speed multiplier (1.0 = normal)
 * - Position: Current playback position in seconds
 */
#end
class AudioHandleImpl {
    #if !no_backend_docs
    /**
     * Audio playback volume (0.0 to 1.0).
     * Default is 0.5 (50% volume).
     */
    #end
    public var volume:Float = 0.5;
    
    #if !no_backend_docs
    /**
     * Stereo pan position (-1.0 to 1.0).
     * -1.0 = full left, 0.0 = center, 1.0 = full right.
     * Default is 0.0 (center).
     */
    #end
    public var pan:Float = 0;
    
    #if !no_backend_docs
    /**
     * Playback pitch/speed multiplier.
     * 1.0 = normal speed, 2.0 = double speed, 0.5 = half speed.
     * Default is 1.0 (normal speed).
     */
    #end
    public var pitch:Float = 1;
    
    #if !no_backend_docs
    /**
     * Current playback position in seconds.
     * Default is 0.0 (beginning).
     */
    #end
    public var position:Float = 0;
    
    #if !no_backend_docs
    /**
     * Creates a new audio handle with default values.
     */
    #end
    public function new() {}
}
