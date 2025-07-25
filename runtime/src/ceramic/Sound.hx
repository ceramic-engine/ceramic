package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;

class Sound extends Entity {

    public var backendItem:backend.AudioResource;

    public var asset:SoundAsset;

    /**
     * Default bus to play this sound on (0-based)
     */
    public var bus:Int = 0;

    public var group(default, set):Int = 0;
    function set_group(group:Int):Int {
        if (this.group == group) return group;
        this.group = group;
        ceramic.App.app.audio.initMixerIfNeeded(group);
        return group;
    }

/// Lifecycle

    /**
     * Create a new sound from the given samples buffer
     * @param buffer Float32Array containing the raw PCM samples
     * @param samples Number of sample frames (samples per channel)
     * @param channels Number of audio channels (1 = mono, 2 = stereo, etc.)
     * @param sampleRate Sample rate in Hz (e.g., 44100)
     * @param interleaved Whether the PCM data is interleaved (LRLRLR...) or planar (LLL...RRR...)
     */
    public static function fromSamplesBuffer(buffer:Float32Array, samples:Int, channels:Int, sampleRate:Float, interleaved:Bool):Sound {

        var backendItem = app.backend.audio.createFromSamplesBuffer(buffer, samples, channels, sampleRate, interleaved);
        return new Sound(backendItem);

    }

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
     */
    public var volume:Float = 0.5;

    /**
     * Default pan when playing this sound.
     */
    public var pan:Float = 0;

    /**
     * Default pitch when playing this sound.
     */
    public var pitch:Float = 1;

    /**
     * Sound duration.
     */
    public var duration(get, never):Float;
    inline function get_duration():Float {
        return app.backend.audio.getDuration(backendItem);
    }

    /**
     * Play the sound at requested position. If volume/pan/pitch are not provided,
     * sound instance properties will be used instead.
     * @param position Start position in seconds
     * @param loop Whether to loop the sound
     * @param volume Volume (0-1)
     * @param pan Pan (-1 to 1)
     * @param pitch Pitch multiplier
     * @param bus Bus to play on (defaults to sound's bus property)
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
