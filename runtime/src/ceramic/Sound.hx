package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;

class Sound extends Entity {

    public var backendItem:backend.AudioResource;

    public var asset:SoundAsset;

    /**
     * Default channel to play this sound on (0-based)
     */
    public var channel:Int = 0;

    public var group(default, set):Int = 0;
    function set_group(group:Int):Int {
        if (this.group == group) return group;
        this.group = group;
        ceramic.App.app.audio.initMixerIfNeeded(group);
        return group;
    }

/// Lifecycle

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
     * @param channel Channel to play on (defaults to sound's channel property)
     */
    public function play(position:Float = 0, loop:Bool = false, ?volume:Float, ?pan:Float, ?pitch:Float, ?channel:Int):SoundPlayer {

        var mixer = audio.mixers.getInline(group);

        // Don't play any sound linked to a muted mixed
        if (mixer.mute)
            return cast app.backend.audio.mute(backendItem);

        if (volume == null) volume = this.volume;
        if (pan == null) pan = this.pan;
        if (pitch == null) pitch = this.pitch;
        if (channel == null) channel = this.channel;

        // Apply mixer settings
        volume *= mixer.volume * 2;
        pan += mixer.pan;
        pitch += mixer.pitch - 1;

        return cast app.backend.audio.play(backendItem, volume, pan, pitch, position, loop, channel);

    }

}
