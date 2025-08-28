package ceramic;

/**
 * Data structure representing the JSON format exported by Aseprite.
 * This format contains sprite sheet metadata including frame information,
 * animations (frame tags), layers, and slices.
 *
 * Example JSON structure (Aseprite array format):
 * ```json
 * {
 *   "frames": [
 *     {
 *       "filename": "sprite 0.png",
 *       "frame": {"x": 0, "y": 0, "w": 32, "h": 32},
 *       "rotated": false,
 *       "trimmed": true,
 *       "spriteSourceSize": {"x": 4, "y": 2, "w": 24, "h": 30},
 *       "sourceSize": {"w": 32, "h": 32},
 *       "duration": 100
 *     }
 *     // ... more frames
 *   ],
 *   "meta": {
 *     "app": "aseprite",
 *     "version": "1.3.1",
 *     "image": "spritesheet.png",
 *     "format": "RGBA8888",
 *     "size": {"w": 128, "h": 32},
 *     "scale": "1",
 *     "frameTags": [
 *       {"name": "idle", "from": 0, "to": 1, "direction": "forward"}
 *       // ... more animations
 *     ],
 *     "layers": [
 *       {"name": "Layer1", "opacity": 255, "blendMode": "normal"}
 *     ],
 *     "slices": []
 *   }
 * }
 * ```
 *
 * Note: This parser only supports the JSON array format. When exporting from Aseprite,
 * use File > Export Sprite Sheet and select "JSON data" with "Array" format.
 * While designed for Aseprite, any tool can generate compatible JSON following this structure.
 */
typedef AsepriteJson = {

    /**
     * Array of frame definitions in the sprite sheet.
     * Each frame contains position, size, timing, and trimming information.
     */
    var frames:Array<AsepriteJsonFrame>;

    /**
     * Metadata about the sprite sheet including application info,
     * image dimensions, animations, and layers.
     */
    var meta:AsepriteJsonMeta;

}

/**
 * Animation playback direction for frame tags.
 * Determines how frames are played within an animation sequence.
 */
enum abstract AsepriteJsonFrameTagDirection(String) {

    /**
     * Play frames from first to last.
     */
    var FORWARD = "forward";

    /**
     * Play frames from last to first.
     */
    var REVERSE = "reverse";

    /**
     * Play frames forward then backward repeatedly.
     * Creates a smooth back-and-forth animation.
     */
    var PINGPONG = "pingpong";

}

/**
 * Metadata section of the Aseprite JSON export.
 * Contains information about the export settings and sprite structure.
 */
typedef AsepriteJsonMeta = {

    /**
     * Application name that exported the file (usually "aseprite").
     */
    var app:String;

    /**
     * Version of the application that exported the file.
     */
    var version:String;

    /**
     * Path to the image file containing the sprite sheet texture.
     */
    var image:String;

    /**
     * Pixel format of the image (e.g., "RGBA8888").
     */
    var format:String;

    /**
     * Total dimensions of the sprite sheet texture.
     */
    var size:AsepriteJsonSize;

    /**
     * Scale factor applied during export (e.g., "1", "2").
     */
    var scale:String;

    /**
     * Array of animation definitions (called tags in Aseprite).
     * Each tag defines a named animation sequence with frame range.
     */
    var frameTags:Array<AsepriteJsonFrameTag>;

    /**
     * Array of layer information from the original Aseprite file.
     */
    var layers:Array<AsepriteJsonLayer>;

    /**
     * Array of slice definitions for 9-slice scaling and other purposes.
     */
    var slices:Array<AsepriteJsonSlice>;

}

/**
 * Animation definition in Aseprite, called a "frame tag".
 * Defines a named sequence of frames that form an animation.
 */
typedef AsepriteJsonFrameTag = {

    /**
     * Name of the animation (e.g., "idle", "walk", "jump").
     */
    var name:String;

    /**
     * Starting frame index (0-based) for this animation.
     */
    var from:Int;

    /**
     * Ending frame index (inclusive) for this animation.
     */
    var to:Int;

    /**
     * Playback direction for the animation.
     */
    var direction:AsepriteJsonFrameTagDirection;

}

/**
 * Layer information from the original Aseprite file.
 * Preserves layer properties for advanced rendering.
 */
typedef AsepriteJsonLayer = {

    /**
     * Name of the layer.
     */
    var name:String;

    /**
     * Layer opacity (0-255).
     */
    var opacity:Int;

    /**
     * Blend mode applied to the layer (e.g., "normal", "multiply").
     */
    var blendMode:String;

}

/**
 * Slice definition for 9-slice scaling and UI elements.
 * Currently empty but reserved for future Aseprite features.
 */
typedef AsepriteJsonSlice = {

}

/**
 * Individual frame definition within the sprite sheet.
 * Contains all information needed to extract and display a single frame.
 */
typedef AsepriteJsonFrame = {

    /**
     * Unique filename/identifier for this frame.
     * Usually in format "filename frame_number.png" or custom naming.
     */
    var filename:String;

    /**
     * Rectangle defining the frame's position and size in the sprite sheet.
     */
    var frame:AsepriteJsonRect;

    /**
     * Whether the frame is rotated 90 degrees clockwise in the atlas.
     * Used for more efficient texture packing.
     */
    var rotated:Bool;

    /**
     * Whether transparent pixels were trimmed from the original frame.
     */
    var trimmed:Bool;

    /**
     * Rectangle defining the trimmed frame size and offset within the original frame.
     * Used to restore the frame to its original dimensions when rendered.
     */
    var spriteSourceSize:AsepriteJsonRect;

    /**
     * Original frame dimensions before any trimming.
     */
    var sourceSize:AsepriteJsonSize;

    /**
     * Frame duration in milliseconds for animations.
     */
    var duration:Float;

}

/**
 * Rectangle structure with position and dimensions.
 * Used for frame boundaries and trimming information.
 */
typedef AsepriteJsonRect = {

    /**
     * X coordinate of the rectangle's top-left corner.
     */
    var x:Float;

    /**
     * Y coordinate of the rectangle's top-left corner.
     */
    var y:Float;

    /**
     * Width of the rectangle.
     */
    var w:Float;

    /**
     * Height of the rectangle.
     */
    var h:Float;

}

/**
 * Size structure for dimensions without position.
 */
typedef AsepriteJsonSize = {

    /**
     * Width dimension.
     */
    var w:Float;

    /**
     * Height dimension.
     */
    var h:Float;

}
