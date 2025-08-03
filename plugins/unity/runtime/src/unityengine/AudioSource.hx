package unityengine;

import unityengine.Component;

/**
 * Component that plays AudioClips in 3D or 2D space.
 * The primary way to play sounds in Unity, supporting spatial audio,
 * effects, and mixer routing.
 * 
 * In Ceramic's Unity backend, AudioSources are pooled and managed
 * to efficiently play sounds through the audio bus system.
 * 
 * Key features:
 * - 3D spatial audio with distance attenuation
 * - Pitch and volume control
 * - Looping and time control
 * - Integration with AudioMixer for effects
 * - Doppler effect simulation
 * 
 * @see AudioClip
 * @see AudioMixer
 * @see AudioMixerGroup
 */
@:native('UnityEngine.AudioSource')
extern class AudioSource extends Behaviour {

    /**
     * Bypasses all effects applied by the AudioMixerGroup.
     * When true, audio plays without any mixer effects (reverb, etc.).
     * Useful for UI sounds or when effects cause issues.
     */
    var bypassEffects:Bool;

    /**
     * Bypasses effects applied to the AudioListener.
     * When true, ignores global effects on the listener.
     */
    var bypassListenerEffects:Bool;

    /**
     * Bypasses reverb zones in the scene.
     * When true, this source ignores any reverb zone effects.
     * Useful for UI or non-diegetic sounds.
     */
    var bypassReverbZones:Bool;

    /**
     * The AudioClip to play.
     * Set this before calling Play() or enable playOnAwake.
     * Can be changed during playback for crossfading effects.
     */
    var clip:AudioClip;

    /**
     * Doppler effect intensity (0-5).
     * 0 = No doppler effect
     * 1 = Realistic doppler
     * >1 = Exaggerated effect
     * 
     * Simulates pitch changes from relative motion.
     */
    var dopplerLevel:Single;

    /**
     * Whether this source continues playing when AudioListener.pause is true.
     * Useful for menu sounds that should play during game pause.
     */
    var ignoreListenerPause:Bool;

    /**
     * Whether this source ignores AudioListener.volume.
     * When true, only this source's volume property affects loudness.
     */
    var ignoreListenerVolume:Bool;

    /**
     * Whether the AudioSource is currently playing.
     * Read-only. Check this to determine playback state.
     * 
     * Returns false when paused, stopped, or finished.
     */
    var isPlaying(default, null):Bool;

    /**
     * Whether Unity has virtualized this AudioSource.
     * Virtual sources are too quiet/far to hear but continue
     * updating position for when they become audible again.
     */
    var isVirtual:Bool;

    /**
     * Whether the sound repeats after finishing.
     * When true, playback restarts from beginning after reaching end.
     * Essential for background music and ambient sounds.
     */
    var loop:Bool;

    /**
     * Maximum distance for 3D sound attenuation.
     * Beyond this distance, volume remains at minimum.
     * Works with minDistance to define falloff curve.
     * 
     * Default: 500.0
     */
    var maxDistance:Single;

    /**
     * Distance at which 3D sound begins attenuating.
     * Within this distance, sound plays at full volume.
     * 
     * Default: 1.0
     */
    var minDistance:Single;

    /**
     * Mutes the AudioSource.
     * When true, no sound is produced but playback continues.
     * Different from volume=0 as it completely bypasses audio processing.
     */
    var mute:Bool;

    /**
     * Stereo pan position (-1 to 1).
     * -1 = Full left
     *  0 = Center
     *  1 = Full right
     * 
     * Only affects 2D sounds (spatialBlend = 0).
     */
    var panStereo:Single;

    /**
     * Pitch multiplier (0.1 to 3.0).
     * 1.0 = Normal pitch
     * 0.5 = One octave lower  
     * 2.0 = One octave higher
     * 
     * Note: Extreme values may cause artifacts.
     */
    var pitch:Single;

    /**
     * Whether to start playing immediately when enabled.
     * If true and clip is set, playback begins automatically.
     * Useful for ambient sounds in scenes.
     */
    var playOnAwake:Bool;

    /**
     * Priority for voice management (0-256).
     * 0 = Highest priority (never virtualized)
     * 256 = Lowest priority (first to be virtualized)
     * 
     * Unity virtualizes lower priority sounds when too many play.
     */
    var priority:Int;

    /**
     * Amount of reverb zone effect applied (0-1.1).
     * 0 = No reverb
     * 1 = Full reverb
     * >1 = Amplified reverb
     * 
     * Requires reverb zones in scene.
     */
    var reverbZoneMix:Single;

    /**
     * Enables 3D spatialization plugins.
     * When true, compatible spatial audio plugins can process
     * this source for binaural or ambisonic output.
     */
    var spatialize:Bool;

    /**
     * Current playback position in seconds.
     * Can be set to seek to specific time.
     * Clamped between 0 and clip.length.
     * 
     * Use for scrubbing or syncing multiple sources.
     */
    var time:Single;

    /**
     * Current playback position in PCM samples.
     * More precise than time for sample-accurate sync.
     * Range: 0 to (clip.samples - 1)
     * 
     * Useful for beat-matching or precise loops.
     */
    var timeSamples:Int;

    /**
     * Volume/amplitude multiplier (0-1).
     * 0 = Silent
     * 1 = Full volume
     * 
     * Applied before mixer group processing.
     * Use logarithmic scaling for perceptual linearity.
     */
    var volume:Single;

    /**
     * Routes audio output to specific mixer group.
     * If null, outputs to master mixer.
     * 
     * Use this to apply group effects and manage
     * multiple sounds together (e.g., all SFX).
     */
    var outputAudioMixerGroup:AudioMixerGroup;

    /**
     * Pauses playback, maintaining current position.
     * Call UnPause() to resume from same position.
     * Unlike Stop(), doesn't reset playback position.
     */
    function Pause():Void;

    /**
     * Starts playing the assigned AudioClip.
     * If already playing, restarts from beginning.
     * Requires clip to be assigned.
     * 
     * @example Basic playback:
     * ```haxe
     * source.clip = myClip;
     * source.volume = 0.8;
     * source.Play();
     * ```
     */
    function Play():Void;

    /**
     * Schedules playback to start after a delay.
     * Useful for timing sounds with animations or music.
     * 
     * @param delay Seconds to wait before playing (must be positive)
     * 
     * Note: Uses audio DSP time for sample-accurate scheduling.
     */
    function PlayDelayed(delay:Single):Void;

    /**
     * Stops playback and resets position to beginning.
     * If Play() is called after Stop(), playback starts from 0.
     * Use Pause() instead to maintain position.
     */
    function Stop():Void;

    /**
     * Resumes playback after Pause().
     * Continues from the position where Pause() was called.
     * Has no effect if not currently paused.
     */
    function UnPause():Void;

}
