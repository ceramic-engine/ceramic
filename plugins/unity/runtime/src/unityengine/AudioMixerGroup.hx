package unityengine;

/**
 * Represents a routing target within an AudioMixer.
 * Groups allow sounds to be processed together with shared effects and volume.
 * 
 * AudioMixerGroups form a hierarchy within an AudioMixer, where:
 * - Each group can have child groups
 * - Audio flows from children to parents
 * - Effects are applied at each group level
 * - Final output goes through the Master group
 * 
 * In Ceramic's Unity backend, these groups implement the audio bus system,
 * allowing sounds to be categorized (Music, SFX, UI, etc.) and controlled
 * as groups with individual volume and effects.
 * 
 * Typical hierarchy:
 * ```
 * Master
 * ├── Music
 * │   ├── Background
 * │   └── Stingers
 * ├── SFX
 * │   ├── Player
 * │   ├── Enemies
 * │   └── Environment
 * └── UI
 * ```
 * 
 * Note: AudioMixerGroups are created and configured in Unity Editor,
 * not through code. This class provides runtime access only.
 * 
 * @see AudioMixer
 * @see AudioSource
 */
@:native('UnityEngine.Audio.AudioMixerGroup')
extern class AudioMixerGroup extends Object {

}
