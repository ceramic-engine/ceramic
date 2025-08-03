package ceramic;

import spine.BlendMode as SpineBlendMode;
import spine.attachments.RegionAttachment;

using ceramic.Extensions;

/**
 * Utility class for binding Ceramic visuals to Spine skeleton slots.
 * 
 * This class provides static methods to:
 * - Show/hide specific slots
 * - Attach Ceramic visuals (Text, Quad, Mesh, etc.) to Spine slots
 * - Synchronize visual properties with slot transforms and colors
 * 
 * Common use cases include:
 * - Attaching particle effects to bones
 * - Displaying dynamic text on characters
 * - Overlaying custom graphics on skeleton parts
 * - Creating hybrid Spine/Ceramic animations
 * 
 * ## Usage Example
 * 
 * ```haxe
 * // Attach a text label to a character's head
 * var nameText = new Text();
 * nameText.content = "Player 1";
 * SpineBindVisual.bindVisual(spine, "head_slot", nameText, 0, -50);
 * 
 * // Hide a slot
 * SpineBindVisual.hideSlot(spine, "weapon_slot");
 * ```
 * 
 * @see SpineBindVisualOptions
 * @see Spine
 */
class SpineBindVisual {

    /**
     * Hides a specific slot in the Spine skeleton.
     * 
     * The slot will not be rendered but continues to be updated.
     * Use this to dynamically hide equipment, body parts, etc.
     * 
     * @param spine The Spine instance
     * @param slotName Name of the slot to hide
     */
    public static function hideSlot(spine:Spine, slotName:String):Void {

        if (spine.hiddenSlots == null) {
            spine.hiddenSlots = new IntBoolMap();
        }

        spine.hiddenSlots.set(Spine.globalSlotIndexForName(slotName), true);
        spine.renderDirty = true;

    }

    /**
     * Shows a previously hidden slot in the Spine skeleton.
     * 
     * Reverses the effect of `hideSlot()`.
     * 
     * @param spine The Spine instance
     * @param slotName Name of the slot to show
     */
    public static function showSlot(spine:Spine, slotName:String):Void {

        if (spine.hiddenSlots == null) {
            // Nothing to unhide
            return;
        }

        spine.hiddenSlots.set(Spine.globalSlotIndexForName(slotName), false);
        spine.renderDirty = true;

    }

    /**
     * Binds a Ceramic visual to a Spine slot.
     * 
     * The visual will follow the slot's transform (position, rotation, scale)
     * and optionally inherit its color and alpha. The visual becomes a child
     * of the Spine instance for proper rendering order.
     * 
     * @param spine The Spine instance to bind to
     * @param slotName Name of the slot to follow
     * @param visual The Ceramic visual to attach
     * @param offsetX Horizontal offset from the slot position
     * @param offsetY Vertical offset from the slot position
     * @return Configuration options for customizing the binding behavior
     */
    public static function bindVisual(spine:Spine, slotName:String, visual:Visual, offsetX:Float = 0.0, offsetY:Float = 0.0):SpineBindVisualOptions {

        var options = new SpineBindVisualOptions();

        options.spineData = spine.spineData;
        options.spine = spine;
        options.slotName = slotName;
        options.visual = visual;
        options.offsetX = offsetX;
        options.offsetY = offsetY;

        if (options.visual != null) {

            if (Std.isOfType(visual, Text)) {
                // Keep pre-casted text visual if applicable
                options.textVisual = cast visual;
            }
            else if (visual.asQuad == null && visual.asMesh == null) {
                // On unknown visual types, do not update color by default
                options.bindColor = false;
            }

            // Add visual into spine object
            spine.add(visual);
        }

        // Then update visual when slot changes
        options.handleUpdateSlot = function(info) {

            options.didUpdateSlot = true;

            var visual = options.visual;
            info.drawDefault = options.drawDefault;

            if (options.manageActiveProperty) {
                visual.active = true;
            }

            if (visual != null && (visual.visible || !options.skipIfInvisible)) {

                if (options.bindTransform) {
                    var transform = visual.transform;
                    if (transform == null) {
                        transform = new Transform();
                        visual.transform = transform;
                    }

                    transform.identity();

                    if (options.compensateRegionRotation) {
                        var region:RegionAttachment = null;
                        if (Std.isOfType(info.slot.attachment, RegionAttachment)) {
                            region = cast info.slot.attachment;
                        }
                        if (region != null) {
                            transform.rotate(-Utils.degToRad(region.getRotation()));
                        }
                    }

                    transform.translate(options.offsetX, options.offsetY);

                    var spineScale = options.spine.skeletonScale;
                    var spineUnscale = 1.0 / spineScale;

                    transform.scale(spineUnscale, spineUnscale);
                    transform.concat(info.transform);
                    transform.scale(spineScale, spineScale);
                }

                if (options.bindColor) {
                    if (options.textVisual != null) {
                        options.textVisual.color = Color.fromRGBFloat(
                            info.slot.color.r,
                            info.slot.color.g,
                            info.slot.color.b
                        );
                    }
                    else if (visual.asQuad != null) {
                        visual.asQuad.color = Color.fromRGBFloat(
                            info.slot.color.r,
                            info.slot.color.g,
                            info.slot.color.b
                        );
                    }
                    else if (visual.asMesh != null) {
                        visual.asMesh.color = Color.fromRGBFloat(
                            info.slot.color.r,
                            info.slot.color.g,
                            info.slot.color.b
                        );
                    }
                    else {
                        visual.setProperty('color', Color.fromRGBFloat(
                            info.slot.color.r,
                            info.slot.color.g,
                            info.slot.color.b
                        ));
                    }
                }

                if (options.bindBlending) {
                    visual.blending = (info.slot.data.blendMode == SpineBlendMode.additive) ? Blending.ADD : Blending.AUTO;
                }

                if (options.bindAlpha) {
                    options.visual.alpha = info.slot.color.a;
                }

                if (options.bindDepth) {
                    options.visual.depth = info.depth;
                }
            }
        };

        spine.onUpdateSlotWithName(visual, slotName, options.handleUpdateSlot);
        spine.onBeginRender(visual, options.handleBeginRender);
        spine.onEndRender(visual, options.handleEndRender);

        return options;

    }

}
