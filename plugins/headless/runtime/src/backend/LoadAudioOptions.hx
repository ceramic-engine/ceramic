package backend;

#if !no_backend_docs
/**
 * Options for loading audio resources in the headless backend.
 * 
 * These options control how audio files are loaded and processed.
 * In headless mode, these options are maintained for API compatibility
 * but don't affect actual audio loading since no audio data is processed.
 */
#end
typedef LoadAudioOptions = {

    #if !no_backend_docs
    /**
     * Whether to stream the audio instead of loading it entirely into memory.
     * 
     * In headless mode, this option is ignored since no actual audio
     * data is loaded.
     */
    #end
    @:optional var stream:Bool;

}
