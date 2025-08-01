package ceramic;

import haxe.DynamicAccess;

/**
 * Data structure that defines a fragment's content and properties.
 * This is typically loaded from .fragment files and used to instantiate
 * Fragment objects with their entities, animations, and components.
 * 
 * A FragmentData contains:
 * - Basic properties like dimensions and appearance
 * - Entity definitions (items) to instantiate
 * - Timeline tracks for animations
 * - Components to attach at the fragment level
 * - Labels for marking timeline positions
 * 
 * @see Fragment
 * @see FragmentItem
 * @see TimelineTrackData
 */
typedef FragmentData = {

    /**
     * Unique identifier for this fragment.
     * Used for caching and referencing fragments.
     */
    public var id:String;

    /**
     * Arbitrary data that can be attached to this fragment.
     * Useful for storing custom metadata or configuration.
     */
    public var data:Dynamic<Dynamic>;

    /**
     * The width of the fragment in pixels.
     * Defines the fragment's bounds and layout area.
     */
    public var width:Float;

    /**
     * The height of the fragment in pixels.
     * Defines the fragment's bounds and layout area.
     */
    public var height:Float;

    /**
     * Components to attach at the fragment level.
     * Keys are component names, values are component type names or data.
     * These components are attached to the Fragment instance itself.
     */
    public var components:DynamicAccess<String>;

    /**
     * Timeline animation tracks for animating entity properties.
     * Each track defines keyframe animations for a specific entity field.
     */
    @:optional public var tracks:Array<TimelineTrackData>;

    /**
     * Named positions in the timeline.
     * Keys are label names, values are frame indices.
     * Useful for marking important animation points or states.
     */
    @:optional public var labels:DynamicAccess<Int>;

    /**
     * Timeline playback speed in frames per second.
     * Default is 30 FPS.
     * 
     * Note: This only affects timeline animation speed, not screen refresh rate.
     * Timeline values are interpolated to match the actual display frame rate.
     */
    @:optional public var fps:Int;

    /**
     * Background color of the fragment.
     * Only visible when `transparent` is false.
     * Default is BLACK.
     */
    @:optional public var color:Color;

    /**
     * Whether the fragment has a transparent background.
     * When false, the fragment is filled with the `color` property.
     * Default is true.
     */
    @:optional public var transparent:Bool;

    /**
     * Hint for whether content should be allowed to overflow the fragment bounds.
     * This is a metadata flag - actual behavior depends on the implementation
     * using the fragment (e.g., a fragment player or container).
     */
    @:optional public var overflow:Bool;

    /**
     * Array of entity definitions to instantiate in this fragment.
     * Each item describes an entity type and its initial properties.
     * Items can be visuals (Quad, Text, etc.) or any other Entity type.
     */
    @:optional public var items:Array<FragmentItem>;

}

