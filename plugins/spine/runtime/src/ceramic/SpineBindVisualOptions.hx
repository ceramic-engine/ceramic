package ceramic;

import ceramic.Spine.SlotInfo;

/**
 * Configuration options for binding a Ceramic visual to a Spine slot.
 * 
 * This class controls how a visual synchronizes with a Spine slot's properties.
 * It's returned by `SpineBindVisual.bindVisual()` and allows fine-tuning the
 * binding behavior after creation.
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var options = SpineBindVisual.bindVisual(spine, "weapon", sword);
 * 
 * // Customize binding behavior
 * options.drawDefault = true; // Show original slot attachment too
 * options.bindColor = false;  // Don't sync color
 * options.offsetY = -10;      // Adjust position
 * 
 * // Later, unbind the visual
 * options.unbind();
 * ```
 * 
 * @see SpineBindVisual
 */
@:allow(ceramic.SpineBindVisual)
class SpineBindVisualOptions {

    /// Public options

    /**
     * Whether to render the original slot attachment.
     * Set to true to display both the original attachment and the bound visual.
     * Default is false (only show the bound visual).
     */
    public var drawDefault:Bool = false;

    /**
     * Horizontal offset from the slot's position in pixels.
     * Positive values move the visual to the right.
     */
    public var offsetX:Float = 0.0;

    /**
     * Vertical offset from the slot's position in pixels.
     * Positive values move the visual down.
     */
    public var offsetY:Float = 0.0;

    /**
     * Whether to apply the slot's transform (position, rotation, scale) to the visual.
     * Disable this if you only want to sync other properties like color.
     * Default is true.
     */
    public var bindTransform:Bool = true;

    /**
     * Whether to apply the slot's color tint to the visual.
     * Works with Text, Quad, Mesh, and any visual with a color property.
     * Default is true.
     */
    public var bindColor:Bool = true;

    /**
     * Whether to apply the slot's alpha transparency to the visual.
     * The slot's alpha is multiplied with the visual's existing alpha.
     * Default is true.
     */
    public var bindAlpha:Bool = true;

    /**
     * Whether to apply the slot's rendering depth (z-order) to the visual.
     * Ensures the visual renders at the correct layer relative to other slots.
     * Default is true.
     */
    public var bindDepth:Bool = true;

    /**
     * Whether to apply the slot's blend mode to the visual.
     * Synchronizes additive blending when the slot uses it.
     * Default is true.
     */
    public var bindBlending:Bool = true;

    /**
     * Whether to compensate for region attachment rotation.
     * Enable this if your visual appears rotated incorrectly when bound
     * to slots with rotated region attachments.
     * Default is false.
     */
    public var compensateRegionRotation:Bool = false;

    /**
     * Controls the visual's active state based on slot visibility.
     * When true, sets visual.active = false when the slot has no attachment,
     * and visual.active = true when it does.
     * Default is true.
     */
    public var manageActiveProperty:Bool = true;

    /**
     * Skip updating the visual if it's not visible.
     * This optimization avoids unnecessary calculations for hidden visuals.
     * Default is true.
     */
    public var skipIfInvisible:Bool = true;

    /**
     * Whether to reset the visual's transform to identity when unbinding.
     * Prevents the visual from keeping the last slot transform.
     * Default is true.
     */
    public var resetTransformOnUnbind:Bool = true;

    /**
     * Whether to destroy the visual when unbinding.
     * Use this for temporary visuals that should be cleaned up automatically.
     * Default is false.
     */
    public var destroyVisualOnUnbind:Bool = false;

    /// Managed internally
    
    /**
     * The name of the slot this binding is attached to.
     * Set automatically by SpineBindVisual.bindVisual().
     */
    public var slotName(default, null):String = null;

    /**
     * The Spine instance this binding is attached to.
     * Set automatically by SpineBindVisual.bindVisual().
     */
    public var spine(default, null):Spine = null;

    /**
     * The SpineData of the bound Spine instance.
     * Set automatically by SpineBindVisual.bindVisual().
     */
    public var spineData(default, null):SpineData = null;

    /**
     * The visual being controlled by this binding.
     * Set automatically by SpineBindVisual.bindVisual().
     */
    public var visual(default, null):Visual = null;

    /**
     * If the visual is a Text instance, this contains the type-cast reference.
     * Used internally for optimized text property access.
     */
    public var textVisual(default, null):Text = null;

    var handleUpdateSlot:SlotInfo->Void = null;

    public function new() {}

    /**
     * Removes the binding between the visual and the Spine slot.
     * 
     * This method:
     * - Unregisters all event handlers
     * - Optionally resets the visual's transform (see `resetTransformOnUnbind`)
     * - Optionally destroys the visual (see `destroyVisualOnUnbind`)
     * 
     * After calling unbind(), this options object should not be used again.
     */
    public function unbind():Void {

        if (spine != null && !spine.destroyed) {
            if (handleUpdateSlot != null) {
                spine.offUpdateSlotWithName(slotName, handleUpdateSlot);
                spine.offBeginRender(handleBeginRender);
                spine.offEndRender(handleEndRender);
                handleUpdateSlot = null;
                if (destroyVisualOnUnbind && visual != null) {
                    visual.destroy();
                }
                else if (resetTransformOnUnbind && visual != null && visual.transform != null) {
                    visual.transform.identity();
                }
            }
        }

    }

    /// Internal

    var didUpdateSlot:Bool = false;

    function handleBeginRender():Void {

        didUpdateSlot = false;

    }

    function handleEndRender():Void {

        if (!didUpdateSlot && manageActiveProperty) {
            visual.active = false;
        }

    }

}
