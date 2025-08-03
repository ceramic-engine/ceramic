package ceramic;

import ceramic.Entity;

import spine.support.graphics.TextureAtlas;
import spine.support.utils.JsonValue;
import spine.attachments.*;
import spine.*;

import ceramic.SpinePlugin;

using StringTools;
using ceramic.Extensions;

/**
 * Container for loaded Spine animation data, including skeleton structure and texture atlas.
 * 
 * SpineData represents the shared, immutable data loaded from Spine export files (.json/.skel)
 * and their associated texture atlases. Multiple Spine instances can share the same SpineData,
 * making it efficient to have many instances of the same animation.
 * 
 * This class manages the lifecycle of Spine skeleton data and ensures proper cleanup of
 * resources when no longer needed. It's typically created automatically when loading
 * Spine assets through the asset system.
 * 
 * @example
 * ```haxe
 * // SpineData is usually created internally when loading assets
 * assets.add(Spines.HERO);
 * assets.load(function(success) {
 *     if (success) {
 *         var spineData = assets.spine(Spines.HERO);
 *         
 *         // Create multiple Spine instances from the same data
 *         var hero1 = new Spine();
 *         hero1.spineData = spineData;
 *         
 *         var hero2 = new Spine();
 *         hero2.spineData = spineData;
 *     }
 * });
 * ```
 */
class SpineData extends Entity {

    /**
     * The Spine skeleton data containing bone hierarchy, slots, animations, and skins.
     * This is the core data structure that defines the animation's structure and behavior.
     * It's shared between all Spine instances using this SpineData.
     */
    public var skeletonData(default,null):SkeletonData;

    /**
     * The texture atlas containing all images used by this Spine animation.
     * The atlas maps region names to texture coordinates, allowing the animation
     * to reference specific parts of texture pages.
     */
    public var atlas(default,null):TextureAtlas;

    /**
     * Optional reference to the SpineAsset that created this data.
     * When set, the asset will be destroyed along with this SpineData,
     * ensuring proper cleanup of all related resources.
     */
    public var asset:SpineAsset;

    /**
     * Creates a new SpineData instance from a texture atlas and JSON data.
     * 
     * @param atlas The texture atlas containing all images for the animation
     * @param json The parsed JSON data exported from Spine
     * @param scale Optional scale factor to apply to the skeleton data (default: 1.0).
     *              This affects the size of the animation when rendered.
     */
    public function new(
        atlas:TextureAtlas,
        json:JsonValue,
        scale:Float = 1.0
    ) {

        super();

        this.atlas = atlas;

        var spineJson:SkeletonJson = new SkeletonJson(
            new AtlasAttachmentLoader(atlas)
        );
        spineJson.setScale(scale);

        skeletonData = spineJson.readSkeletonData(
            json
        );

    }

    /**
     * Finds the index of a slot by its name.
     * 
     * Slots are the containers in Spine that hold attachments (images, meshes, etc.).
     * Each slot has a unique name and index within the skeleton. This method provides
     * a way to look up a slot's index, which can be more efficient for repeated operations
     * than using the name directly.
     * 
     * @param slotName The name of the slot to find
     * @return The index of the slot if found, or -1 if the slot doesn't exist or if slotName is null
     * 
     * @example
     * ```haxe
     * var spineData = assets.spine(Spines.HERO);
     * var weaponSlotIndex = spineData.findSlotIndex("weapon");
     * 
     * if (weaponSlotIndex != -1) {
     *     // Use the index for efficient slot operations
     *     trace("Weapon slot found at index: " + weaponSlotIndex);
     * }
     * ```
     */
    public function findSlotIndex(slotName:String):Int {

        // TODO cache this info

        if (slotName == null || skeletonData == null) {
            return -1;
        }
        else {
            var allSlots = skeletonData.slots;
            for (i in 0...allSlots.length) {
                var slot = allSlots.unsafeGet(i);
                if (slot.name == slotName) {
                    return i;
                }
            }
            return -1;
        }

    }

    /**
     * Destroys this SpineData instance and releases all associated resources.
     * 
     * This method ensures proper cleanup by:
     * - Destroying the associated SpineAsset if one exists
     * - Disposing of the texture atlas to free GPU memory
     * - Clearing all references to allow garbage collection
     * 
     * After calling destroy(), this SpineData instance should not be used anymore.
     * Any Spine instances still using this data may exhibit undefined behavior.
     */
    override public function destroy():Void {

        super.destroy();

        if (asset != null) asset.destroy();

        atlas.dispose();
        atlas = null;

    }

}
