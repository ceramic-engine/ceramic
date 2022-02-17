package ceramic;

import spine.BlendMode as SpineBlendMode;
import spine.attachments.RegionAttachment;

using ceramic.Extensions;

class SpineBindVisual {

    public static function hideSlot(spine:Spine, slotName:String):Void {

        if (spine.hiddenSlots == null) {
            spine.hiddenSlots = new IntBoolMap();
        }

        spine.hiddenSlots.set(Spine.globalSlotIndexForName(slotName), true);
        spine.renderDirty = true;

    }

    public static function showSlot(spine:Spine, slotName:String):Void {

        if (spine.hiddenSlots == null) {
            // Nothing to unhide
            return;
        }

        spine.hiddenSlots.set(Spine.globalSlotIndexForName(slotName), false);
        spine.renderDirty = true;

    }

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
