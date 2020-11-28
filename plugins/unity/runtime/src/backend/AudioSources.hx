package backend;

import unityengine.AudioSource;

#if ceramic_unity_debug_audiosource
import ceramic.Assert.assert;
#end

import unityengine.GameObject;

class AudioSources {

    /**
     * GameObject on which audio sources are associated with
     */
    var gameObject:GameObject;

    /**
     * All `AudioSource` instances associated with `gameObject`
     */
    var all:Array<AudioSource> = [];

    /**
     * `AudioSource` instances currently available for reuse
     */
    var pool:Array<AudioSource> = [];

    public function new(gameObject:GameObject) {

        this.gameObject = gameObject;

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

        pool.push(audioSource);

    }

}
