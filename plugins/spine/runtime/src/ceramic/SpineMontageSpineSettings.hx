package ceramic;

/**
 * Configuration for the Spine instance used by a SpineMontage.
 * 
 * This class allows you to either provide an existing Spine instance or
 * create a new one with specific settings. It also controls the lifecycle
 * relationship between the montage and its Spine instance, as well as
 * visual properties like scale and rendering depth.
 * 
 * The configuration follows a priority system: if an instance is provided,
 * it will be used and the data field will be ignored. Otherwise, a new
 * Spine instance will be created using the provided SpineData.
 * 
 * Using an existing Spine instance
 * ```haxe
 * var existingSpine = new Spine();
 * existingSpine.spineData = heroData;
 * 
 * var settings:SpineMontageSpineSettings = {
 *     instance: existingSpine,
 *     bound: false,  // Don't destroy spine when montage is destroyed
 *     scale: 0.5,
 *     depth: 10
 * };
 * ```
 * 
 * Creating a new Spine instance
 * ```haxe
 * var settings:SpineMontageSpineSettings = {
 *     data: heroSpineData,
 *     bound: true,   // Destroy spine when montage is destroyed
 *     scale: 0.75,
 *     depth: 5,
 *     depthRange: 2
 * };
 * ```
 */
@:structInit
class SpineMontageSpineSettings {

    /**
     * An existing Spine instance to use with this montage.
     * 
     * When provided, this instance will be used directly and the `data`
     * field will be ignored. This is useful when you want to:
     * - Share a Spine instance between multiple montages
     * - Use a pre-configured Spine instance with specific settings
     * - Maintain direct control over the Spine instance lifecycle
     * 
     * The instance will still have its scale, depth, and depthRange
     * properties set according to this configuration.
     */
    public var instance:Null<Spine> = null;

    /**
     * SpineData used to create a new Spine instance.
     * 
     * This field is only used when `instance` is null. A new Spine
     * instance will be created with this data and configured according
     * to the other settings in this configuration.
     * 
     * The created instance will be inactive by default until an
     * animation is played through the montage.
     */
    public var data:Null<SpineData> = null;

    /**
     * Controls the lifecycle binding between the montage and Spine instance.
     * 
     * When true (default):
     * - Destroying the montage will also destroy the Spine instance
     * - Destroying the Spine instance will also destroy the montage
     * - Creates a strong ownership relationship
     * 
     * When false:
     * - The montage and Spine instance have independent lifecycles
     * - You must manually manage the Spine instance destruction
     * - Useful when sharing a Spine instance between multiple systems
     * 
     * This applies whether using an existing instance or creating a new one.
     */
    public var bound:Bool = true;

    /**
     * The scale factor applied to the Spine skeleton.
     * 
     * This sets the `skeletonScale` property of the Spine instance, which
     * uniformly scales all bone positions and renders. Useful for:
     * - Adjusting character sizes without re-exporting from Spine
     * - Creating different sized variants of the same character
     * - Matching your game's coordinate system
     * 
     * Default: 1.0 (original size)
     * 
     * scale: 0.5  // Half size
     * scale: 2.0  // Double size
     */
    public var scale:Float = 1.0;

    /**
     * The rendering depth (z-order) of the Spine instance.
     * 
     * Higher values render on top of lower values. This determines
     * the base rendering order of the entire Spine skeleton relative
     * to other visuals in your scene.
     * 
     * Default: 0.0
     * 
     * @see depthRange for controlling depth of individual Spine parts
     */
    public var depth:Float = 0.0;

    /**
     * The depth range available for Spine attachment rendering.
     * 
     * Spine uses this range to distribute the depth of individual
     * attachments (slots) within the skeleton. This allows proper
     * layering of body parts while keeping them as a cohesive unit.
     * 
     * The actual depth of attachments will be:
     * - Minimum: depth
     * - Maximum: depth + depthRange
     * 
     * Default: 1.0
     * 
     * depth: 10, depthRange: 5
     * // Attachments will render between depths 10 and 15
     */
    public var depthRange:Float = 1.0;

}
