package ceramic;

import ceramic.App.app;

abstract SoundPlayer(backend.Audio.AudioHandle) {

    /** Pause the sound (for later resume). */
    inline public function pause():Void {

        app.backend.audio.pause(this);

    } //pause

    /** Resume playing the sound. */
    inline public function resume():Void {

        app.backend.audio.resume(this);

    } //resume

    /** Stop the sound. */
    inline public function stop():Void {

        app.backend.audio.stop(this);

    } //stop

    /** The volume of the sound being played. */
    public var volume(get,set):Float;
    inline function get_volume():Float {
        return app.backend.audio.getVolume(this);
    }
    inline function set_volume(volume:Float):Float {
        app.backend.audio.setVolume(this, volume);
        return volume;
    }

    /** The pan of the sound being played. */
    public var pan(get,set):Float;
    inline function get_pan():Float {
        return app.backend.audio.getPan(this);
    }
    inline function set_pan(pan:Float):Float {
        app.backend.audio.setPan(this, pan);
        return pan;
    }

    /** The pitch of the sound being played. */
    public var pitch(get,set):Float;
    inline function get_pitch():Float {
        return app.backend.audio.getPitch(this);
    }
    inline function set_pitch(pitch:Float):Float {
        app.backend.audio.setPitch(this, pitch);
        return pitch;
    }

    /** The position (in seconds) of the sound being played. */
    public var position(get,set):Float;
    inline function get_position():Float {
        return app.backend.audio.getPosition(this);
    }
    inline function set_position(position:Float):Float {
        app.backend.audio.setPosition(this, position);
        return position;
    }

} //SoundPlayer
