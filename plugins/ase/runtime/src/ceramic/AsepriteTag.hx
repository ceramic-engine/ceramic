package ceramic;

// Mostly taken from: https://github.com/AustinEast/heaps-aseprite/blob/3d9a251265ec41bb64e494ef9ef52041ad218974/src/aseprite/Tag.hx
// Credits to its original authors

/**
 * Represents an animation tag from an Aseprite file.
 * 
 * Tags define named animation sequences within the sprite's frames.
 * Each tag marks a range of frames that can be played as a loop or
 * one-shot animation with a specific playback direction.
 * 
 * Tags are commonly used to organize different character animations
 * like "idle", "walk", "jump", "attack" within a single Aseprite file.
 * 
 * @see AsepriteData for the parent data structure
 * @see SpriteSheet for animation playback using tags
 */
@:structInit
class AsepriteTag {
    /**
     * The name of this animation tag.
     * Used to identify and play specific animations (e.g., "walk", "idle").
     */
    public var name(default, null):String;
    
    /**
     * The first frame index of this animation (0-based, inclusive).
     */
    public var fromFrame(default, null):Int;
    
    /**
     * The last frame index of this animation (0-based, inclusive).
     */
    public var toFrame(default, null):Int;
    
    /**
     * The playback direction for this animation:
     * - 0: Forward (play from fromFrame to toFrame)
     * - 1: Reverse (play from toFrame to fromFrame)
     * - 2: Ping-pong (play forward then reverse)
     */
    public var direction(default, null):Int;

    /**
     * Creates an AsepriteTag from raw tag chunk data.
     * 
     * Converts the file format representation into a more convenient
     * structure for use in the engine.
     * 
     * @param chunk The tag data from the Aseprite file
     * @return A new AsepriteTag instance
     */
    public static function fromChunk(chunk:ase.chunks.TagsChunk.Tag):AsepriteTag {
        return {
            name: chunk.tagName,
            fromFrame: chunk.fromFrame,
            toFrame: chunk.toFrame,
            direction: chunk.animDirection
        };
    }
}
