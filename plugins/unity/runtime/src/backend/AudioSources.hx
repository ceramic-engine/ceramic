package backend;

import backend.Float32Array;
import unityengine.AudioMixer;
import unityengine.AudioMixerGroup;
import unityengine.AudioSource;
import unityengine.GameObject;

#if ceramic_unity_debug_audiosource
import ceramic.Assert.assert;
#end

#if !no_backend_docs
/**
 * Manages pooled Unity AudioSource components for efficient audio playback.
 * 
 * This singleton class handles creation, pooling, and recycling of AudioSource
 * components in Unity, as well as managing audio mixer groups (buses) and
 * MiniLoud integration for advanced audio filtering.
 * 
 * Key features:
 * - Object pooling to avoid repeated AudioSource allocation/deallocation
 * - Audio bus system with Unity AudioMixer integration
 * - MiniLoud support for buses that require audio filtering
 * - Automatic cleanup of existing AudioSource components on initialization
 * 
 * The system creates AudioSource components on-demand and pools them when
 * finished to improve performance. Each bus can have its own mixer group
 * and optional MiniLoud component for DSP processing.
 * 
 * ```haxe
 * // Get a pooled AudioSource
 * var source = AudioSources.shared.get();
 * source.clip = myAudioClip;
 * source.Play();
 * 
 * // Return to pool when done
 * source.Stop();
 * AudioSources.shared.recycle(source);
 * ```
 */
#end
class AudioSources {

    #if !no_backend_docs
    /**
     * The singleton instance of AudioSources.
     * Automatically created on first access using the main GameObject and AudioMixer.
     */
    #end
    public static var shared(get,null):AudioSources = null;
    static function get_shared():AudioSources {
        if (shared == null) {
            shared = new AudioSources(Main.monoBehaviour.gameObject, Main.audioMixer);
        }
        return shared;
    }

    #if !no_backend_docs
    /**
     * GameObjects created for MiniLoud audio processing, indexed by bus number.
     * Each bus that uses filtering gets its own GameObject with a MiniLoud component.
     */
    #end
    var miniLoudObjectByBus:Array<GameObject> = [];

    #if !no_backend_docs
    /**
     * MiniLoud components for audio filtering, indexed by bus number.
     * These handle advanced DSP processing for buses with filters applied.
     */
    #end
    var miniLoudComponentByBus:Array<MiniLoudUnity> = [];

    #if !no_backend_docs
    /**
     * GameObject on which audio sources are associated with
     */
    #end
    var gameObject:GameObject;

    #if !no_backend_docs
    /**
     * Main AudioMixer object
     */
    #end
    var audioMixer:AudioMixer;

    #if !no_backend_docs
    /**
     * All `AudioSource` instances associated with `gameObject`
     */
    #end
    var all:Array<AudioSource> = [];

    #if !no_backend_docs
    /**
     * `AudioSource` instances currently available for reuse
     */
    #end
    var pool:Array<AudioSource> = [];

    #if !no_backend_docs
    /**
     * Busses by index
     */
    #end
    var busses:Array<AudioBus> = [];

    #if !no_backend_docs
    /**
     * An array to keep track of bus that were not found
     */
    #end
    var bussesNotFound:Array<Bool> = [];

    #if !no_backend_docs
    /**
     * Creates a new AudioSources manager.
     * Removes any existing AudioSource components from the GameObject to ensure clean state.
     * 
     * @param gameObject The GameObject to attach AudioSources to
     * @param audioMixer The main AudioMixer for bus routing
     */
    #end
    public function new(gameObject:GameObject, audioMixer:AudioMixer) {

        this.gameObject = gameObject;
        this.audioMixer = audioMixer;

        removeExistingAudioSourceComponents();

    }

    #if !no_backend_docs
    /**
     * Removes all existing AudioSource components from the GameObject.
     * Called during initialization to ensure no lingering components interfere.
     */
    #end
    function removeExistingAudioSourceComponents():Void {

        untyped __cs__('UnityEngine.AudioSource[] _sources = {0}.GetComponents<UnityEngine.AudioSource>()', gameObject);
        untyped __cs__('foreach(UnityEngine.AudioSource _source in _sources) UnityEngine.Object.Destroy(_source)');

    }

    #if !no_backend_docs
    /**
     * Gets an AudioSource from the pool or creates a new one if pool is empty.
     * The returned AudioSource is ready for configuration and playback.
     * 
     * @return A pooled or newly created AudioSource component
     */
    #end
    public function get():AudioSource {

        if (pool.length > 0) {
            return pool.pop();
        }
        else {
            var audioSource:AudioSource = untyped __cs__('{0}.AddComponent<UnityEngine.AudioSource>() as UnityEngine.AudioSource', gameObject);
            all.push(audioSource);
            return audioSource;
        }

    }

    #if !no_backend_docs
    /**
     * Returns an AudioSource to the pool for reuse.
     * Clears the AudioSource's state (mixer group and clip) before pooling.
     * 
     * @param audioSource The AudioSource to recycle (must be owned by this manager)
     */
    #end
    public function recycle(audioSource:AudioSource):Void {

        #if ceramic_unity_debug_audiosource
        assert(all.indexOf(audioSource) != -1, 'Cannot recycle this audio source: not own by this instance of AudioSources!');
        #end

        audioSource.outputAudioMixerGroup = null;
        audioSource.clip = null;

        pool.push(audioSource);

    }

    #if !no_backend_docs
    /**
     * Gets or creates an AudioBus for the specified index.
     * Looks for a mixer group named "Bus_N" where N is the bus index.
     * Caches both found buses and missing buses to avoid repeated lookups.
     * 
     * @param busIndex The index of the bus to retrieve (0-based)
     * @return The AudioBus if found, null if no matching mixer group exists
     */
    #end
    public function bus(busIndex:Int):AudioBus {

        var bus:AudioBus = busses[busIndex];

        if (bus == null && bussesNotFound[busIndex] != true) {

            var groups:cs.NativeArray<AudioMixerGroup> = audioMixer.FindMatchingGroups('Bus_$busIndex');
            if (groups.length > 0)
            {
                final mixerGroup = groups[0];
                bus = {
                    busIndex: busIndex,
                    mixerGroup: mixerGroup,
                    audioSources: []
                };
                busses[busIndex] = bus;
            }
            else
            {
                if (bussesNotFound[busIndex] != true) {
                    bussesNotFound[busIndex] = true;
                    ceramic.Shortcuts.log.warning('Bus_$busIndex group not found in mixer');
                }
            }

        }

        return bus;

    }

    #if !no_backend_docs
    /**
     * Creates an audio filter callback for the specified bus.
     * Sets up MiniLoud audio processing to handle real-time DSP effects.
     * The filter processes audio samples through the Audio backend's filter chain.
     * 
     * @param busIndex The bus index to create a filter for
     */
    #end
    public function createBusFilter(
        busIndex:Int
    ):Void {

        untyped __cs__('{0}.OnAudioProcess += (float[] planarBuffer, int samplesPerChannel, int channels, int sampleRate, double currentTime) => {
            global::backend.Audio._unityFilterProcess({1}, {2}, planarBuffer, samplesPerChannel, channels, sampleRate, currentTime);
        }', miniLoudObject(busIndex), busIndex, busIndex);

    }

    #if !no_backend_docs
    /**
     * Gets or creates a MiniLoud component for the specified bus.
     * MiniLoud provides advanced audio processing capabilities beyond Unity's built-in system.
     * Creates a dedicated GameObject if needed and configures the mixer group routing.
     * 
     * @param busIndex The bus index to get MiniLoud for
     * @return The MiniLoudUnity component for this bus
     */
    #end
    public function miniLoudObject(busIndex:Int):MiniLoudUnity {

        var comp:MiniLoudUnity = miniLoudComponentByBus[busIndex];

        if (comp == null) {
            var obj:GameObject = miniLoudObjectByBus[busIndex];

            if (obj == null) {
                obj = untyped __cs__('new UnityEngine.GameObject({0})', 'MiniLoud_$busIndex');
                miniLoudObjectByBus[busIndex] = obj;
            }

            comp = untyped __cs__('{0}.AddComponent<MiniLoudUnity>()', obj);
            miniLoudComponentByBus[busIndex] = comp;

            final bus = this.bus(busIndex);
            if (bus != null) {
                comp.audioSource.outputAudioMixerGroup = bus.mixerGroup;
            }
        }

        return comp;

    }

}
