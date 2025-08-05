package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;

/**
 * Represents a loaded sound that can be played multiple times.
 * 
 * Sound instances are typically created by loading audio assets,
 * but can also be created from raw PCM sample data.
 * 
 * Features:
 * - Multiple simultaneous playback instances
 * - Volume, pan, and pitch control
 * - Bus routing for audio processing
 * - Group-based mixing
 * - Looping support
 * 
 * Each time you call `play()`, a new SoundPlayer instance is created,
 * allowing the same sound to be played multiple times simultaneously.
 * 
 * ```haxe
 * // Load and play a sound
 * var sound = assets.sound('jump');
 * sound.volume = 0.8;
 * sound.play();
 * 
 * // Play with custom parameters
 * var player = sound.play(0, true, 0.5, -0.3, 1.2);
 * 
 * // Create sound from raw samples
 * var customSound = Sound.fromSamplesBuffer(
 *     samples, frameCount, 2, 44100, true
 * );
 * ```
 * 
 * @see SoundPlayer
 * @see SoundAsset
 * @see AudioMixer
 */
class Sound extends Entity {

    /**
     * The backend audio resource containing the actual audio data.
     */
    public var backendItem:backend.AudioResource;

    /**
     * The asset this sound was loaded from, if any.
     * Automatically destroyed when the sound is destroyed.
     */
    public var asset:SoundAsset;

    /**
     * Default bus to play this sound on.
     * 0 = master bus (default)
     * Higher numbers route through different audio processing chains.
     */
    public var bus:Int = 0;

    /**
     * The mixer group this sound belongs to.
     * Each group has its own AudioMixer for collective volume/pan/pitch control.
     * Setting this will automatically create the mixer if it doesn't exist.
     */
    public var group(default, set):Int = 0;
    function set_group(group:Int):Int {
        if (this.group == group) return group;
        this.group = group;
        ceramic.App.app.audio.initMixerIfNeeded(group);
        return group;
    }

/// Lifecycle

    /**
     * Create a new sound from raw PCM sample data.
     * Useful for procedural audio generation or custom audio processing.
     * 
     * @param buffer Float32Array containing the raw PCM samples
     * @param samples Number of sample frames (total samples divided by channel count)
     * @param channels Number of audio channels (1 = mono, 2 = stereo, etc.)
     * @param sampleRate Sample rate in Hz (e.g., 44100, 48000)
     * @param interleaved Whether the PCM data is interleaved (LRLRLR...) or planar (LLL...RRR...)
     * @return A new Sound instance ready to be played
     */
    public static function fromSamplesBuffer(buffer:Float32Array, samples:Int, channels:Int, sampleRate:Float, interleaved:Bool):Sound {

        var backendItem = app.backend.audio.createFromSamplesBuffer(buffer, samples, channels, sampleRate, interleaved);
        return new Sound(backendItem);

    }

    /**
     * Create a new Sound from a backend audio resource.
     * Usually you don't call this directly - use asset loading or fromSamplesBuffer instead.
     * @param backendItem The backend audio resource
     */
    public function new(backendItem:backend.AudioResource) {

        super();

        this.backendItem = backendItem;

    }

    override function destroy() {

        super.destroy();

        if (asset != null) asset.destroy();

        app.backend.audio.destroy(backendItem);
        backendItem = null;

    }

/// Public API

    /**
     * Default volume when playing this sound.
     * Range: 0.0 (silent) to 1.0 (full volume)
     * This is multiplied with the mixer volume.
     */
    public var volume:Float = 0.5;

    /**
     * Default pan when playing this sound.
     * Range: -1.0 (full left) to 1.0 (full right)
     * 0.0 = center (default)
     */
    public var pan:Float = 0;

    /**
     * Default pitch when playing this sound.
     * 1.0 = normal pitch (default)
     * 0.5 = one octave lower
     * 2.0 = one octave higher
     */
    public var pitch:Float = 1;

    /**
     * Sound duration in seconds.
     * Read-only property calculated from the audio data.
     */
    public var duration(get, never):Float;
    inline function get_duration():Float {
        return app.backend.audio.getDuration(backendItem);
    }

    /**
     * Play the sound with optional parameters.
     * Creates a new SoundPlayer instance for this playback.
     * 
     * If volume/pan/pitch are not provided, the sound's default values are used.
     * The final values are also affected by the mixer group settings.
     * 
     * @param position Start position in seconds (0 = beginning)
     * @param loop Whether to loop the sound continuously
     * @param volume Volume override (0-1, null = use default)
     * @param pan Pan override (-1 to 1, null = use default)
     * @param pitch Pitch override (1 = normal, null = use default)
     * @param bus Bus to play on (null = use sound's default bus)
     * @return A SoundPlayer instance to control this specific playback
     */
    public function play(position:Float = 0, loop:Bool = false, ?volume:Float, ?pan:Float, ?pitch:Float, ?bus:Int):SoundPlayer {

        var mixer = audio.mixers.getInline(group);

        // Don't play any sound linked to a muted mixed
        if (mixer.mute)
            return cast app.backend.audio.mute(backendItem);

        if (volume == null) volume = this.volume;
        if (pan == null) pan = this.pan;
        if (pitch == null) pitch = this.pitch;
        if (bus == null) bus = this.bus;

        // Apply mixer settings
        volume *= mixer.volume * 2;
        pan += mixer.pan;
        pitch += mixer.pitch - 1;

        return cast app.backend.audio.play(backendItem, volume, pan, pitch, position, loop, bus);

    }

}
