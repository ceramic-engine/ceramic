package backend;

#if !no_backend_docs
/**
 * Internal data structure for tracking audio filters in the Unity backend.
 * 
 * This class maintains the state and references needed to manage an audio
 * filter's lifecycle within Unity's audio processing pipeline. It bridges
 * between Ceramic's AudioFilter API and the low-level worklet implementation.
 * 
 * Used internally by the Audio backend to:
 * - Track which filters are attached to which buses
 * - Manage parameter synchronization between main and audio threads
 * - Cache worklet instances for efficient processing
 * 
 * @see backend.Audio The main audio backend that uses this structure
 * @see ceramic.AudioFilter The high-level filter interface
 * @see ceramic.AudioFilterWorklet The low-level processing implementation
 */
#end
@:structInit
class AudioFilterInfo {

    #if !no_backend_docs
    /**
     * Unique identifier for this filter instance.
     * Used to reference the filter when updating parameters or removing it.
     */
    #end
    public final id:Int;

    #if !no_backend_docs
    /**
     * Flag indicating filter parameters need to be synced to the worklet.
     * Set to true when filterParamsChanged() is called, cleared after sync.
     * Default: true (to ensure initial sync)
     */
    #end
    public var paramsDirty:Bool = true;

    #if !no_backend_docs
    /**
     * The instantiated worklet that performs actual audio processing.
     * Created lazily on first audio callback to avoid threading issues.
     * null until the filter is first processed.
     */
    #end
    public var worklet:ceramic.AudioFilterWorklet = null;

    #if !no_backend_docs
    /**
     * The worklet class to instantiate for this filter.
     * Cached from filter.workletClass() to avoid repeated lookups.
     */
    #end
    public var workletClass:Class<ceramic.AudioFilterWorklet>;

    #if !no_backend_docs
    /**
     * Reference to the high-level filter object.
     * Contains the filter parameters and configuration.
     */
    #end
    public var filter:ceramic.AudioFilter;

}
