package ceramic;

import ceramic.App.app;

/**
 * Controls an individual sound playback instance.
 * 
 * SoundPlayer represents a single playing instance of a Sound.
 * It allows real-time control over playback parameters like
 * volume, pan, pitch, and position.
 * 
 * Instances are created by calling `sound.play()` and remain
 * valid until the sound finishes playing or is explicitly stopped.
 * 
 * ```haxe
 * // Play a sound and control it
 * var player = sound.play();
 * player.volume = 0.8;
 * player.pan = -0.5;
 * 
 * // Pause and resume
 * player.pause();
 * Timer.delay(null, 2.0, () -> player.resume());
 * 
 * // Fade out over 1 second
 * player.fadeOut(1.0);
 * ```
 * 
 * @see Sound
 */
abstract SoundPlayer(backend.AudioHandle) {

    /**
     * Pause the sound playback.
     * The sound can be resumed later from the same position.
     * No effect if already paused or stopped.
     */
    inline public function pause():Void {

        app.backend.audio.pause(this);

    }

    /**
     * Resume playing the sound from where it was paused.
     * No effect if not paused.
     */
    inline public function resume():Void {

        app.backend.audio.resume(this);

    }

    /**
     * Stop the sound playback completely.
     * After stopping, this SoundPlayer instance becomes invalid
     * and should not be used further.
     */
    inline public function stop():Void {

        app.backend.audio.stop(this);

    }

    /**
     * The volume of this sound instance.
     * Range: 0.0 (silent) to 1.0 (full volume)
     * Can be modified during playback for real-time volume control.
     */
    public var volume(get,set):Float;
    inline function get_volume():Float {
        return app.backend.audio.getVolume(this);
    }
    inline function set_volume(volume:Float):Float {
        app.backend.audio.setVolume(this, volume);
        return volume;
    }

    /**
     * The stereo pan position of this sound instance.
     * Range: -1.0 (full left) to 1.0 (full right)
     * 0.0 = center
     * Can be modified during playback for real-time panning.
     */
    public var pan(get,set):Float;
    inline function get_pan():Float {
        return app.backend.audio.getPan(this);
    }
    inline function set_pan(pan:Float):Float {
        app.backend.audio.setPan(this, pan);
        return pan;
    }

    /**
     * The pitch (playback speed) of this sound instance.
     * 1.0 = normal pitch
     * 0.5 = one octave lower (half speed)
     * 2.0 = one octave higher (double speed)
     * Can be modified during playback for real-time pitch shifting.
     */
    public var pitch(get,set):Float;
    inline function get_pitch():Float {
        return app.backend.audio.getPitch(this);
    }
    inline function set_pitch(pitch:Float):Float {
        app.backend.audio.setPitch(this, pitch);
        return pitch;
    }

    /**
     * The current playback position in seconds.
     * Can be read to check progress or set to seek to a specific time.
     * Setting position may cause a brief audio glitch on some backends.
     */
    public var position(get,set):Float;
    inline function get_position():Float {
        return app.backend.audio.getPosition(this);
    }
    inline function set_position(position:Float):Float {
        app.backend.audio.setPosition(this, position);
        return position;
    }

/// Helpers

    /**
     * Fade out the sound over a specified duration, then stop it.
     * Uses linear interpolation to smoothly reduce volume to 0.
     * @param duration Fade duration in seconds
     */
    public function fadeOut(duration:Float):Void {

        if (volume == 0) {
            stop();
            return;
        }

        var tween = Tween.start(null, Easing.LINEAR, duration, volume, 0, function(value, time) {
            volume = value;
        });
        tween.onceComplete(null, function() {
            stop();
        });

    }

}
