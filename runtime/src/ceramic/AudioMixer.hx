package ceramic;

/**
 * Controls audio properties for a group of sounds.
 * 
 * AudioMixer allows collective control over sounds assigned to the same group,
 * making it easy to adjust volume, pan, pitch, or mute entire categories of sounds
 * (e.g., music, sound effects, UI sounds) independently.
 * 
 * Mixers are created automatically when accessed through `app.audio.mixer(index)`
 * or when a sound's group property is set.
 * 
 * The mixer's settings are multiplied with individual sound settings:
 * - Final volume = sound.volume × mixer.volume × 2
 * - Final pan = sound.pan + mixer.pan
 * - Final pitch = sound.pitch + (mixer.pitch - 1)
 * 
 * @example
 * ```haxe
 * // Control all sounds in group 1 (e.g., music)
 * var musicMixer = app.audio.mixer(1);
 * musicMixer.volume = 0.3;
 * musicMixer.mute = false;
 * 
 * // Assign sounds to the music group
 * var bgMusic = assets.sound('background');
 * bgMusic.group = 1;
 * bgMusic.play(0, true);
 * ```
 * 
 * @see Audio
 * @see Sound
 */
class AudioMixer extends Entity {

    /**
     * Master volume for all sounds in this group.
     * Range: 0.0 (silent) to 1.0 (full volume)
     * Default: 0.5
     * This is multiplied by 2 then multiplied with each sound's individual volume.
     */
    public var volume:Float = 0.5;

    /**
     * Master pan adjustment for all sounds in this group.
     * Range: -1.0 (full left) to 1.0 (full right)
     * Default: 0.0 (center)
     * This is added to each sound's individual pan value.
     */
    public var pan:Float = 0;

    /**
     * Master pitch adjustment for all sounds in this group.
     * Default: 1.0 (no change)
     * The adjustment (pitch - 1) is added to each sound's individual pitch.
     */
    public var pitch:Float = 1;

    /**
     * Mute all sounds in this group.
     * When true, sounds in this group won't play at all.
     * Useful for quickly toggling categories of sounds on/off.
     */
    public var mute:Bool = false;

    /**
     * The group index this mixer controls.
     * Read-only - set when the mixer is created.
     */
    public var index:Int;

    /**
     * Private constructor - mixers are created by the Audio system.
     * Use `app.audio.mixer(index)` to get or create a mixer.
     * @param index The group index for this mixer
     */
    @:allow(ceramic.Audio)
    private function new(index:Int) {

        super();

        this.index = index;

    }

}
