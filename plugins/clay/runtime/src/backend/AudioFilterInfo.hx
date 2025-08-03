package backend;

/**
 * Internal metadata for audio filters attached to a bus.
 * 
 * This structure tracks the state and components needed for
 * real-time audio filter processing in the Clay backend.
 * It bridges between the high-level AudioFilter API and the
 * low-level worklet processing system.
 */
@:structInit
class AudioFilterInfo {

    /**
     * Unique identifier for this filter instance.
     * Used to reference the filter in add/remove operations.
     */
    public final id:Int;

    /**
     * Flag indicating whether filter parameters need to be
     * synchronized to the worklet on the next audio process cycle.
     * Set to true when filterParamsChanged() is called.
     */
    public var paramsDirty:Bool = true;

    /**
     * The instantiated worklet that performs the actual audio processing.
     * Created lazily on first use in the audio thread.
     * On web, this runs in an AudioWorklet. On native, it runs in the audio callback.
     */
    public var worklet:ceramic.AudioFilterWorklet = null;

    /**
     * The class type of the worklet to instantiate.
     * Retrieved from the filter's workletClass() method.
     */
    public var workletClass:Class<ceramic.AudioFilterWorklet>;

    /**
     * The high-level filter instance that contains the parameters
     * and configuration for this audio effect.
     */
    public var filter:ceramic.AudioFilter;

}
