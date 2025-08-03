package unityengine;

/**
 * Manages audio routing and processing through a graph of mixer groups.
 * AudioMixers allow complex audio routing with effects, volume control,
 * and dynamic mixing of multiple audio sources.
 * 
 * In Ceramic's Unity backend, AudioMixers are used to implement the
 * audio bus system, allowing grouped control of sounds with effects.
 * 
 * Key features:
 * - Hierarchical mixing groups
 * - Built-in audio effects (reverb, compression, etc.)
 * - Exposed parameters for runtime control
 * - Snapshot system for mixing states
 * 
 * @example Basic usage:
 * ```haxe
 * // AudioMixers are typically configured in Unity Editor
 * // and accessed through the backend's bus system
 * var groups = mixer.FindMatchingGroups("Master/SFX");
 * ```
 * 
 * @see AudioMixerGroup
 * @see AudioSource
 */
@:native('UnityEngine.Audio.AudioMixer')
extern class AudioMixer extends Object {

    /**
     * Searches for mixer groups matching the given path pattern.
     * Useful for dynamically finding groups at runtime.
     * 
     * @param subPath Path pattern to search for. Can be:
     *                - Full path: "Master/Music/Ambient"
     *                - Partial path: "Music" (finds all groups named Music)
     *                - Wildcard: "Master/*" (finds all direct children)
     * @return Array of matching AudioMixerGroup objects
     * 
     * @example Finding all SFX groups:
     * ```haxe
     * var sfxGroups = mixer.FindMatchingGroups("SFX");
     * for (group in sfxGroups) {
     *     // Assign audio sources to these groups
     * }
     * ```
     * 
     * Note: Returns empty array if no matches found.
     */
    function FindMatchingGroups(subPath:String):cs.NativeArray<AudioMixerGroup>;

}
