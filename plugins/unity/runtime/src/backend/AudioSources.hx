package backend;

import backend.Float32Array;
import unityengine.AudioMixer;
import unityengine.AudioMixerGroup;
import unityengine.AudioSource;
import unityengine.GameObject;

#if ceramic_unity_debug_audiosource
import ceramic.Assert.assert;
#end

class AudioSources {

    public static var shared(get,null):AudioSources = null;
    static function get_shared():AudioSources {
        if (shared == null) {
            shared = new AudioSources(Main.monoBehaviour.gameObject, Main.audioMixer);
        }
        return shared;
    }

    var miniLoudObjectByBus:Array<GameObject> = [];

    var miniLoudComponentByBus:Array<MiniLoudUnity> = [];

    /**
     * GameObject on which audio sources are associated with
     */
    var gameObject:GameObject;

    /**
     * Main AudioMixer object
     */
    var audioMixer:AudioMixer;

    /**
     * All `AudioSource` instances associated with `gameObject`
     */
    var all:Array<AudioSource> = [];

    /**
     * `AudioSource` instances currently available for reuse
     */
    var pool:Array<AudioSource> = [];

    /**
     * Busses by index
     */
    var busses:Array<AudioBus> = [];

    /**
     * An array to keep track of bus that were not found
     */
    var bussesNotFound:Array<Bool> = [];

    public function new(gameObject:GameObject, audioMixer:AudioMixer) {

        this.gameObject = gameObject;
        this.audioMixer = audioMixer;

        removeExistingAudioSourceComponents();

    }

    function removeExistingAudioSourceComponents():Void {

        untyped __cs__('UnityEngine.AudioSource[] _sources = {0}.GetComponents<UnityEngine.AudioSource>()', gameObject);
        untyped __cs__('foreach(UnityEngine.AudioSource _source in _sources) UnityEngine.Object.Destroy(_source)');

    }

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

    public function recycle(audioSource:AudioSource):Void {

        #if ceramic_unity_debug_audiosource
        assert(all.indexOf(audioSource) != -1, 'Cannot recycle this audio source: not own by this instance of AudioSources!');
        #end

        audioSource.outputAudioMixerGroup = null;
        audioSource.clip = null;

        pool.push(audioSource);

    }

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

    public function createBusFilter(
        busIndex:Int
    ):Void {

        untyped __cs__('{0}.OnAudioProcess += (float[] planarBuffer, int samplesPerChannel, int channels, int sampleRate, double currentTime) => {
            global::backend.Audio._unityFilterProcess({1}, {2}, planarBuffer, samplesPerChannel, channels, sampleRate, currentTime);
        }', miniLoudObject(busIndex), busIndex, busIndex);

    }

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
        }

        return comp;

    }

}
