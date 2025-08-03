package backend;

#if !no_backend_docs
/**
 * Implementation class for audio resources in the headless backend.
 * 
 * This class represents a loaded audio asset in the headless environment.
 * Unlike other backends, this doesn't contain actual audio data or
 * metadata since no sound is played in headless mode. It serves as a
 * placeholder to maintain API compatibility.
 * 
 * Audio resources created by this implementation can be used with
 * all the same audio playback functions as other backends, but will
 * not produce any actual sound output.
 */
#end
class AudioResourceImpl {

    #if !no_backend_docs
    /**
     * Creates a new mock audio resource.
     * 
     * In headless mode, no actual audio data is loaded or stored.
     */
    #end
    public function new() {}

}
